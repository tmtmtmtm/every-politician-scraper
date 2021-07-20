# frozen_string_literal: true

require 'csv'
require 'scraped'

module EveryPoliticianScraper
  # standardise the interface to running a scraper
  class ScraperData
    def initialize(urls, klass: nil, headers: {})
      @urls = [urls].flatten
      @klass = klass
      @headers = headers
    end

    def csv
      header + rows.join
    end

    private

    attr_reader :urls, :headers

    # Allow either fallback, for backwards compatibility
    def klass
      return @klass if @klass

      ['MemberList::Members', 'Legislature::Members'].map do |klass|
        Object.const_get(klass) if Object.const_defined?(klass)
      end.compact.first
    end

    def data
      @data ||= urls.flat_map do |url|
        klass.new(response: Scraped::Request.new(url: url, headers: headers).response).members
      end
    end

    def header
      data.first.keys.to_csv
    end

    def rows
      data.map { |row| row.values.to_csv }
    end
  end
end
