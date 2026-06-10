class AddSourceToListings < ActiveRecord::Migration[8.1]
  def change
    add_column :listings, :source, :string
  end
end
