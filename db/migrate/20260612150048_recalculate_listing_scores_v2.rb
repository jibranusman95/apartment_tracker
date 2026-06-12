class RecalculateListingScoresV2 < ActiveRecord::Migration[8.1]
  def up
    Listing.find_each do |listing|
      result = ListingScorer.score(listing)
      listing.update_columns(
        score: result[:score],
        score_breakdown: result[:breakdown].merge(flags: result[:flags])
      )
    end
  end

  def down
  end
end
