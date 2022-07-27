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
class String
  def zeropad2
    rjust(2, '0')
  end
end

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
      'present'   => '',
      'current'   => '',
      'Current'   => '',
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
    (date_en =~ /^\d{1,2} \w+,? \d{4}$/) || (date_en =~ /^\w+ \d{1,2}, \d{4}$/)
  end

  def format_ym?
    date_en =~ /^\w+ \d{4}$/
  end

  def format_y?
    date_en =~ /^\d{4}$/
  end

  # Dates in the form 24.12.2007
  class DottedDMY < WikipediaDate
    def to_s
      date_en.to_s.split('.').reverse.join('-')
    end
  end

  # Arabic dates
  class Arabic < WikipediaDate
    REMAP = {
      'حتى الأن'     => '',
      'يناير'        => 'January',
      'كانون الثاني' => 'January',
      'شباط'         => 'February',
      'فبراير'       => 'February',
      'آذار'         => 'March',
      'مارس'         => 'March',
      'نيسان'        => 'April',
      'أبريل'        => 'April',
      'مايو'         => 'May',
      'أيار'         => 'May',
      'يونيو'        => 'June',
      'حزيران'       => 'June',
      'يوليو'        => 'July',
      'تموز'         => 'July',
      'أغسطس'        => 'August',
      'آب'           => 'August',
      'أيلول'        => 'September',
      'سبتمبر'       => 'September',
      'أكتوبر'       => 'October',
      'تشرين الأول'  => 'October',
      'نوفمبر'       => 'November',
      'تشرين الثاني' => 'November',
      'كانون الأول'  => 'December',
      'ديسمبر'       => 'December',
    }.freeze

    def remap
      super.merge(REMAP)
    end
  end

  # Belarussian dates
  class Belarussian < WikipediaDate
    REMAP = {
      'студзеня'    => 'January',
      'лютага'      => 'February',
      'сакавіка'    => 'March',
      'Красавік'    => 'April',
      'мая'         => 'May',
      'чэрвеня'     => 'June',
      'Ліпень'      => 'July',
      'ліпеня'      => 'July',
      'жніўня'      => 'August',
      'верасня'     => 'September',
      'кастрычніка' => 'October',
      'лістапада'   => 'November',
      'Снежань'     => 'December',
      'снежня'      => 'December',
    }.freeze

    def remap
      REMAP.merge(super)
    end
  end

  # Bulgarian dates
  class Bulgarian < WikipediaDate
    REMAP = {
      '…'         => '',
      'януари'    => 'January',
      'февруари'  => 'February',
      'март'      => 'March',
      'април'     => 'April',
      'май'       => 'May',
      'юни'       => 'June',
      'юли'       => 'July',
      'август'    => 'August',
      'септември' => 'September',
      'октомври'  => 'October',
      'ноември'   => 'November',
      'декември'  => 'December',
    }.freeze

    def remap
      REMAP.merge(super)
    end
  end

  # Dutch dates
  class Dutch < WikipediaDate
    REMAP = {
      'januari'   => 'January',
      'februari'  => 'February',
      'maart'     => 'March',
      'april'     => 'April',
      'mei'       => 'May',
      'juni'      => 'June',
      'juli'      => 'July',
      'augustus'  => 'August',
      'september' => 'September',
      'oktober'   => 'October',
      'november'  => 'November',
      'december'  => 'December',
    }.freeze

    def remap
      REMAP.merge(super)
    end
  end

  # Estonian dates
  class Estonian < WikipediaDate
    REMAP = {
      'januaar'   => 'January',
      'veebruar'  => 'February',
      'marts'     => 'March',
      'aprill'    => 'April',
      'mai'       => 'May',
      'juuni'     => 'June',
      'juuli'     => 'July',
      'august'    => 'August',
      'september' => 'September',
      'oktoober'  => 'October',
      'november'  => 'November',
      'detsember' => 'December',
    }.freeze

    def remap
      REMAP.merge(super)
    end
  end

  # French dates
  class French < WikipediaDate
    REMAP = {
      "aujourd'hui" => '',
      "auj."        => '',
      'en cours'    => '',
      'januar'      => 'January',
      'février'     => 'February',
      'mars'        => 'March',
      'avril'       => 'April',
      'mai'         => 'May',
      'juin'        => 'June',
      'juillet'     => 'July',
      'août'        => 'August',
      'septembre'   => 'September',
      'octobre'     => 'October',
      'novembre'    => 'November',
      'décembre'    => 'December',
    }.freeze

    def remap
      REMAP.merge(super)
    end

    def date_str
      super.gsub('1er', '1')
    end
  end

  # German dates
  class German < WikipediaDate
    REMAP = {
      'amtierend' => 'Incumbent',
      'Januar'    => 'January',
      'Jänner'    => 'January',
      'Februar'   => 'February',
      'März'      => 'March',
      'April'     => 'April',
      'Mai'       => 'May',
      'Juni'      => 'June',
      'Juli'      => 'July',
      'August'    => 'August',
      'September' => 'September',
      'Oktober'   => 'October',
      'November'  => 'November',
      'Dezember'  => 'December',
    }.freeze

    def date_str
      super.gsub(/(\d+)\./, '\1')
    end

    def remap
      REMAP.merge(super)
    end
  end

  # Indonesian dates
  class Indonesian < WikipediaDate
    REMAP = {
      'Petahana'  => '',
      'Januari'   => 'January',
      'Februari'  => 'February',
      'Maret'     => 'March',
      'April'     => 'April',
      'Mei'       => 'May',
      'Juni'      => 'June',
      'Juli'      => 'July',
      'Agustus'   => 'August',
      'September' => 'September',
      'Oktober'   => 'October',
      'November'  => 'November',
      'Desember'  => 'December',
    }.freeze

    def remap
      REMAP.merge(super)
    end
  end

  # Italian dates
  class Italian < WikipediaDate
    REMAP = {
      'in carica' => '',
      'gennaio'   => 'January',
      'febbraio'  => 'February',
      'marzo'     => 'March',
      'aprile'    => 'April',
      'maggio'    => 'May',
      'giugno'    => 'June',
      'luglio'    => 'July',
      'agosto'    => 'August',
      'settembre' => 'September',
      'ottobre'   => 'October',
      'novembre'  => 'November',
      'dicembre'  => 'December',
    }.freeze

    def remap
      REMAP.merge(super)
    end
  end

  # Lithuanian dates
  class Lithuanian < WikipediaDate
    REMAP = {
      'dabar'     => '',
      'sausio'    => 'January',
      'vasario'   => 'February',
      'kovo'      => 'March',
      'balandžio' => 'April',
      'gegužės'   => 'May',
      'birželio'  => 'June',
      'liepos'    => 'July',
      'rugpjūčio' => 'August',
      'rugsėjo'   => 'September',
      'spalio'    => 'October',
      'lapkričio' => 'November',
      'gruodžio'  => 'December',
    }.freeze

    def date_en
      super.gsub(' m.', ' ').gsub(' d.', ' ').tidy.split.reverse.join(' ')
    end

    def remap
      REMAP.merge(super)
    end
  end

  # Luxembourgish dates
  class Luxembourgish < WikipediaDate
    REMAP = {
      'Januar'    => 'January',
      'Februar'   => 'February',
      'Mäerz'     => 'March',
      'Abrëll'    => 'April',
      'Mee'       => 'May',
      'Juni'      => 'June',
      'Juli'      => 'July',
      'August'    => 'August',
      'September' => 'September',
      'Oktober'   => 'October',
      'November'  => 'November',
      'Dezember'  => 'December',
    }.freeze

    def date_str
      super.gsub(/(\d+)\./, '\1')
    end

    def remap
      REMAP.merge(super)
    end
  end

  # Portuguese dates
  class Portuguese < WikipediaDate
    REMAP = {
      'até a atualidade' => '',
      'atualidade'       => '',
      'em exercício'     => '',
      'Em exercício'     => '',
      'presente'         => '',
      'de janeiro de'    => 'January',
      'de fevereiro de'  => 'February',
      'de março de'      => 'March',
      'de abril de'      => 'April',
      'de maio de'       => 'May',
      'de junho de'      => 'June',
      'de julho de'      => 'July',
      'de agosto de'     => 'August',
      'de setembro de'   => 'September',
      'de outubro de'    => 'October',
      'de novembro de'   => 'November',
      'de dezembro de'   => 'December',
    }.freeze

    def date_str
      super.gsub(/[º°]/, '')
    end

    def remap
      REMAP.merge(super)
    end
  end

  # Romanian dates
  class Romanian < WikipediaDate
    REMAP = {
      'prezent'    => '',
      'ianuarie'   => 'January',
      'februarie'  => 'February',
      'martie'     => 'March',
      'aprilie'    => 'April',
      'mai'        => 'May',
      'iunie'      => 'June',
      'iulie'      => 'July',
      'august'     => 'August',
      'septembrie' => 'September',
      'octombrie'  => 'October',
      'noiembrie'  => 'November',
      'decembrie'  => 'December',
    }.freeze

    def date_str
      super.gsub(/^din /, '')
    end

    def remap
      REMAP.merge(super)
    end
  end

  # Russian dates
  class Russian < WikipediaDate
    REMAP = {
      'по настоящее время' => '',
      'по н. вр.'          => '',
      'Настоящее время'    => '',
      'настоящее время'    => '',
      'наст. время'        => '',
      'в должности'        => '',
      'н. в.'              => '',
      'января'             => 'January',
      'январь'             => 'January',
      'февраля'            => 'February',
      'февраль'            => 'February',
      'марта'              => 'March',
      'март'               => 'March',
      'апреля'             => 'April',
      'апрель'             => 'April',
      'мая'                => 'May',
      'май'                => 'May',
      'июня'               => 'June',
      'июнь'               => 'June',
      'июля'               => 'July',
      'июль'               => 'July',
      'августа'            => 'August',
      'август'             => 'August',
      'сентября'           => 'September',
      'сентябрь'           => 'September',
      'октября'            => 'October',
      'октябрь'            => 'October',
      'октяябрь'           => 'October',
      'ноября'             => 'November',
      'ноябрь'             => 'November',
      'декабря'            => 'December',
      'декабрь'            => 'December',
    }.freeze

    def remap
      REMAP.merge(super)
    end

    def date_str
      super.gsub(' года', '')
    end
  end

  # Spanish dates
  class Spanish < WikipediaDate
    REMAP = {
      'a la fecha'   => '',
      'actualidad'   => '',
      'actual'       => '',
      'en funciones' => '',
      'en el cargo'  => '',
      'presente'     => '',
      'enero'        => 'January',
      'febrero'      => 'February',
      'marzo'        => 'March',
      'abril'        => 'April',
      'mayo'         => 'May',
      'junio'        => 'June',
      'julio'        => 'July',
      'agosto'       => 'August',
      'septiembre'   => 'September',
      'octubre'      => 'October',
      'noviembre'    => 'November',
      'diciembre'    => 'December',
    }.freeze

    def remap
      REMAP.merge(super)
    end

    def date_str
      super.to_s.downcase.gsub(/[º°]/, '').gsub(' de ', ' ').tidy
    end
  end

  # Turkish dates
  class Turkish < WikipediaDate
    REMAP = {
      'Görevde' => '',
      'Ocak'    => 'January',
      'Şubat'   => 'February',
      'Mart'    => 'March',
      'Nisan'   => 'April',
      'Mayıs'   => 'May',
      'Haziran' => 'June',
      'Temmuz'  => 'July',
      'Ağustos' => 'August',
      'Eylül'   => 'September',
      'Ekim'    => 'October',
      'Kasım'   => 'November',
      'Aralık'  => 'December',
    }.freeze

    def remap
      REMAP.merge(super)
    end
  end

  # Ukrainian dates
  class Ukrainian < WikipediaDate
    REMAP = {
      'по т.ч.'   => '',
      'січня'     => 'January',
      'січень'    => 'January',
      'лютого'    => 'February',
      'лютий'     => 'February',
      'березня'   => 'March',
      'березень'  => 'March',
      'квітня'    => 'April',
      'квітень'   => 'April',
      'травня'    => 'May',
      'травень'   => 'May',
      'червня'    => 'June',
      'липня'     => 'July',
      'липень'    => 'July',
      'серпня'    => 'August',
      'серпень'   => 'August',
      'вересня'   => 'September',
      'жовтня'    => 'October',
      'листопада' => 'November',
      'листопад'  => 'November',
      'грудня'    => 'December',
    }.freeze

    def remap
      REMAP.merge(super)
    end
  end

  # Vietnamese dates
  class Vietnamese < WikipediaDate
    def to_s
      tidied.tr(' ', '-').split('-').reverse.map(&:zeropad2).join('-')
    end

    def tidied
      date_str.to_s.gsub('đương nhiệm', '').gsub('nay', '').gsub('Từ', '').gsub(/tháng/i, '').gsub('năm', '').delete(',').tidy
    end
  end
