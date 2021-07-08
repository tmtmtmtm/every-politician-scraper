# frozen_string_literal: true

require 'csv'
require 'daff'

module EveryPoliticianScraper
  # Diff between two CSV files
  class Comparison
    def initialize(wikidata_source, official_source)
      @wikidata_source = wikidata_source
      @official_source = official_source
    end

    def diff
      highlighter.hilite(Daff::TableView.new(data_diff = []))
      data_diff
    end

    private

    attr_reader :wikidata_source, :official_source

    def wikidata
      @wikidata ||= CSV.table('data/wikidata.csv')
    end

    def official
      @official ||= CSV.table('data/official.csv')
    end

    def columns
      wikidata.headers & official.headers
    end

    def wikidata_tc
      [columns, *wikidata.map { |row| row.values_at(*columns) }]
    end

    def official_tc
      [columns, *official.map { |row| row.values_at(*columns) }]
    end

    def wikidata_tv
      Daff::TableView.new(wikidata_tc)
    end

    def official_tv
      Daff::TableView.new(official_tc)
    end

    def alignment
      Daff::Coopy.compare_tables(wikidata_tv, official_tv).align
    end

    # Ugh. :reek:FeatureEnvy
    def highlighter
      flags = Daff::CompareFlags.new
      flags.ordered = false
      flags.unchanged_context = 0
      flags.show_unchanged_columns = true
      Daff::TableDiff.new(alignment, flags)
    end
  end
end
