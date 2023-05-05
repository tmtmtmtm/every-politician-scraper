# frozen_string_literal: true

require 'scraped'
require 'warning'

require_relative '../lib/every_politician_scraper/infobox'
require_relative '../lib/every_politician_scraper/infobox_en'
require_relative '../lib/every_politician_scraper/experience'
require_relative '../lib/every_politician_scraper/wpdates'

Gem.path.each do |path|
  Warning.ignore(//, path)
end

require 'minitest/autorun'
