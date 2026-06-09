# Period aggregation over a DailySummary relation (one inverter's summaries, or all
# of them for a site-wide view). Computes the date range for a Day/Month/Year/Lifetime
# selection, the summed EnergyTotals, a breakdown series for the chart, and the
# date-navigation labels. A PORO (no service layer) so both the dashboard and the
# per-inverter page share the same logic.
class EnergySummary
  PERIODS = %w[day month year lifetime].freeze

  attr_reader :period, :date

  def initialize(scope, period:, date:)
    @scope = scope
    @period = period.presence_in(PERIODS) || "day"
    @date = date || Date.current
  end

  def range
    case period
    when "month" then date.beginning_of_month..date.end_of_month
    when "year" then date.beginning_of_year..date.end_of_year
    when "lifetime" then (@scope.minimum(:date) || date)..Date.current
    else date..date
    end
  end

  def totals
    sums = @scope.between(range).totals
    Inverter::EnergyTotals.new(
      generation: sums[:generation_kwh],
      feed_in: sums[:feed_in_kwh],
      import: sums[:import_kwh],
      consumption: sums[:consumption_kwh],
      charge: sums[:charge_kwh],
      discharge: sums[:discharge_kwh]
    )
  end

  # [[label, generation_kwh], ...] for the column chart, or nil for "day" (callers
  # show an intraday chart there instead). Day columns by day, year by month,
  # lifetime by year.
  def breakdown
    case period
    when "month"
      @scope.between(range).group(:date).order(:date).sum(:generation_kwh)
        .map { |day, kwh| [ day.day.to_s, kwh ] }
    when "year"
      by_month = @scope.between(range).group("strftime('%Y-%m', date)").sum(:generation_kwh)
      (1..12).map { |m| [ Date::ABBR_MONTHNAMES[m], by_month["#{date.year}-#{format('%02d', m)}"].to_f ] }
    when "lifetime"
      @scope.group("strftime('%Y', date)").order(Arel.sql("strftime('%Y', date)")).sum(:generation_kwh)
        .map { |year, kwh| [ year, kwh ] }
    end
  end

  def breakdown_unit
    { "month" => "day", "year" => "month", "lifetime" => "year" }[period]
  end

  def navigable?
    period != "lifetime"
  end

  def label
    case period
    when "month" then date.strftime("%B %Y")
    when "year" then date.year.to_s
    when "lifetime" then "All time"
    else date.strftime("%d/%m/%Y")
    end
  end

  def step
    case period
    when "month" then 1.month
    when "year" then 1.year
    else 1.day
    end
  end

  def prev_date = date - step
  def next_date = date + step
end
