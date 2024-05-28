# frozen_string_literal: true

class String
  def zeropad2
    rjust(2, '0')
  end
end

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
    return if raw == 'Incumbent'

    dateclass.new(raw).to_s
  end

  private

  attr_reader :rawstring, :dateclass

  def date_string
    tidied.tidy.sub(/[—−–\-－]/, '-').gsub(/^(from|since) (.*)/, '\2-').gsub(/-$/, '-Incumbent')
  end

  def parts
    date_string.split('-').map(&:tidy)
  end

  def raw_ended
    parts[1] || parts[0]
  end

  def raw_began
    ended_parts.zip(padded_start_parts).map(&:compact).map(&:last).join(' ')
  end

  def padded_start_parts
    return start_parts if start_parts.count == 3
    # if we have a year, left pad (for "Dec 2001 - 13 Jan 2002")
    return (['', '', ''] + start_parts).last(3) if start_parts.last.to_s[/\d{4}/]

    # not a year, so pass through to fill things like "3 - 10 Dec 2001"
    start_parts
  end

  def start_parts
    parts[0].to_s.split
  end

  def ended_parts
    ((raw_ended || '').split + [nil, nil, nil]).take(3)
  end

  def tidied
    dateclass.new(rawstring).tidied
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
    return date_en if format_iso?
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

  # reduce to d M Y or equivalent, without flourishes: 1º, de mai, etc
  # NB: this needs to work both for individual dates, but also combo ranges
  def tidied
    date_str
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
    @date_en ||= remap.reduce(tidied) { |str, (local, eng)| str.to_s.sub(local, eng) }
  end

  def format_ymd?
    (date_en =~ /^\d{1,2} \w+,? \d{4}$/) || (date_en =~ /^\w+ \d{1,2},? \d{4}$/)
  end

  def format_ym?
    date_en =~ /^\w+ \d{4}$/
  end

  def format_y?
    date_en =~ /^\d{4}$/
  end

  def format_iso?
    date_en =~ /^\d{4}(-\d{2}){1,2}$/
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
      'настояще'  => 'Incumbent',
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

  # Catalan dates
  class Catalan < WikipediaDate
    REMAP = {
      'gener'    => 'January',
      'jener'    => 'January',
      'febrer'   => 'February',
      'març'     => 'March',
      'abril'    => 'April',
      'maig'     => 'May',
      'juny'     => 'June',
      'juliol'   => 'July',
      'agost'    => 'August',
      'setembre' => 'September',
      'octubre'  => 'October',
      'novembre' => 'November',
      'desembre' => 'December',
    }.freeze

    def tidied
      super.gsub(' de ', ' ').gsub(" d'", ' ')
    end

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
      'Ametis'    => 'Incumbent',
      'jaanuar'   => 'January',
      'januaar'   => 'January',
      'veebruar'  => 'February',
      'märts'     => 'March',
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

    def tidied
      super.gsub('.', '')
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

    def tidied
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

    def tidied
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

    def tidied
      super.to_s.downcase.gsub(/[º°]/, '').tidy
    end

    def remap
      REMAP.merge(super)
    end
  end

  class Japanese < WikipediaDate
    def to_s
      return if date_str.to_s.empty?

      date_str.split(/[年月日]/).map { |num| num.tidy.rjust(2, "0") }.take(3).join('-')
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

    def tidied
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

    def tidied
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
      'janeiro'          => 'January',
      'fevereiro'        => 'February',
      'março'            => 'March',
      'abril'            => 'April',
      'maio'             => 'May',
      'junho'            => 'June',
      'julho'            => 'July',
      'agosto'           => 'August',
      'setembro'         => 'September',
      'outubro'          => 'October',
      'novembro'         => 'November',
      'dezembro'         => 'December',
    }.freeze

    def tidied
      super.gsub(/\.?[º°]/, '').gsub(' de ', ' ').tidy
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

    def tidied
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
      'Февраля'            => 'February',
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

    def tidied
      super.gsub(' года', '')
    end
  end

  # Slovak dates
  class Slovak < WikipediaDate
    REMAP = {
      'január'    => 'January',
      'januára'   => 'January',
      'február'   => 'February',
      'februára'  => 'February',
      'marec'     => 'March',
      'marca'     => 'March',
      'apríl'     => 'April',
      'apríla'    => 'April',
      'máj'       => 'May',
      'mája'      => 'May',
      'jún'       => 'June',
      'júna'      => 'June',
      'júl'       => 'July',
      'júla'      => 'July',
      'august'    => 'August',
      'augusta'   => 'August',
      'september' => 'September',
      'septembra' => 'September',
      'október'   => 'October',
      'októbra'   => 'October',
      'november'  => 'November',
      'novembra'  => 'November',
      'december'  => 'December',
      'decembra'  => 'December',
    }.freeze

    def tidied
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

    def tidied
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
      date_str.to_s.gsub('đương nhiệm', '').gsub('nay', '').gsub(/Từ (.*)/, '\1 - ').gsub(/tháng/i, '').gsub('năm', '').delete(',').tidy
    end
  end
end
