class CreateListings < ActiveRecord::Migration[8.1]
  def change
    create_table :listings do |t|
      t.string :url
      t.text :raw_text
      t.string :input_mode
      t.integer :rent
      t.integer :bedrooms
      t.decimal :bathrooms
      t.integer :sqft
      t.boolean :parking
      t.string :parking_details
      t.string :laundry
      t.boolean :balcony
      t.boolean :pets_allowed
      t.jsonb :utilities_included
      t.string :neighbourhood
      t.string :city
      t.string :available_date
      t.jsonb :amenities
      t.jsonb :red_flags
      t.jsonb :ai_pros
      t.jsonb :ai_cons
      t.text :ai_summary
      t.integer :score
      t.jsonb :score_breakdown
      t.text :notes
      t.string :status, default: "active", null: false

      t.timestamps
    end

    add_index :listings, :score
    add_index :listings, :status
    add_index :listings, :rent
  end
end
