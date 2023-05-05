# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/spec'
require 'test_helper'
require 'pathname'
require 'pry'

describe InfoboxEN::JSON do
  let(:pathname)  { Pathname.new("test/data/#{datafile}") }
  let(:infobox)   { InfoboxEN::JSON.new(pathname.read) }
  let(:mandates) { infobox.mandates.reject { |data| data[:positionLabel].to_s.empty? }.sort_by { |data| data[:startDate].to_s } }

  describe 'Annabel Goldie' do
    let(:datafile) { 'AG.json' }

    it 'has 6 mandates' do
      assert_equal 6, mandates.count
    end

    it 'has a sensible latest position' do
      mandate = mandates.last
      assert_equal 'Minister of State for Defence', mandate[:positionLabel]
      assert_equal '2019-07-26', mandate[:startDate]
      assert_nil mandate[:endDate]
    end

    it 'handles holding the same position twice' do
      leader = mandates.select { |posn| posn[:positionLabel] == 'Leader of the Scottish Conservative Party in the Scottish Parliament' }
      assert_equal 2, leader.count
    end
  end

  describe 'Osea Naiqamu' do
    let(:datafile) { 'ON.json' }

    it 'handles termstart as well as term_start' do
      assert_equal 1, mandates.count
      assert_equal '2018-11-21', mandates.first[:startDate]
    end
  end

  describe 'Moon Sung-wook' do
    let(:datafile) { 'MS.json' }

    it 'handles going straight to office1 with no office' do
      assert_equal 4, mandates.count
    end
  end

  describe 'Jeong_Kyeong-doo' do
    let(:datafile) { 'JK.json' }

    it 'skips a different first infobox' do
      assert_equal 3, mandates.count
    end
  end

  describe 'Silvio Schembri' do
    let(:datafile) { 'SS.json' }

    it 'copes with being called Order rather than Office' do
      assert_equal 2, mandates.count
    end
  end

  describe 'Edward Zammit Lewis' do
    let(:datafile) { 'EZL.json' }

    it 'handles month+year only dates' do
      assert_equal '2020-01', mandates[4][:startDate]
    end

    it 'splits "X to Y" term fields' do
      assert_equal '2019-07', mandates[3][:startDate]
      assert_equal '2020-01', mandates[3][:endDate]
    end

    it 'splits "X - Y" term fields' do
      assert_equal '2014-04', mandates[2][:startDate]
      assert_equal '2017-06', mandates[2][:endDate]
    end
  end

  describe 'Eddie Fenech Adami' do
    let(:datafile) { 'EFA.json' }

    it 'handles both "office" and "order"' do
      assert_equal 'Prime Minister of Malta', mandates[0][:positionLabel]
    end
  end

  describe 'Teten Masduki' do
    let(:datafile) { 'TM.json' }

    it 'handles "office" and "order" on the same page' do
      assert_equal 2, mandates.count
      assert_equal 'Presidential Chief of Staff', mandates[0][:positionLabel]
      assert_equal 'Minister for Cooperatives and SMEs', mandates[1][:positionLabel]
    end
  end

  describe 'George Young' do
    let(:datafile) { 'GY.json' }

    it 'handles more than 10 offices' do
      assert_equal 16, mandates.count
      assert_includes mandates[1][:positionLabel], 'Ealing Acton'
      assert_includes mandates[15][:positionLabel], 'Lord-in-waiting'
    end
  end

  describe 'Zasia binti Sirin' do
    let(:datafile) { 'ZbS.json' }

    it 'handles other date separators' do
      assert_equal 1, mandates.count
      assert_includes mandates[0][:startDate], '2011'
      assert_includes mandates[0][:endDate], '2016'
    end
  end

  describe 'ʻAisake Eke' do
    let(:datafile) { 'AE.json' }

    it 'handles normal data for constituency_MP roles' do
      assert_equal 2, mandates.count
      assert_equal '2010-11-25', mandates[0][:startDate]
      assert_equal '2017-11-16', mandates[0][:endDate]
    end

    it 'rewrites constituency MP offices' do
      assert_equal 'MP for Tongatapu 5', mandates[0][:positionLabel]
    end
  end

  describe 'Farooq Abdullah' do
    let(:datafile) { 'FA.json' }

    it 'has three Chief Minister mandates' do
      assert_equal 3, (mandates.count { |posn| posn[:positionLabel] == 'Chief Minister of Jammu and Kashmir' })
    end

    it 'has three MP mandates' do
      assert_equal 3, (mandates.count { |posn| posn[:positionLabel] == 'Member of Parliament, Lok Sabha' })
    end
  end

  describe 'Nathaniel Exum' do
    let(:datafile) { 'NE.json' }

    it 'recognises State Delegates' do
      assert_equal 'Member of the Maryland House of Delegates', mandates[0][:positionLabel]
    end
  end
end
