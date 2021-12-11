# frozen_string_literal: true

require 'csv'
require 'daff'

module EveryPoliticianScraper
  # Diff between two CSV files
  class Comparison
    def initialize(wikidata_source, external_source)
      @wikidata_source = wikidata_source
      @external_source = external_source
    end

    def diff
      highlighter.hilite(Daff::TableView.new(data_diff = []))
      data_diff
    end

    private

    attr_reader :wikidata_source, :external_source

    def wikidata
      @wikidata ||= CSV.table(wikidata_source, wikidata_csv_options)
    end

    def external
      @external ||= CSV.table(external_source, external_csv_options)
    end

    def wikidata_csv_options
      {}
    end

    def external_csv_options
      {}
    end

    def columns
      wikidata.headers & external.headers
    end

    def wikidata_tc
      [columns, *wikidata.map { |row| row.values_at(*columns) }]
    end

    def external_tc
      [columns, *external.map { |row| row.values_at(*columns) }]
    end

    def wikidata_tv
      Daff::TableView.new(wikidata_tc)
    end

    def external_tv
      Daff::TableView.new(external_tc)
    end

    def alignment
      Daff::Coopy.compare_tables(wikidata_tv, external_tv).align
    end

    # Ugh. :reek:FeatureEnvy _and_ :reek:UtilityFunction
    def flags
      flags = Daff::CompareFlags.new
      flags.ordered = false
      flags.unchanged_context = 0
      flags.show_unchanged_columns = true
      flags
    end

    def highlighter
      Daff::TableDiff.new(alignment, flags)
    end
  end
end
