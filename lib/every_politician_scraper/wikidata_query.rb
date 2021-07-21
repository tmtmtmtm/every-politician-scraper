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
      env[:cabinet] || raise('No cabinet ID provided')
    end

    def lang
      env[:lang] || 'en'
    end

    def query
      <<~SPARQL
        SELECT (STRAFTER(STR(?item), STR(wd:)) AS ?wdid) ?name (STRAFTER(STR(?positionItem), STR(wd:)) AS ?pid) ?position
        WHERE {
          BIND (wd:#{cabinet} AS ?cabinet) .
          ?cabinet wdt:P31 ?parent .

          # Positions currently in the cabinet
          ?positionItem p:P361 ?ps .
          ?ps ps:P361 ?parent .
          FILTER NOT EXISTS { ?ps pq:P582 [] }

          # Who currently holds those positions
          ?item wdt:P31 wd:Q5 ; p:P39 ?held .
          ?held ps:P39 ?positionItem ; pq:P580 ?start .
          FILTER NOT EXISTS { ?held pq:P582 [] }

          OPTIONAL { ?held prov:wasDerivedFrom/pr:P1810 ?sourceName }
          OPTIONAL { ?item rdfs:label ?enLabel FILTER(LANG(?enLabel) = "#{lang}") }
          BIND(COALESCE(?sourceName, ?enLabel) AS ?name)

          OPTIONAL { ?held prov:wasDerivedFrom/pr:P1932 ?statedName }
          OPTIONAL { ?positionItem wdt:P1705  ?nativeLabel   FILTER(LANG(?nativeLabel)   = "#{lang}") }
          OPTIONAL { ?positionItem rdfs:label ?positionLabel FILTER(LANG(?positionLabel) = "#{lang}") }
          BIND(COALESCE(?statedName, ?nativeLabel, ?positionLabel) AS ?position)
        }
        ORDER BY ?positionLabel ?began
      SPARQL
    end
  end
end
