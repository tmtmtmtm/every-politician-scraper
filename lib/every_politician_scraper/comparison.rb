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

  # A comparison where we don't care about things that want to be NULL
  #  i.e. where Wikidata has additional information that the source doesn't
  # We care if it exists, but is different, but not if it's missing
  class NulllessComparison < Comparison
    # bass class for working with Daff Table
    class DiffThing
      def initialize(data)
        @data = data
      end

      attr_reader :data
    end

    # the whole Daff Table
    class DiffTable < DiffThing
      def denulled
        data.map { |row| DiffRow.new(row).denulled }.compact
      end
    end

    # a row of a Daff Table
    class DiffRow < DiffThing
      def denulled
        return data if header_row?
        return nil unless still_has_diffs?

        remapped
      end

      private

      def remapped
        data.map { |cell| DiffCell.new(cell).denulled }
      end

      def header_row?
        data.first == '@@'
      end

      def still_has_diffs?
        remapped.drop(1).any? { |cell| cell.to_s.include? '->' }
      end
    end

    # a cell from a Daff Table
    class DiffCell < DiffThing
      def denulled
        data.is_a?(String) ? data.gsub('->NULL', '') : data
      end
    end

    def diff
      DiffTable.new(super).denulled
    end
  end
end
