# Live overview: a site-wide energy & cost summary (Day/Month/Year/Lifetime) plus a
# rich live panel per inverter. The live panels update over Turbo Streams as readings
# arrive; the summary swaps via its own Turbo frame on tab/date changes.
class DashboardsController < ApplicationController
  def show
    @inverters = Inverter.order(:name)
    @tariff = Tariff.instance
    @summary = EnergySummary.new(DailySummary.all,
      period: params[:period], date: parse_date(params[:date]))
  end

  private
    def parse_date(raw)
      Date.parse(raw) if raw.present?
    rescue ArgumentError
      nil
    end
end
