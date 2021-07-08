# frozen_string_literal: true

require 'warning'

Gem.path.each do |path|
  Warning.ignore(//, path)
end

require 'minitest/autorun'
