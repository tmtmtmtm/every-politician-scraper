# frozen_string_literal: true

require 'date'
require 'json'

# remove trailing number, and standardise 'Order' to 'Office'
class Symbol
  def unnumbered
    to_s.sub(/\d+$/, '').sub('order', 'office').to_sym
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

        Date.parse(term_start_raw).to_s rescue term_start_raw
      end

      def end_time
        return unless term_end_raw

        Date.parse(term_end_raw).to_s rescue term_end_raw
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
        data.dig(:term_start, :text) || data.dig(:termstart, :text)
      end

      def term_end_raw
        data.dig(:term_end, :text) || data.dig(:termend, :text)
      end

      def successor
        data[:successor]
      end

      def predecessor
        data[:predecessor]
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
