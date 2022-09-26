# frozen_string_literal: true

# Two dates in one string, e.g:
#   1990 - 1994
#   Jan-Dec 2004
#   Jan 2004 - Dec 2005
#   Jan 3-9, 2005
#   January 3, 2004 - February 9, 2005
#   2003
class WikipediaComboDate
  def initialize(rawstring, dateclass)
    @rawstring = rawstring
    @dateclass = dateclass
  end

  def first
    raw = raw_began or return

    dateclass.new(raw).to_s
  end

  def last
    raw = raw_ended or return

    dateclass.new(raw).to_s
  end

  private

  attr_reader :rawstring, :dateclass

  def date_string
    rawstring.tidy.sub(/[—–-]/, '-').gsub(/-$/, '-Incumbent')
  end

  def parts
    date_string.split('-').map(&:tidy)
  end

  def raw_ended
    parts[1] || parts[0]
  end

  def raw_began
    start_parts = parts[0].to_s.split
    ended_parts[0..2].zip(start_parts).map(&:compact).map(&:last).join(' ')
  end

  def ended_parts
    ((raw_ended || '').split + [nil, nil, nil]).take(3)
  end
end

# Handle a variety of date formats seen on Wikipedia
# Subclass this to remap foreign language dates
class WikipediaDate
  def initialize(date_str)
    @date_str = date_str.to_s.tidy
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
      'حتى الآن'     => '',
      'في المنصب'    => '',
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
      'heden'     => '',
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
      'jaanuar'   => 'January',
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
      'auj.'        => '',
      'en cours'    => '',
      'en fonction' => '',
      'januar'      => 'January',
      'février'     => 'February',
      'mars'        => 'March',
      'avril'       => 'April',
      'mai'         => 'May',
      'juin'        => 'June',
      'juillet'     => 'July',
      'août'        => 'August',
      'aout'        => 'August',
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

  # Greek dates
  class Greek < WikipediaDate
    REMAP = {
      'Ιανουαρίου'  => 'January',
      'Φεβρουαρίου' => 'February',
      'Μαρτίου'     => 'March',
      'Απριλίου'    => 'April',
      'Μαΐου'       => 'May',
      'Ιουνίου'     => 'June',
      'Ιουλίου'     => 'July',
      'Αυγούστου'   => 'August',
      'Σεπτεμβρίου' => 'September',
      'Οκτωβρίου'   => 'October',
      'Νοεμβρίου'   => 'November',
      'Δεκεμβρίου'  => 'December',
    }.freeze

    def remap
      REMAP.merge(super)
    end
  end

  # Hungarian dates
  class Hungarian < WikipediaDate
    REMAP = {
      'hivatalban' => '',
      'január'     => 'January',
      'február'    => 'February',
      'március'    => 'March',
      'április'    => 'April',
      'május'      => 'May',
      'június'     => 'June',
      'július'     => 'July',
      'augusztus'  => 'August',
      'szeptember' => 'September',
      'október'    => 'October',
      'november'   => 'November',
      'december'   => 'December',
    }.freeze

    def remap
      REMAP.merge(super)
    end

    def date_en
      super.split.reverse.join(' ').delete('.')
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

  # Slovak dates
  class Slovak < WikipediaDate
    REMAP = {
      'január'    => 'January',
      'február'   => 'February',
      'marec'     => 'March',
      'apríl'     => 'April',
      'máj'       => 'May',
      'jún'       => 'June',
      'júl'       => 'July',
      'august'    => 'August',
      'september' => 'September',
      'október'   => 'October',
      'november'  => 'November',
      'december'  => 'December',
    }.freeze

    def date_str
      super.gsub(/(\d+)\./, '\1')
    end

    def remap
      REMAP.merge(super)
    end
  end

  # Spanish dates
  class Spanish < WikipediaDate
    REMAP = {
      'Actualmente en el cargo' => '',
      'actualmente en el cargo' => '',
      'a la fecha'              => '',
      'actualidad'              => '',
      'actual'                  => '',
      'en funciones'            => '',
      'en el cargo'             => '',
      'en ejercicio'            => '',
      'presente'                => '',
      'enero'                   => 'January',
      'febrero'                 => 'February',
      'marzo'                   => 'March',
      'abril'                   => 'April',
      'mayo'                    => 'May',
      'junio'                   => 'June',
      'julio'                   => 'July',
      'agosto'                  => 'August',
      'septiembre'              => 'September',
      'octubre'                 => 'October',
      'noviembre'               => 'November',
      'diciembre'               => 'December',
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
