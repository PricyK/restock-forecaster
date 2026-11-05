# frozen_string_literal: true

require "test_helper"

class SalesHistoryTest < ActiveSupport::TestCase
  TODAY = Date.new(2026, 11, 10)

  test "has three ranges of 7, 30 and 8 points" do
    ranges = SalesHistory.call(daily_units: {}, today: TODAY)
    assert_equal ["7 days", "30 days", "8 weeks"], ranges.map { _1[:label] }
    assert_equal [7, 30, 8], ranges.map { _1[:points].size }
  end

  test "daily points end today and fill missing days with zero" do
    week = range("7 days", { TODAY => 4, TODAY - 2 => 1 })
    assert_equal TODAY - 6, week.first[:date]
    assert_equal [0, 0, 0, 0, 1, 0, 4], week.map { _1[:units] }
  end

  test "30 day range starts 29 days before today" do
    assert_equal Date.new(2026, 10, 12), range("30 days", {}).first[:date]
  end

  test "weeks are 7 day totals and the last one ends today" do
    weeks = range("8 weeks", { TODAY => 2, TODAY - 6 => 3, TODAY - 7 => 5, TODAY - 55 => 1, TODAY - 56 => 100 })
    assert_equal({ date: TODAY - 6, units: 5 }, weeks.last)
    assert_equal 5, weeks[-2][:units]
    assert_equal({ date: TODAY - 55, units: 1 }, weeks.first)
    assert_equal 11, weeks.sum { _1[:units] } # TODAY - 56 is outside the 8 weeks
  end

  private

  def range(label, daily) = SalesHistory.call(daily_units: daily, today: TODAY).find { _1[:label] == label }[:points]
end
