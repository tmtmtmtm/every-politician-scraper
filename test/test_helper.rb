# frozen_string_literal: true

require 'warning'
require_relative '../lib/every_politician_scraper/infobox'

Gem.path.each do |path|
  Warning.ignore(//, path)
end

require 'minitest/autorun'
