# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/spec'
require 'test_helper'
require 'pathname'
require 'pry'

# Calculate how long someone has held office, coping with overlapping periods.
describe Experience do
  describe '#total' do
    describe 'no ranges' do
      it 'has no experience' do
        assert_equal 0, Experience.new.total
      end
    end

    describe 'one range' do
      it 'has one day of experience' do
        assert_equal 1, Experience.new(%w[2022-01-01 2022-01-01]).total
      end

      it 'has two days of experience' do
        assert_equal 2, Experience.new(%w[2022-01-01 2022-01-02]).total
      end

      it 'has one month of experience' do
        assert_equal 31, Experience.new(%w[2022-01-01 2022-01-31]).total
      end

      it 'ignores inverted ranges' do
        assert_equal 0, Experience.new(%w[2022-01-11 2022-01-01]).total
      end
    end

    describe 'two ranges' do
      let(:first)      { %w[2022-01-01 2022-01-31] }
      let(:experience) { Experience.new(first, @second) }

      it 'handles discontinuous ranges' do
        @second = %w[2022-03-01 2022-03-31]
        assert_equal 62, experience.total
      end

      it 'handles abutting ranges' do
        @second = %w[2022-02-01 2022-02-28]
        assert_equal 59, experience.total
      end

      it 'handles fully overlapping ranges' do
        @second = %w[2022-01-01 2022-01-31]
        assert_equal 31, experience.total
      end

      it 'handles partially overlapping ranges' do
        @second = %w[2022-01-21 2022-02-28]
        assert_equal 59, experience.total
      end

      it 'handles supersets' do
        @second = %w[2022-01-01 2022-02-28]
        assert_equal 59, experience.total
      end

      it 'handles subsets' do
        @second = %w[2022-01-10 2022-01-20]
        assert_equal 31, experience.total
      end

      it 'handles second period being earlier than the first' do
        @second = %w[2021-12-01 2022-01-10]
        assert_equal 62, experience.total
      end
    end

    describe 'many ranges' do
      it 'handles four ranges' do
        assert_equal 102, Experience.new(
          %w[2022-01-01 2022-01-31],  # 31 days
          %w[2022-04-01 2022-05-30],  # 60 more days
          %w[2022-01-10 2022-02-10],  # 10 new days in Feb
          %w[2022-03-01 2022-03-01]  # 1 more day
        ).total
      end
    end
  end

  describe '#before' do
    let(:experience) do
      Experience.new(
        %w[2022-01-01 2022-01-31], %w[2022-04-01 2022-05-30],
        %w[2022-01-10 2022-02-10], %w[2022-03-01 2022-03-01]
      )
    end

    it 'has no experience before 2022' do
      assert_equal 0, experience.before('2022-01-01')
    end

    it 'has one day of experience before 2022-01-02' do
      assert_equal 1, experience.before('2022-01-02')
    end

    it 'has all the experience before 2023-01-03' do
      assert_equal 102, experience.before('2023-01-01')
    end
  end
end
