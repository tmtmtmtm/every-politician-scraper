# frozen_string_literal: true

require 'date'
require 'json'
require 'scraped'

# remove trailing number, and standardise 'Order' to 'Office'
class Symbol
  def unnumbered
    to_s.sub(/\d+$/, '').to_sym
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

# Transform Slovenian dates into English ones
class DateStringSL < DateString
  REMAP = %w[ZZZ januar februar marec aprila maj junij julij avgust september oktober november december].freeze
  MONTHS_RE = Regexp.new REMAP.join('|')

  def str
    super.gsub(MONTHS_RE) { |match| MONTHS[REMAP.index(match)] }
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
      def initialize(data, lang)
        @data = data
        @lang = lang
      end

      def command_data
        {
          office: office.to_h,
          P768:   constituency,
          P1545:  ordinal.zero? ? nil : ordinal.to_s,
          P580:   start_time,
          P1365:  replaces,
          P582:   end_time,
          P1366:  replaced_by,
        }.compact
      end

      private

      attr_reader :data, :lang

      def dateclass
        return DateStringSL if lang == 'sl'

        DateString
      end

      def office
        Link.new(data[:office])
      end

      def start_time
        return unless term_start_raw

        dateclass.new(term_start_raw).to_s
      end

      def end_time
        return unless term_end_raw

        dateclass.new(term_end_raw).to_s
      end

      def constituency
        raw = data[:constituency] or return

        Link.new(raw).to_h
      end

      def replaces
        raw = data[:predecessor] or return

        Link.new(raw).to_h
      end

      def replaced_by
        raw = data[:successor] or return

        Link.new(raw).to_h
      end

      def ordinal
        data.dig(:order, :text).to_i
      end

      def term_start_raw
        data.dig(:term_start, :text) || data.dig(:termstart, :text) || combo_term_parts.first
      end

      def term_end_raw
        data.dig(:term_end, :text) || data.dig(:termend, :text) || combo_term_parts.last
      end

      def combo_term
        data.dig(:term, :text)
      end

      def combo_term_parts
        return [nil, nil] unless combo_term

        combo_term.split(/\s*(?:to|-|–)\s*/, 2)
      end
    end

    def initialize(raw_json, lang = 'en')
      @raw_json = raw_json
      @lang     = lang
    end

    def positions
      filled_offices.compact.map { |office| Position.new(office, lang) }
    end

    def title
      json[:title]
    end

    private

    def json
      @json ||= JSON.parse(raw_json, symbolize_names: true)
    end

    def infoboxes
      json[:sections].flat_map { |section| section[:infoboxes] }.compact.flatten
    end

    def infoboxes_with_positions
      infoboxes.select { |box| (box.transform_keys(&:unnumbered).keys & %i[office order parliament constituency_mp]).any? }
    end

    def infobox_hash
      @infobox_hash ||= infoboxes_with_positions.reduce(&:merge)
    end

    def offices
      @offices ||= infobox_hash.group_by { |key, _| (key[/(\d+)$/, 1] || 0) }
                               .map { |num, rows| InfoboxSection.new(num, rows) }
                               .sort_by(&:num)
                               .map(&:to_h)
    end

    def filled_offices
      offices.each_with_index.map do |office, index|
        this_office = office[:office] || next
        next_office = offices[index + 1]
        next_office[:office] ||= this_office if next_office
        office
      end
    end

    attr_reader :raw_json, :lang
  end

  # A section of an Infobox, usually relating to a Position held
  #   based on each 'key' ending with the same number
  class InfoboxSection
    def initialize(num, rows)
      @num = num.to_i
      @rows = rows
    end

    def office
      return { text: 'Member of Parliament' } if hash[:constituency_mp] || hash[:riding]

      hash.values_at(:office, :order).compact.first
    end

    def to_h
      hash.merge(
        office:       office,
        constituency: hash[:constituency_mp] || hash[:riding]
      )
    end

    attr_reader :num, :rows

    def hash
      @hash = rows.to_h.transform_keys(&:unnumbered)
    end
  end
end
