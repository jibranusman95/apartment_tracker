class AddFavoritedAndDistanceToListings < ActiveRecord::Migration[8.1]
  def change
    add_column :listings, :favorited, :boolean, default: false, null: false
    add_column :listings, :distance_km, :decimal
    add_column :listings, :drive_minutes, :integer
  end
end
