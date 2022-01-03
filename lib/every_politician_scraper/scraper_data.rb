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
  def initialize(date_str)
    @date_str = date_str
  end

  def to_s
    return if date_en.to_s.tidy.empty?
    return date_obj.to_s if format_ymd?
    return date_obj_ym if format_ym?
    return date_en if format_y?

    raise "Unknown date format: #{date_en}"
  end

  def remap
    {
      'Incumbent' => '',
      'incumbent' => '',
      'Present'   => '',
    }
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
    @date_en ||= remap.reduce(date_str) { |str, (local, eng)| str.to_s.sub(local, eng) }
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

  # Portuguese dates
  class Portuguese < WikipediaDate
    REMAP = {
      'atualidade'      => '',
      'em exercício'    => '',
      'de janeiro de'   => 'January',
      'de fevereiro de' => 'February',
      'de março de'     => 'March',
      'de abril de'     => 'April',
      'de maio de'      => 'May',
      'de junho de'     => 'June',
      'de julho de'     => 'July',
      'de agosto de'    => 'August',
      'de setembro de'  => 'September',
      'de outubro de'   => 'October',
      'de novembro de'  => 'November',
      'de dezembro de'  => 'December',
    }.freeze

    def date_str
      super.gsub('º', '')
    end

    def remap
      super.merge(REMAP)
    end
  end

  # Ukrainian dates
  class Ukrainian < WikipediaDate
    REMAP = {
      'по т.ч.'   => '',
      'січня'     => 'January',
      'лютого'    => 'February',
      'березня'   => 'March',
      'квітня'    => 'April',
      'травня'    => 'May',
      'червня'    => 'June',
      'липня'     => 'July',
      'серпня'    => 'August',
      'вересня'   => 'September',
      'жовтня'    => 'October',
      'листопада' => 'November',
      'грудня'    => 'December',
    }.freeze

    def remap
      super.merge(REMAP)
    end
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
      itemLabel.to_s.tidy.empty?
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
      combo_date_cell.text
    end

    def raw_combo_dates
      raw_combo_date.split(/[—–-]/).map(&:tidy)
    end

    def combo_date
      rstart, rend = raw_combo_dates
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
      return WikipediaDate::Portuguese if /pt.wikipedia.org/.match?(url)
      return WikipediaDate::Ukrainian if /uk.wikipedia.org/.match?(url)

      WikipediaDate
    end
  end
end
