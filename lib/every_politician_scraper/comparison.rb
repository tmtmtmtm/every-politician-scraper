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

  # default set of decorators for comparisons.
  # This is not the preferred method to do this, but a stopgap until
  # everything can be migrated to a more explicit route.
  class DecoratedComparison < Comparison
    def diff
      DaffDiff::Decorator.new(
        cell_class: DaffDiff::Decorator::Nullless,
        data:       DaffDiff::Decorator.new(
          cell_class: DaffDiff::Decorator::DatePrecision,
          data:       super
        ).decorated
      ).decorated
    end
  end
end

module DaffDiff
  # Decorate the diff output from daff
  class Decorator
    def initialize(data:, table_class: Table, row_class: Row, cell_class: Cell)
      @data = data
      @table_class = table_class
      @row_class = row_class
      @cell_class = cell_class
    end

    def decorated
      table_class.new(data, row_class, cell_class).data
    end

    private

    attr_reader :data, :table_class, :row_class, :cell_class
  end

  # the whole Daff Table
  class Table
    def initialize(table, row_class, cell_class)
      @table = table
      @row_class = row_class
      @cell_class = cell_class
    end

    def data
      table.map { |row| row_class.new(row, header_row, cell_class).data }.compact
    end

    private

    attr_reader :table, :row_class, :cell_class

    def header_row
      table.first
    end
  end

  # a row of a Daff Table
  class Row
    def initialize(row, header_row, cell_class)
      @row = row
      @header_row = header_row
      @cell_class = cell_class
    end

    def data
      return row unless change_row?
      return nil unless still_has_diffs?

      decorated
    end

    private

    attr_reader :row, :header_row, :cell_class

    def decorated
      @decorated ||= row.each_with_index.map { |cell, index| cell_class.new(cell, header_row[index]).transformed }
    end

    def change_row?
      row.first == '->'
    end

    def still_has_diffs?
      decorated.drop(1).any? { |cell| cell.to_s.include? '->' }
    end
  end

  # a cell from a Daff Table
  class Cell
    def initialize(data, field)
      @data = data
      @field = field
    end

    def transformed
      return data unless data.is_a?(String)
      return data if     data == '->' # row type, not an actual diff
      return data unless data.include? '->'

      clean_data
    end

    def diff?
      data.to_s.include? '->'
    end

    def clean_data
      raise 'Subclass needs to provide #clean_data'
    end

    private

    attr_reader :data, :field

    def scraped
      data.split('->', 2).last
    end

    def wikidata
      data.split('->', 2).first
    end
  end

  class Decorator
    # Don't complain if Wikidata has higher precision date than the source
    # e.g. 2008-05-13 vs 2008 or 2008-05
    class DatePrecision < DaffDiff::Cell
      def clean_data
        return data unless field.to_s.include? 'date'
        return wikidata if wikidata.include?(scraped)

        data
      end
    end

    # Don't complain if Wikidata has a value where the external source doesn't
    class Nullless < DaffDiff::Cell
      def clean_data
        data.gsub('->NULL', '')
      end
    end
  end
end
