class BackfillDistances < ActiveRecord::Migration[8.0]
  def up
    listings = Listing.where(distance_km: nil)
    say "Backfilling distances for #{listings.count} listings..."

    listings.find_each.with_index(1) do |listing, i|
      say "#{i}. #{listing.street_address || listing.neighbourhood}, #{listing.city}"

      result = DistanceService.compute_for(listing)
      if result
        listing.update_columns(distance_km: result.distance_km, drive_minutes: result.drive_minutes)

        score_result = ListingScorer.score(listing)
        listing.update_columns(
          score:           score_result[:score],
          score_breakdown: score_result[:breakdown].merge(flags: score_result[:flags])
        )
        say "   → #{result.distance_km}km / #{result.drive_minutes}min (score: #{score_result[:score]})"
      else
        say "   → FAILED"
      end

      sleep 1.1
    end
  end

  def down; end
end
