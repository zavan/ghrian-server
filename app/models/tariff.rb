# Singleton electricity pricing for the installation: what the user pays per kWh
# imported from the grid, and what they earn per kWh exported (feed-in tariff).
# Used to turn energy aggregates into money (cost / earnings / net / savings).
class Tariff < ApplicationRecord
  validates :import_rate, :export_rate,
    numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true

  def self.instance
    first_or_create!
  end

  # Money the given imported energy (kWh) costs.
  def cost(kwh)
    money(kwh, import_rate)
  end

  # Money the given exported energy (kWh) earns.
  def earnings(kwh)
    money(kwh, export_rate)
  end

  def configured?
    import_rate.positive? || export_rate.positive?
  end

  # "$12.34" / "-$1.20"
  def format(amount)
    amount ||= 0
    sign = amount.negative? ? "-" : ""
    "#{sign}#{currency}#{amount.abs.round(2)}"
  end

  private
    def money(kwh, rate)
      return 0.0 if kwh.nil?
      (kwh.to_f * rate.to_f).round(2)
    end
end
