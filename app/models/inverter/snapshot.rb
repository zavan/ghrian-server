class Inverter
  # Value object over an inverter's `latest_values` snapshot, presenting the live
  # power flow, battery/grid state, and today's energy totals in display-ready form
  # (the Solis-style overview). Sign conventions follow the agent/device notes:
  #   inverter_ac_grid_port_power: + = exporting to grid,   - = importing
  #   battery_current_direction:   0 = charging,            1 = discharging
  #   battery_power:               magnitude in W (sign used only as a fallback)
  #
  # Direction is expressed relative to the inverter hub:
  #   :in  = energy flows INTO the inverter  (PV, grid import, battery discharge)
  #   :out = energy flows OUT of the inverter (load, grid export, battery charge)
  #   :idle = no meaningful flow
  class Snapshot
    Flow = Struct.new(:key, :label, :watts, :direction, keyword_init: true) do
      def kw
        watts ? (watts.abs / 1000.0) : nil
      end

      def display
        Snapshot.kw(watts)
      end

      def active?
        direction != :idle && watts.present? && !watts.zero?
      end
    end

    def initialize(values)
      @values = values || {}
    end

    # "1.194 kW" / "0 kW" / "—"
    def self.kw(watts)
      return "—" if watts.nil?
      "#{(watts.abs / 1000.0).round(3)} kW"
    end

    def self.kwh(value)
      return "—" if value.nil?
      "#{value.round(2)} kWh"
    end

    # --- live power flow -----------------------------------------------------

    def pv
      Flow.new(key: "pv", label: "PV", watts: num("total_dc_output_power"), direction: :in)
    end

    def load
      Flow.new(key: "load", label: "Load", watts: num("household_load_power"), direction: :out)
    end

    def grid
      watts = num("inverter_ac_grid_port_power")
      direction = if watts.nil? || watts.zero?
        :idle
      elsif watts.positive?
        :out # exporting to grid
      else
        :in  # importing from grid
      end
      Flow.new(key: "grid", label: grid_label(watts), watts: watts, direction: direction)
    end

    def battery
      Flow.new(key: "battery", label: "Battery", watts: num("battery_power"), direction: battery_direction)
    end

    def flows
      [ pv, grid, battery, load ]
    end

    # --- battery / grid state ------------------------------------------------

    def soc
      num("battery_soc")
    end

    def battery_state
      case battery_direction
      when :out then "Charging"
      when :in then "Discharging"
      else "Standby"
      end
    end

    def grid_state
      case grid.direction
      when :out then "Exporting"
      when :in then "Importing"
      else "Idle"
      end
    end

    def online?
      flows.any?(&:active?) || soc.present?
    end

    # --- today's energy ------------------------------------------------------

    def daily_yield     = num("today_energy_generation")
    def daily_charge    = num("today_battery_charge_energy")
    def daily_discharge = num("today_battery_discharge_energy")
    def to_grid_energy  = num("today_energy_fed_into_grid")
    def from_grid_energy = num("today_energy_imported_from_grid")
    def consumption_energy = num("today_load_energy_consumption")

    # Self-consumption split (Solis "To Consumption" vs "To Grid"), derived from
    # today's generation and the energy fed into the grid.
    def to_grid_kwh
      to_grid_energy
    end

    def to_consumption_kwh
      return nil if daily_yield.nil?
      [ daily_yield - (to_grid_energy || 0), 0 ].max.round(2)
    end

    def consumption_pct
      return nil unless daily_yield&.positive?
      ((to_consumption_kwh / daily_yield) * 100).round
    end

    def grid_pct
      return nil unless consumption_pct
      100 - consumption_pct
    end

    def temperature
      num("inverter_temperature")
    end

    private
      def num(key)
        value = @values.dig(key, "value")
        value.is_a?(Numeric) ? value : nil
      end

      def battery_direction
        power = num("battery_power")
        return :idle if power&.zero?

        direction = num("battery_current_direction")
        if direction
          direction.zero? ? :out : :in # 0 = charging (out to battery), else discharging
        elsif power
          power.positive? ? :out : :in
        else
          :idle
        end
      end

      def grid_label(watts)
        return "Grid" if watts.nil? || watts.zero?
        watts.positive? ? "Grid (Exporting)" : "Grid (Importing)"
      end
  end
end
