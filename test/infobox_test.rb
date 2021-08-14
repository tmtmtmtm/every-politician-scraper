# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/spec'
require 'test_helper'
require 'pathname'
require 'pry'

describe EveryPolitician::Infobox do
  let(:positions) do
    EveryPolitician::Infobox.new(Pathname.new("test/data/#{datafile}").read).positions.map(&:command_data).sort_by { |data| data[:P580] }
  end

  describe 'Annabel Goldie' do
    let(:datafile) { 'AG.json' }

    it 'has 6 positions' do
      assert_equal 6, positions.count
    end

    it 'has a sensible latest position' do
      position = positions.last
      assert_equal 'Minister of State for Defence', position[:office][:stated_as]
      assert_equal 1, position[:office][:links].count
      assert_equal 'Minister of State for Defence', position[:office][:links].first
      assert_equal '2019-07-26', position[:P580]
      assert_equal 'The Earl Howe', position[:P1365][:stated_as]
      assert_equal 1, position[:P1365][:links].count
      assert_equal 'Frederick Curzon, 7th Earl Howe', position[:P1365][:links].first
      assert_nil position[:P582]
      assert_nil position[:P1366]
    end

    it 'handles holding the same position twice' do
      leader = positions.select { |posn| posn[:office][:stated_as] == 'Leader of the Scottish Conservative Party in the Scottish Parliament' }
      assert_equal 2, leader.count
    end

    it 'handles positions with multiple links' do
      position = positions.first
      assert_equal "Member of the Scottish Parliament\nfor West Scotland\n(1 of 7 Regional MSPs)", position[:office][:stated_as]
      assert_equal 2, position[:office][:links].count
      assert_equal ['Member of the Scottish Parliament', 'West Scotland (Scottish Parliament electoral region)'], position[:office][:links]
      assert_equal '1999-05-06', position[:P580]
      assert_equal '2016-03-24', position[:P582]
    end
  end

  describe 'Osea Naiqamu' do
    let(:datafile) { 'ON.json' }

    it 'handles termstart as well as term_start' do
      assert_equal 1, positions.count
      assert_equal '2018-11-21', positions.first[:P580]
    end
  end

  describe 'Moon Sung-wook' do
    let(:datafile) { 'MS.json' }

    it 'handles going straight to office1 with no office' do
      assert_equal 4, positions.count
    end
  end

  describe 'Jeong_Kyeong-doo' do
    let(:datafile) { 'JK.json' }

    it 'skips a different first infobox' do
      assert_equal 3, positions.count
    end
  end

  describe 'Silvio Schembri' do
    let(:datafile) { 'SS.json' }

    it 'copes with being called Order rather than Office' do
      assert_equal 2, positions.count
    end
  end
end
