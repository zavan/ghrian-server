module Api
  module V1
    class InvertersController < BaseController
      def index
        @inverters = Inverter.order(:name)
      end

      def show
        @inverter = Inverter.find(params[:id])
      end
    end
  end
end
