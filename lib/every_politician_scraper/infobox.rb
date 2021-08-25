# frozen_string_literal: true

require 'date'
require 'json'
require 'scraped'

# remove trailing number, and standardise 'Order' to 'Office'
class Symbol
  def unnumbered
    to_s.sub(/\d+$/, '').sub('order', 'office').to_sym
  end
end

# Parse a (potentially partial) date
class DateString
  MONTHS = %w[
    nil January February March April May June July August September October November December
  ].freeze

  def initialize(str)
    @str = str.tidy
  end

  def to_s
    parsed_date
  end

  private

  attr_reader :str

  def parts
    str.split(/\s+/)
  end

  def ruby_date
    Date.parse(str).to_s rescue nil
  end

  def parsed_date
    return str if year_only?
    return "#{year}-#{month}" if month_year?

    ruby_date
  end

  def final_part_looks_like_year?
    parts.last =~ /^(\d{4})$/
  end

  def penultimate_part_looks_like_month?
    MONTHS.include? parts[-2]
  end

  def year
    raise "Unknown date format: #{str}" unless final_part_looks_like_year?

    parts.last
  end

  def month
    raise "Unknown date format: #{str}" unless penultimate_part_looks_like_month?

    format('%02d', MONTHS.index { |mon| mon == parts[-2] })
  end

  def year_only?
    (parts.count == 1)
  end

  def month_year?
    (parts.count == 2)
  end
end

module EveryPolitician
  # a Wikipedia Infobox
  class Infobox
    # A Wikilink
    class Link
      def initialize(data)
        @data = data
      end

      def stated_as
        data[:text]
      end

      def links
        (data[:links] || []).map { |link| link[:page] }
      end

      def to_h
        { links: links, stated_as: stated_as }
      end

      private

      attr_reader :data
    end

    # A person can have held one or more positions one or more times
    class Position
      def initialize(data)
        @data = data
      end

      def command_data
        {
          office: office.to_h,
          P580:   start_time,
          P582:   end_time,
          P1365:  replaces ? replaces.to_h : nil,
          P1366:  replaced_by ? replaced_by.to_h : nil,
        }.compact
      end

      private

      attr_reader :data

      def office
        Link.new(data[:office])
      end

      def start_time
        return unless term_start_raw

        DateString.new(term_start_raw).to_s
      end

      def end_time
        return unless term_end_raw

        DateString.new(term_end_raw).to_s
      end

      def replaces
        return unless predecessor

        Link.new(predecessor)
      end

      def replaced_by
        return unless successor

        Link.new(successor)
      end

      def term_start_raw
        data.dig(:term_start, :text) || data.dig(:termstart, :text) || combo_term_parts.first
      end

      def term_end_raw
        data.dig(:term_end, :text) || data.dig(:termend, :text) || combo_term_parts.last
      end

      def successor
        data[:successor]
      end

      def predecessor
        data[:predecessor]
      end

      def combo_term
        data.dig(:term, :text)
      end

      def combo_term_parts
        return [nil, nil] unless combo_term

        combo_term.split(/ (?:to|-) /, 2)
      end
    end

    def initialize(raw_json)
      @raw_json = raw_json
    end

    def positions
      filled_offices.compact.map { |office| Position.new(office) }
    end

    def title
      json[:title]
    end

    private

    def json
      @json ||= JSON.parse(raw_json, symbolize_names: true)
    end

    def infobox_hash
      @infobox_hash ||= json[:sections].flat_map { |section| section[:infoboxes] }.compact.flatten
                                       .find { |box| box.transform_keys(&:unnumbered).key?(:office) } || {}
    end

    def offices
      @offices ||= infobox_hash
                   .group_by { |key, _| (key[/(\d+)$/, 1] || 0) }
                   .sort_by { |key, _v| key.to_i }
                   .map { |_, val| val.to_h.transform_keys(&:unnumbered) }
    end

    def filled_offices
      offices.each_with_index.map do |office, index|
        next_office = offices[index + 1]
        next_office[:office] ||= office[:office] if next_office
        office if office.key?(:office)
      end
    end

    attr_reader :raw_json
  end
end
