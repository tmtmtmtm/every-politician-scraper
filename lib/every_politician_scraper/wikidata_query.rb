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
end
