module Api
  module V1
    class ReadingsController < BaseController
      MAX_LIMIT = 1000

      def index
        @inverter = Inverter.find(params[:inverter_id])
        @metric = params[:metric].presence
        @readings = @inverter.readings
          .since(parse_time(params[:from]))
          .through(parse_time(params[:to]))
          .chronological
          .limit(limit)
      end

      private
        def limit
          requested = params[:limit].to_i
          requested = MAX_LIMIT if requested <= 0 || requested > MAX_LIMIT
          requested
        end

        def parse_time(raw)
          return nil if raw.blank?

          Time.zone.parse(raw.to_s)
        rescue ArgumentError
          nil
        end
    end
  end
end
