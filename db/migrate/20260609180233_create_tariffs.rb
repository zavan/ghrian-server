class CreateTariffs < ActiveRecord::Migration[8.1]
  def change
    create_table :tariffs do |t|
      t.decimal :import_rate, precision: 10, scale: 4, default: 0, null: false
      t.decimal :export_rate, precision: 10, scale: 4, default: 0, null: false
      t.string :currency, default: "$", null: false

      t.timestamps
    end
  end
end
