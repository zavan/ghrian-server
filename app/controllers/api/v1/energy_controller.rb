module Api
  module V1
    # Period energy totals (Day/Month/Year/Lifetime) + costs. Scoped to one inverter
    # when nested (member route, params[:id]); site-wide over every inverter's
    # summaries when hit at /api/v1/energy. Reuses the EnergySummary PORO and Tariff,
    # same as the web dashboard and the per-inverter page.
    class EnergyController < BaseController
      def show
        @inverter = Inverter.find(params[:id]) if params[:id].present?
        scope = @inverter ? @inverter.daily_summaries : DailySummary.all
        @summary = EnergySummary.new(scope, period: params[:period], date: parse_date(params[:date]))
        @tariff = Tariff.instance
      end

      private
        def parse_date(raw)
          return nil if raw.blank?

          Date.parse(raw.to_s)
        rescue ArgumentError, TypeError
          nil
        end
    end
  end
end
