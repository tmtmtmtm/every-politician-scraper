# frozen_string_literal: true

class Experience
  def initialize(*periods)
    @periods = periods
  end

  def total
    dates.count
  end

  def before(datestr)
    cutpoint = Date.parse(datestr)
    dates.count { |date| date < cutpoint }
  end

  private

  attr_reader :periods

  def ranges
    @ranges ||= periods.map { |period| Date.parse(period.first)..Date.parse(period.last) }
  end

  def dates
    ranges.flat_map(&:uniq).uniq
  end
end
