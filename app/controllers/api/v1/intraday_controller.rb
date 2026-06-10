module Api
  module V1
    # Downsampled intraday chart series for one inverter and date — the same data
    # the dashboard chart uses (Inverter#intraday_series), exposed for clients so
    # they don't have to page the raw /readings endpoint (capped at 1000 rows).
    class IntradayController < BaseController
      def show
        @inverter = Inverter.find(params[:id])
        @date = parse_date(params[:date])
        @series = @inverter.intraday_series(date: @date)
      end

      private
        def parse_date(raw)
          return Date.current if raw.blank?

          Date.parse(raw.to_s)
        rescue ArgumentError, TypeError
          Date.current
        end
    end
  end
end