end

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

# Base class for a table of Officeholders
# TODO: rename this to not be confused with the List version
class OfficeholderListBase < Scraped::HTML
  field :members do
    raise 'No holder_entries found' if holder_entries.empty?

    holder_entries.map { |ul| fragment(ul => member_class) }.reject(&:empty?).map(&:to_h).uniq
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
  class OfficeholderBase < Scraped::HTML
    LANG = {
      ar: WikipediaDate::Arabic,
      be: WikipediaDate::Belarussian,
      bg: WikipediaDate::Bulgarian,
      de: WikipediaDate::German,
      es: WikipediaDate::Spanish,
      et: WikipediaDate::Estonian,
      fr: WikipediaDate::French,
      id: WikipediaDate::Indonesian,
      it: WikipediaDate::Italian,
      lb: WikipediaDate::Luxembourgish,
      lt: WikipediaDate::Lithuanian,
      nl: WikipediaDate::Dutch,
      pt: WikipediaDate::Portuguese,
      ro: WikipediaDate::Romanian,
      ru: WikipediaDate::Russian,
      tr: WikipediaDate::Turkish,
      uk: WikipediaDate::Ukrainian,
      vi: WikipediaDate::Vietnamese,
    }.freeze

    def empty?
      (tds.first.text == tds.last.text) || itemLabel.to_s.tidy.empty? || too_early?
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
      date_class.new(raw_start).to_s
    end

    field :endDate do
      date_class.new(raw_end).to_s
    end

    private

    def raw_start
      return combo_date.first if combo_date?

      start_cell.text.gsub(/\(.*?\)/, '').tidy
    end

    def raw_end
      return combo_date.last if combo_date?

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

    def ignore_before
      2000
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
      name_cell.css('a').map(&:text).first
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
