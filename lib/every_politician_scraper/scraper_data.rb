# frozen_string_literal: true

require 'csv'
require 'scraped'
require 'wikidata_ids_decorator'
require_relative 'wpdates'

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

# Decorator to change ZeroWidthSpaces to regualar ones
class ReplaceZeroWidthSpaces < Scraped::Response::Decorator
  def body
    super.gsub(/[\u200B-\u200D\uFEFF]/, ' ')
  end
end

# Decorator to remove all References
class RemoveReferences < Scraped::Response::Decorator
  def body
    Nokogiri::HTML(super).tap do |doc|
      doc.css('sup').remove
    end.to_s
  end
end

# Decorator to Unspan all tables
class UnspanAllTables < Scraped::Response::Decorator
  require 'table_unspanner'

  def body
    Nokogiri::HTML(super).tap do |doc|
      doc.css('table.wikitable').each do |table|
        unspanned_table = TableUnspanner::UnspannedTable.new(table)
        table.children = unspanned_table.nokogiri_node.children
      end
    end.to_s
  end
end

# Base class for a table of Officeholders
# TODO: rename this to not be confused with the List version
class OfficeholderListBase < Scraped::HTML
  field :members do
    raise 'No holder_entries found' if holder_entries.empty?

    member_items.reject(&:empty?).map(&:to_h).uniq
  end

  def member_items
    holder_entries.map { |ul| fragment(ul => member_class) }
  end

  private

  def member_class
    ::OfficeholderList::Officeholder
  end

  def holder_entries
    noko.xpath("//table[.//th[contains(.,'#{header_column}')]][#{table_number}]//tr[td]")
  end

  def header_column
    raise 'need to define a header_column'
  end

  def table_number
    'last()'
  end

  # Base class for a single entry in the list of Officeholders
  class OfficeholderBase < Scraped::HTML # rubocop:todo Metrics/ClassLength
    LANG = {
      ar: WikipediaDate::Arabic,
      be: WikipediaDate::Belarussian,
      bg: WikipediaDate::Bulgarian,
      ca: WikipediaDate::Catalan,
      de: WikipediaDate::German,
      el: WikipediaDate::Greek,
      es: WikipediaDate::Spanish,
      et: WikipediaDate::Estonian,
      fr: WikipediaDate::French,
      hu: WikipediaDate::Hungarian,
      id: WikipediaDate::Indonesian,
      it: WikipediaDate::Italian,
      lb: WikipediaDate::Luxembourgish,
      lt: WikipediaDate::Lithuanian,
      nl: WikipediaDate::Dutch,
      pt: WikipediaDate::Portuguese,
      ro: WikipediaDate::Romanian,
      ru: WikipediaDate::Russian,
      sk: WikipediaDate::Slovak,
      tr: WikipediaDate::Turkish,
      uk: WikipediaDate::Ukrainian,
      vi: WikipediaDate::Vietnamese,
    }.freeze

    def empty?
      non_data_row? || vacant? || too_early?
    end

    field :item do
      return name_node.attr('wikidata') if name_node

      name_cell.css('a/@wikidata').map(&:text).first
    end

    field :itemLabel do
      return name_node.text.tidy if name_node

      name_link_text || name_cell.text.tidy
    end

    field :startDate do
      return combo_date.first if combo_date?

      date_class.new(raw_start).to_s
    end

    field :endDate do
      return combo_date.last if combo_date?

      date_class.new(raw_end).to_s
    end

    private

    def raw_start
      return combo_date.first if combo_date?
      return start_cell.xpath('.//text()').map(&:text).map(&:tidy).reject(&:empty?).join(' ').tidy if multi_line_dates?

      start_cell.text.gsub(/\(.*?\)/, '').tidy
    end

    def raw_end
      return combo_date.last if combo_date?
      return end_cell.xpath('.//text()').map(&:text).map(&:tidy).reject(&:empty?).join(' ').tidy if multi_line_dates?

      end_cell.text.gsub(/\(.*?\)/, '').delete('†').tidy
    end

    def tds
      noko.css('th,td')
    end

    # Override this if the name is only one of multiple links within the cell
    def name_node
      nil
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

    # override this if year is on a different line to the day+month
    def multi_line_dates?
      false
    end

    def raw_combo_date
      combo_date_cell.text
    end

    def combo_date
      WikipediaComboDate.new(raw_combo_date, date_class)
    end

    def ignore_before
      2000
    end

    def non_data_row?
      (tds.first.text == tds.last.text)
    end

    def vacant?
      itemLabel.to_s.tidy.empty?
    end

    def too_early?
      end_year && (end_year < ignore_before)
    end

    def start_year
      startDate[0...4].to_i
    end

    def end_year
      return if endDate.to_s.empty?

      endDate[0...4].to_i
    end

    def name_link_text
      name_cell.css('a').map(&:text).map(&:tidy).first
    end

    def columns
      raise 'Need to define the columns'
    end

    def date_class
      LANG.fetch(url[/(\w+)\.wikipedia.org/, 1].to_sym, WikipediaDate)
    end
  end
end

# Base class for a list of Officeholders
class OfficeholderNonTableBase < OfficeholderListBase::OfficeholderBase
  def empty?
    too_early?
  end

  def combo_date?
    true
  end

  def raw_combo_date
    raise 'need to define a raw_combo_date'
  end

  def name_node
    raise 'need to define a name_node'
  end
end

# Base class for Wikipedia table of Cabinet members
class WikiCabinetTable < OfficeholderListBase
  # TODO: harmonise
  field :members do
    member_items.flat_map do |member|
      data = member.to_h
      [data.delete(:positionLabel)].flatten.map { |posn| data.merge(positionLabel: posn) }
    end.uniq
  end

  def member_items
    super.reject(&:skip?)
  end
end

# Base class for Cabinet Member in a Wikipedia table
class WikiCabinetMember < OfficeholderListBase::OfficeholderBase
  field :position do
    position_node.attr('wikidata') if position_node
  end

  field :positionLabel do
    position_node.text.tidy if position_node
  end

  field :party do
    party_node.attr('wikidata') if party_node
  end

  field :partyLabel do
    party_node.text.tidy if party_node
  end

  def startDate
    (cell_for('start') || cell_for('dates')) ? super : nil
  end

  def endDate
    (cell_for('end') || cell_for('dates')) ? super : nil
  end

  def skip?
    false
  end

  # TODO: push this further up the hierarchy
  def cell_for(title)
    tds.at(columns.index(title))
  end

  private

  def position_node
    position_cell&.at_css('a') || position_cell
  end

  def position_cell
    cell_for('position')
  end

  def party_node
    party_cell&.at_css('a') || party_cell
  end

  def party_cell
    cell_for('party')
  end
end

# Members of a legislature table on Wikipedia
#   mostly the same as Cabinet, but with a built-in area
class WikiLegislatureMember < WikiCabinetMember
  field :area do
    area_node.attr('wikidata') if area_node
  end

  field :areaLabel do
    area_node.text.tidy if area_node
  end

  private

  def area_node
    area_cell&.at_css('a') || area_cell
  end

  def area_cell
    cell_for('area')
  end
end
