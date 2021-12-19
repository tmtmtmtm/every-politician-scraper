# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/spec'
require 'test_helper'
require 'pathname'
require 'pry'

describe EveryPolitician::Infobox do
  let(:pathname)  { Pathname.new("test/data/#{datafile}") }
  let(:infobox)   { EveryPolitician::Infobox.new(pathname.read) }
  let(:positions) { infobox.positions.map(&:command_data).sort_by { |data| data[:P580].to_s } }

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

  describe 'Edward Zammit Lewis' do
    let(:datafile) { 'EZL.json' }

    it 'handles month+year only dates' do
      assert_equal '2020-01', positions[4][:P580]
    end

    it 'splits "X to Y" term fields' do
      assert_equal '2019-07', positions[3][:P580]
      assert_equal '2020-01', positions[3][:P582]
    end

    it 'splits "X - Y" term fields' do
      assert_equal '2014-04', positions[2][:P580]
      assert_equal '2017-06', positions[2][:P582]
    end
  end

  describe 'Eddie Fenech Adami' do
    let(:datafile) { 'EFA.json' }

    it 'handles both "office" and "order"' do
      # wtf_wikipedia doesn't find the link here
      # assert_equal 'Prime Minister of Malta', positions[0][:office][:links]
      assert_equal 'Prime Minister of Malta', positions[0][:office][:stated_as]
    end

    it 'can find numeric ordinals' do
      assert_equal '7', positions[2][:P1545]
      assert_equal '10', positions[1][:P1545]
      assert_nil positions[0][:P1545]
    end
  end

  describe 'Teten Masduki' do
    let(:datafile) { 'TM.json' }

    it 'handles "office" and "order" on the same page' do
      assert_equal 2, positions.count
      assert_equal '2nd Presidential Chief of Staff', positions[0][:office][:stated_as]
      assert_equal 'Minister for Cooperatives and SMEs', positions[1][:office][:stated_as]
    end
  end

  describe 'Zorana Mihajlović' do
    let(:datafile) { 'ZM.json' }

    it 'handles multiple predecessors' do
      assert_equal 4, positions.count
      position = positions[2]
      assert_equal 'Minister of Construction, Transport, and Infrastructure', position[:office][:stated_as]
      assert_equal ['Velimir Ilić', 'Aleksandar Antić'], position[:P1365][:links]
    end
  end

  describe 'George Young' do
    let(:datafile) { 'GY.json' }

    it 'handles more than 10 offices' do
      assert_equal 16, positions.count
      assert_includes positions[0][:office][:stated_as], 'Ealing Acton'
      assert_includes positions[15][:office][:stated_as], 'Lord-in-waiting'
    end
  end

  describe 'Zasia binti Sirin' do
    let(:datafile) { 'ZbS.json' }

    it 'handles other date separators' do
      assert_equal 1, positions.count
      assert_includes positions[0][:P580], '2011'
      assert_includes positions[0][:P582], '2016'
    end
  end

  describe 'ʻAisake Eke' do
    let(:datafile) { 'AE.json' }

    it 'handles normal data for constituency_MP roles' do
      assert_equal 2, positions.count
      assert_equal('2010-11-25', positions[0][:P580])
      assert_equal('2017-11-16', positions[0][:P582])
    end

    it 'rewrites constituency MP offices' do
      assert_includes positions[0][:office][:stated_as], 'Member of Parliament'
    end

    it 'handles constituency_MP districts' do
      assert_includes positions[0][:P768][:stated_as], 'Tongatapu 5'
    end
  end

  describe 'Tomaž Gantar' do
    let(:datafile) { 'TG.json' }
    let(:infobox)  { EveryPolitician::Infobox.new(pathname.read, 'sl') }

    it 'handles Slovenian dates' do
      assert_equal 4, positions.count

      # the first position is null, because of a bare 'order'
      assert_equal(%w[2012-02-11 2013-02-22], positions[1].values_at(:P580, :P582))
      assert_equal(%w[2013-03-20 2013-11-25], positions[2].values_at(:P580, :P582))
      assert_equal(%w[2020-03-13 2020-12-18], positions[3].values_at(:P580, :P582))
    end
  end

  describe 'Dejan Židan' do
    let(:datafile) { 'DZh.json' }
    let(:infobox)  { EveryPolitician::Infobox.new(pathname.read, 'sl') }

    it 'handles Slovenian dates' do
      assert_equal 2, positions.count

      assert_equal(%w[2010-05-05 2018], positions[0].values_at(:P580, :P582))
      assert_equal(%w[2018-08-23 2020-03-03], positions[1].values_at(:P580, :P582))
    end
  end

  describe 'Marian Jurečka' do
    let(:datafile) { 'MJ.json' }
    let(:infobox)  { EveryPolitician::Infobox.new(pathname.read, 'sl') }

    it 'copes with only having a title' do
      assert_equal 4, positions.count
      mlsa = positions.last

      assert_equal('2021-12-17', mlsa[:P580])
      assert_equal('Minister of Labour and Social Affairs', mlsa[:office][:stated_as])
    end
  end
end
