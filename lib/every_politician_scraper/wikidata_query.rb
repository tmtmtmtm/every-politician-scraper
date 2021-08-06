# frozen_string_literal: true

module EveryPoliticianScraper
  # SPARQL run against the Wikidata Query Service
  class WikidataQuery
    require 'cgi'
    require 'scraped'

    WIKIDATA_SPARQL_URL = 'https://query.wikidata.org/sparql?query=%s'

    def initialize(sparql, agent)
      @sparql = sparql
      @agent = agent
    end

    def csv
      response.body.gsub!(/\r\n/, "\n")
    end

    private

    attr_reader :sparql, :agent

    def query_url
      WIKIDATA_SPARQL_URL % CGI.escape(sparql)
    end

    def headers
      {
        'Accept'     => 'text/csv',
        'User-Agent' => agent,
      }
    end

    def response
      @response ||= Scraped::Request.new(url: query_url, headers: headers).response
    end
  end

  # Wikidata's list of the members of a Cabinet
  class WikidataCabinet
    require 'pathname'
    require 'json'

    def initialize(config_filename)
      @config_filename = config_filename
    end

    def csv
      @csv ||= WikidataQuery.new(query, agent).csv
    end

    private

    attr_reader :config_filename

    def config_filepath
      Pathname.new(config_filename)
    end

    def env
      @env ||= JSON.parse(config_filepath.read, symbolize_names: true)
    end

    def agent
      env[:agent] || raise('No agent provided')
    end

    def cabinet
      env.dig(:cabinet, :id) || env[:cabinet] || raise('No cabinet ID provided')
    end

    def parent
      env.dig(:cabinet, :parent)
    end

    def lang
      env.dig(:source, :lang, :code) || env[:lang] || 'en'
    end

    def sourcefilter
      return '' unless source_match

      "FILTER CONTAINS(STR(?source), '#{source_match.gsub(%r[https?://],'')}')"
    end

    def source_match
      env[:source_match] || env.dig(:source, :url)
    end

    def query
      <<~SPARQL
        SELECT DISTINCT (STRAFTER(STR(?item), STR(wd:)) AS ?wdid)
               ?name ?wdLabel ?gender ?dob ?dobPrecision ?source
               (STRAFTER(STR(?positionItem), STR(wd:)) AS ?pid) ?position
               (STRAFTER(STR(?held), '/statement/') AS ?psid)
        WHERE {
          BIND (wd:#{cabinet} AS ?cabinet) .
          #{parent ? "BIND (wd:#{parent} AS ?parent) ." : "?cabinet wdt:P31 ?parent ."}

          # Positions currently in the cabinet
          ?positionItem p:P361 ?ps .
          ?ps ps:P361 ?parent .
          FILTER NOT EXISTS { ?ps pq:P582 [] }

          # Who currently holds those positions
          ?item wdt:P31 wd:Q5 ; p:P39 ?held .
          ?held ps:P39 ?positionItem ; pq:P580 ?start .
          FILTER NOT EXISTS { ?held wikibase:rank wikibase:DeprecatedRank }
          FILTER NOT EXISTS { ?held pq:P582 [] }

          OPTIONAL {
            ?held prov:wasDerivedFrom ?ref .
            ?ref pr:P854 ?source #{sourcefilter} .
            OPTIONAL { ?ref pr:P1810 ?sourceName }
            OPTIONAL { ?ref pr:P1932 ?statedName }
          }

          OPTIONAL { ?item rdfs:label ?wdLabel FILTER(LANG(?wdLabel) = "#{lang}") }
          BIND(COALESCE(?sourceName, ?wdLabel) AS ?name)

          OPTIONAL { ?positionItem wdt:P1705  ?nativeLabel   FILTER(LANG(?nativeLabel)   = "#{lang}") }
          OPTIONAL { ?positionItem rdfs:label ?positionLabel FILTER(LANG(?positionLabel) = "#{lang}") }
          BIND(COALESCE(?statedName, ?nativeLabel, ?positionLabel) AS ?position)

          OPTIONAL { ?item wdt:P21 ?genderItem }
          OPTIONAL { # truthiest DOB, with precison
            ?item p:P569 ?ts .
            ?ts a wikibase:BestRank .
            ?ts psv:P569 [wikibase:timeValue ?dob ; wikibase:timePrecision ?dobPrecision] .
          }

          SERVICE wikibase:label {
            bd:serviceParam wikibase:language "en".
            ?genderItem rdfs:label ?gender
          }
        }
        ORDER BY STR(?name) STR(?position) ?began
      SPARQL
    end
  end
end
