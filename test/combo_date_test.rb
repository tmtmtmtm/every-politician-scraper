# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/spec'
require 'test_helper'
require 'pathname'
require 'pry'

describe WikipediaComboDate do
  let(:combo) { WikipediaComboDate.new(datestr, WikipediaDate) }

  describe 'no dates' do
    let(:datestr) { '' }

    it 'has the correct start' do
      assert_nil combo.first
    end

    it 'has the correct end' do
      assert_nil combo.last
    end
  end

  describe 'two full dates' do
    let(:datestr) { 'January 3, 2004 - February 9, 2005' }

    it 'has the correct start' do
      assert_equal '2004-01-03', combo.first
    end

    it 'has the correct end' do
      assert_equal '2005-02-09', combo.last
    end
  end

  describe 'two partial dates' do
    let(:datestr) { 'January 2004 - February 2005' }

    it 'has the correct start' do
      assert_equal '2004-01', combo.first
    end

    it 'has the correct end' do
      assert_equal '2005-02', combo.last
    end
  end

  describe 'two years' do
    let(:datestr) { '2004- 2005' }

    it 'has the correct start' do
      assert_equal '2004', combo.first
    end

    it 'has the correct end' do
      assert_equal '2005', combo.last
    end
  end

  describe 'single year' do
    let(:datestr) { '2007' }

    it 'has the correct start' do
      assert_equal '2007', combo.first
    end

    it 'has the correct end' do
      assert_equal '2007', combo.last
    end
  end

  describe 'unterminated' do
    let(:datestr) { '2007-' }

    it 'has the correct start' do
      assert_equal '2007', combo.first
    end

    it 'has the correct end' do
      assert_nil combo.last
    end
  end

  describe 'incumbent' do
    let(:datestr) { '2007 - Incumbent' }

    it 'has the correct start' do
      assert_equal '2007', combo.first
    end

    it 'has the correct end' do
      assert_nil combo.last
    end
  end

  describe 'month precision incumbent' do
    let(:datestr) { 'April 2022–Current' }

    it 'has the correct start' do
      assert_equal '2022-04', combo.first
    end

    it 'has the correct end' do
      assert_nil combo.last
    end
  end

  describe 'full date incumbent' do
    let(:datestr) { '6 April 2022 – present' }

    it 'has the correct start' do
      assert_equal '2022-04-06', combo.first
    end

    it 'has the correct end' do
      assert_nil combo.last
    end
  end

  describe 'two months in a year' do
    let(:datestr) { 'April-June 2004' }

    it 'has the correct start' do
      assert_equal '2004-04', combo.first
    end

    it 'has the correct end' do
      assert_equal '2004-06', combo.last
    end
  end

  describe 'two days in a month' do
    let(:datestr) { '3-10 June, 2004' }

    it 'has the correct start' do
      assert_equal '2004-06-03', combo.first
    end

    it 'has the correct end' do
      assert_equal '2004-06-10', combo.last
    end
  end

  describe 'German dates' do
    let(:combo) { WikipediaComboDate.new(datestr, WikipediaDate::German) }
    let(:datestr) { '18.–23. März 2004' }

    it 'has the correct start' do
      assert_equal '2004-03-18', combo.first
    end

    it 'has the correct end' do
      assert_equal '2004-03-23', combo.last
    end
  end
end

describe WikipediaDate do
  describe 'already ISO-formmated' do
    let(:datestr) { '2004-06-03' }

    it 'has the correct representation' do
      assert_equal '2004-06-03', WikipediaDate.new(datestr).to_s
    end
  end

  describe 'partial ISO-formmated date' do
    let(:datestr) { '2004-06' }

    it 'has the correct representation' do
      assert_equal '2004-06', WikipediaDate.new(datestr).to_s
    end
  end
end
