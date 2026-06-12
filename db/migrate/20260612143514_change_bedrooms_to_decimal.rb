class ChangeBedroomsToDecimal < ActiveRecord::Migration[8.1]
  def up
    change_column :listings, :bedrooms, :decimal, precision: 3, scale: 1
  end

  def down
    change_column :listings, :bedrooms, :integer
  end
end
