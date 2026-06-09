# Edits the singleton electricity tariff (import/export rates + currency) used for
# cost calculations across the energy aggregates.
class TariffsController < ApplicationController
  before_action :set_tariff

  def show
  end

  def edit
  end

  def update
    if @tariff.update(tariff_params)
      redirect_to tariff_path, notice: "Tariff saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_tariff
      @tariff = Tariff.instance
    end

    def tariff_params
      params.require(:tariff).permit(:import_rate, :export_rate, :currency)
    end
end
