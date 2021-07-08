# frozen_string_literal: true

require 'csv'
require 'scraped'

module EveryPoliticianScraper
  # standardise the interface to running a scraper
  class ScraperData
    def initialize(url, klass = Legislature::Members)
      @url = url
      @klass = klass
    end

    def csv
      header + rows.join
    end

    private

    attr_reader :url, :klass

    def data
      @data ||= klass.new(response: Scraped::Request.new(url: url).response).members
    end

    def header
      data.first.keys.to_csv
    end

    def rows
      data.map { |row| row.values.to_csv }
    end
  end
end
