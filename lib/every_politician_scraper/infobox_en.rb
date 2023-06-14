# frozen_string_literal: true

require 'json'
require 'every_politician_scraper/wpdates'
require 'pry'

class String
  def deordinaled
    ordinal = '\d+[snrt][tdh]'
    tidy.gsub(/^#{ordinal} (and|&) #{ordinal} /, '').gsub(/^#{ordinal} /, '')
  end
end

module InfoboxEN
  class Mandate
    POSITION = %w[office order title succession jr/sr parliament
                  state_house state_senate state_assembly assembly
                  state_delegate constituency_mp constituency_am
                  state district amabassador_from].freeze
    BEGAN = %w[term_start termstart].freeze
    ENDED = %w[term_end termend].freeze
    TERM = %w[term reign].freeze

    def initialize(origjson)
      @origjson = origjson
    end

    def to_h
      {
        order:         origjson.keys.first[/(\d+)$/, 1].to_i,
        positionLabel: position_label.deordinaled,
        startDate:     start_date,
        endDate:       end_date,
      }
    end

    private

    attr_reader :origjson

    # strip off the position number, and transform 'subterm' etc
    def json
      @json ||= origjson.transform_keys { |key| key.sub(/\d+$/, '').delete_prefix('sub') }
    end

    def first_of_type(arr)
      json.values_at(*arr).compact.first
    end

    def position
      first_of_type(POSITION) || {}
    end

    # There's a lot of extra logic in the Officeholder template
    #   https://en.wikipedia.org/w/index.php?title=Template:Infobox_officeholder/office&action=edit
    def position_label
      return "ambassador to #{json.dig('country', 'text') || '?'}" if json.key?('ambassador_from')
      return "#{json.dig('parliament', 'text')} MP" if json.key?('constituency_mp') && json.key?('parliament')
      return "Member of Parliament" if json.key?('constituency_mp')
      return "Member of the #{json.dig('assembly', 'text')} Assembly" if json.key?('assembly')
      return "Member of the #{json.dig('state_delegate', 'text')} House of Delegates" if json.key?('state_delegate')
      return 'Senator' if json.key?('jr/sr')
      return "#{json.dig('parliament', 'text')} MP" if json.key?('parliament')
      return "#{json.dig('state_house', 'text')} State Representative" if json.key?('state_house')
      return "#{json.dig('state_legislature', 'text')} State Legislator" if json.key?('state_legislature')
      return "#{json.dig('state_senate', 'text')} State Senator" if json.key?('state_senate')
      return "#{json.dig('state_assembly', 'text')} State Assembly Member" if json.key?('state_assembly')
      return "Member of the U.S. House of Representatives" if json.key?('state') && json.key?('constituency')
      return "Member of the U.S. House of Representatives" if json.key?('state') && json.key?('district')

      position['text'].to_s.tidy
    end

    def term
      first_of_type(TERM)
    end

    def term_parts
      return [] unless term
      return term['text'].split(' to ', 2) if term['text'].include? ' to '

      term['text'].split(/\s*[-–—]\s*/, 2)
    end

    def began
      first_of_type(BEGAN) || {}
    end

    def ended
      first_of_type(ENDED) || {}
    end

    def raw_start
      began['text'] || term_parts[0]
    end

    def raw_end
      ended['text'] || term_parts[1]
    end

    def start_date
      return if raw_start.to_s.empty?

      WikipediaDate.new(raw_start.to_s.tidy).to_s rescue raw_start.tidy
    end

    def end_date
      return if raw_end.to_s.empty?

      WikipediaDate.new(raw_end.to_s.tidy).to_s rescue raw_end.tidy
    end
  end

  class Infobox
    def initialize(raw)
      @raw = raw
    end

    # If a mandate has no positionLabel, fill it from the previous one
    def mandates
      raw_sorted_mandates.each_with_index do |mandate, idx|
        mandate[:positionLabel] = raw_sorted_mandates[idx - 1][:positionLabel] if
          mandate[:positionLabel].to_s.empty? && !idx.zero?
      end
    end

    private

    attr_reader :raw

    def grouped
      raw.group_by { |key, _| key.match(/\d*$/)[0].to_i }.sort_by(&:first).map(&:last).map(&:to_h)
    end

    def raw_mandates
      grouped.map { |entry| InfoboxEN::Mandate.new(entry).to_h rescue {} } rescue []
    end

    def raw_sorted_mandates
      @raw_sorted_mandates ||= raw_mandates.sort_by { |h| h[:order] }
    end
  end

  class JSON
    def initialize(raw)
      @raw = raw
    end

    def mandates
      infoboxes.flat_map { |box| Infobox.new(box).mandates }
    end

    private

    attr_reader :raw

    def parsed
      @parsed ||= ::JSON.parse(raw)
    end

    def infoboxes
      parsed['sections'].flat_map { |section| section['infoboxes'] }.compact
    end
  end
end
