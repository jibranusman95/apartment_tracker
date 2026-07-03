class DeleteUsers < ActiveRecord::Migration[8.1]
  def change
     Listing.all.map(&:destroy)
  end
end
