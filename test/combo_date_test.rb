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

  describe 'one partial, one DMY' do
    let(:datestr) { 'January 2004 - 12 February 2005' }

    it 'has the correct start' do
      assert_equal '2004-01', combo.first
    end

    it 'has the correct end' do
      assert_equal '2005-02-12', combo.last
    end
  end

  describe 'MD - MDY' do
    let(:datestr) { 'August 28 – October 10, 2018' }

    it 'has the correct start' do
      assert_equal '2018-08-28', combo.first
    end

    it 'has the correct end' do
      assert_equal '2018-10-10', combo.last
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

  describe 'longdash' do
    let(:datestr) { '1950－1952' }

    it 'has the correct start' do
      assert_equal '1950', combo.first
    end

    it 'has the correct end' do
      assert_equal '1952', combo.last
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

  describe 'Vietnamese dates' do
    let(:combo) { WikipediaComboDate.new(datestr, WikipediaDate::Vietnamese) }

    describe 'basic Vietnamese range' do
      let(:datestr) { 'Tháng 8, 2011 – 9 tháng 4 năm 2016' }

      it 'has the correct start' do
        assert_equal '2011-08', combo.first
      end

      it 'has the correct end' do
        assert_equal '2016-04-09', combo.last
      end
    end

    describe 'Vietnamese incumbent (nay)' do
      let(:datestr) { '21 tháng 10 năm 2022 - nay' }

      it 'has the correct start' do
        assert_equal '2022-10-21', combo.first
      end

      it 'has the correct end' do
        assert_nil combo.last
      end
    end

    describe 'Vietnamese incumbent (Từ)' do
      let(:datestr) { 'Từ 12 tháng 11 năm 2020' }

      it 'has the correct start' do
        assert_equal '2020-11-12', combo.first
      end

      it 'has the correct end' do
        assert_nil combo.last
      end
    end
  end

  describe 'Portuguese dates' do
    let(:combo) { WikipediaComboDate.new(datestr, WikipediaDate::Portuguese) }
    # TODO: handle this raw
    # let(:datestr) { '15 de março de 1983 até 14 de maio de 1986' }
    let(:datestr) { '15 de março de 1983 - 14 de maio de 1986' }

    it 'has the correct start' do
      assert_equal '1983-03-15', combo.first
    end

    it 'has the correct end' do
      assert_equal '1986-05-14', combo.last
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

  describe 'Japanese dates' do
    let(:datestr) { '2001年1月6日' }

    it 'has the correct representation' do
      assert_equal '2001-01-06', WikipediaDate::Japanese.new(datestr).to_s
    end
  end
end
