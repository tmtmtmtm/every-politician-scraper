# frozen_string_literal: true

require 'csv'
require 'scraped'
require 'table_unspanner'
require 'wikidata_ids_decorator'

# scraped Stragegy for reading a file rather than URL
class LocalFileRequest < Scraped::Request::Strategy
  def response
    { body: Pathname.new(url).read }
  end
end

module EveryPoliticianScraper
  # standardise the interface to running a scraper
  class ScraperData
    def initialize(urls, klass: MemberList::Members, headers: {})
      @urls = [urls].flatten
      @klass = klass
      @headers = headers
    end

    def csv
      header + rows.join
    end

    private

    attr_reader :urls, :headers, :klass

    def data
      @data ||= urls.flat_map do |url|
        klass.new(response: request(url).response).members
      end
    end

    def request(url)
      Scraped::Request.new(url: url, headers: headers)
    end

    def header
      data.first.keys.to_csv
    end

    def rows
      data.map { |row| row.values.to_csv }
    end
  end

  # Scraping a file on disk, e.g. downloaded via curl
  class FileData < ScraperData
    def request(url)
      Scraped::Request.new(url: url, headers: headers, strategies: [LocalFileRequest])
    end
  end
end

class CabinetMemberList
  # base class for an individual member
  class Member < Scraped::HTML
    field :name do
      abort('Scraper should provide a #name method')
    end

    field :position do
      abort('Scraper should provide a #position method')
    end
  end

  # base class for the list of members
  class Members < Scraped::HTML
    field :members do
      member_items.flat_map do |member|
        data = member.to_h
        [data.delete(:position)].flatten.map { |posn| data.merge(position: posn) }
      end.uniq
    end

    def member_class
      ::CabinetMemberList::Member
    end

    def member_items
      member_container.map { |member| fragment(member => member_class) }
    end
  end
end

class MemberList
  # details for an individual member
  class Member < CabinetMemberList::Member
    # A politician's name, from which prefixes and suffixes can be removed
    class Name
      def initialize(full:, prefixes: [], suffixes: [])
        @full = full
        @prefixes = prefixes
        @suffixes = suffixes
      end

      def short
        suffixes.reduce(unprefixed) { |current, suffix| current.sub(/ #{suffix},?\s?$/, ' ').tidy }
      end

      private

      attr_reader :full, :prefixes, :suffixes

      def unprefixed
        prefixes.reduce(full) { |current, prefix| " #{current}".sub(/ #{prefix}\.? /i, ' ') }.tidy
      end
    end
  end

  # The page listing all the members
  class Members < CabinetMemberList::Members
    def member_class
      Member
    end
  end
end

#-----------------------------------------------------------------------
# Interacting with a table of officeholders
#   e.g. on a "List of Attorney Generals of Placeistan" page
#-----------------------------------------------------------------------

# Handle a variety of date formats seen on Wikipedia
# Subclass this to remap foreign language dates
class WikipediaDate
  REMAP = {
    'Incumbent' => '',
    'incumbent' => '',
    'Present'   => '',
  }.freeze

  def initialize(date_str)
    @date_str = date_str
  end

  def to_s
    return if date_en.to_s.empty?
    return date_obj.to_s if format_ymd?
    return date_obj_ym if format_ym?
    return date_en if format_y?

    raise "Unknown date format: #{date_en}"
  end

  private

  attr_reader :date_str

  def date_obj
    @date_obj ||= Date.parse(date_en)
  end

  def date_obj_ym
    date_obj.to_s[0...7]
  end

  def date_en
    @date_en ||= REMAP.reduce(date_str) { |str, (ro, en)| str.sub(ro, en) }
  end

  def format_ymd?
    (date_en =~ /^\d{1,2} \w+ \d{4}$/) || (date_en =~ /^\w+ \d{1,2}, \d{4}$/)
  end

  def format_ym?
    date_en =~ /^\w+ \d{4}$/
  end

  def format_y?
    date_en =~ /^\d{4}$/
  end
end

# Decorator to remove all References
class RemoveReferences < Scraped::Response::Decorator
  def body
    Nokogiri::HTML(super).tap do |doc|
      doc.css('sup.reference').remove
    end.to_s
  end
end

# Decorator to Unspan all tables
class UnspanAllTables < Scraped::Response::Decorator
  def body
    Nokogiri::HTML(super).tap do |doc|
      doc.css('table.wikitable').each do |table|
        unspanned_table = TableUnspanner::UnspannedTable.new(table)
        table.children = unspanned_table.nokogiri_node.children
      end
    end.to_s
  end
end

# Base class for a list of Officeholders
class OfficeholderListBase < Scraped::HTML
  field :members do
    holder_entries.map { |ul| fragment(ul => member_class) }.reject(&:empty?).map(&:to_h).uniq
  end

  private

  def member_class
    ::OfficeholderList::Officeholder
  end

  def holder_entries
    noko.xpath("//table[.//th[contains(.,'#{header_column}')]][last()]//tr[td]")
  end

  def header_column
    raise 'need to define a header_column'
  end

  # Base class for a single entry in the list of Officeholders
  class OfficeholderBase < Scraped::HTML
    def empty?
      tds.first.text == tds.last.text
    end

    field :item do
      name_cell.css('a/@wikidata').map(&:text).first
    end

    field :itemLabel do
      name_link_text || name_cell.text.tidy
    end

    field :startDate do
      date_class.new(raw_start).to_s
    end

    field :endDate do
      date_class.new(raw_end).to_s
    end

    private

    def raw_start
      return combo_date.first if combo_date?

      start_cell.text.tidy
    end

    def raw_end
      return combo_date.last if combo_date?

      end_cell.text.tidy
    end

    def tds
      noko.css('td')
    end

    def name_cell
      tds[columns.index('name')]
    end

    def start_cell
      tds[columns.index('start')]
    end

    def end_cell
      tds[columns.index('end')]
    end

    def combo_date_cell
      tds[columns.index('dates')]
    end

    def combo_date?
      columns.include? 'dates'
    end

    def raw_combo_date
      combo_date_cell.text.split(/[—–-]/).map(&:tidy)
    end

    def combo_date
      rstart, rend = raw_combo_date
      # Add missing year if in format "April 8 - May 20 2019"
      return ["#{rstart}, #{rend[-4..]}", rend] unless rstart[/\d{4}$/]

      [rstart, rend]
    end

    def name_link_text
      name_cell.css('a').map(&:text).first
    end

    def columns
      raise 'Need to define the columns'
    end

    def date_class
      WikipediaDate
    end
  end
end
