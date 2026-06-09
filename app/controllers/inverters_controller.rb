class InvertersController < ApplicationController
  before_action :set_inverter, only: [ :show, :edit, :update, :destroy ]

  def index
    @inverters = Inverter.order(:name)
  end

  # The per-inverter "plant" page: current snapshot + Day/Month/Year/Lifetime energy
  # aggregates with cost figures, and the intraday/breakdown chart.
  def show
    @tariff = Tariff.instance
    @summary = EnergySummary.new(@inverter.daily_summaries,
      period: params[:period], date: parse_date(params[:date]))
  end

  def new
    @inverter = Inverter.new
  end

  def edit
  end

  def create
    @inverter = Inverter.new(inverter_params)
    if @inverter.save
      redirect_to inverters_path, notice: "Inverter added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @inverter.update(inverter_params)
      redirect_to inverters_path, notice: "Inverter updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @inverter.destroy
    redirect_to inverters_path, notice: "Inverter removed."
  end

  private
    def set_inverter
      @inverter = Inverter.find(params[:id])
    end

    def inverter_params
      params.require(:inverter).permit(:name, :device_model, :mqtt_topic, :serial_number)
    end

    def parse_date(raw)
      Date.parse(raw) if raw.present?
    rescue ArgumentError
      nil
    end
end
