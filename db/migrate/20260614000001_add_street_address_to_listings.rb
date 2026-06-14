class AddStreetAddressToListings < ActiveRecord::Migration[8.0]
  def up
    add_column :listings, :street_address, :string

    Listing.where.not(raw_text: nil).find_each.with_index(1) do |listing, i|
      say "#{i}. #{listing.neighbourhood}, #{listing.city}"

      # Re-extract street_address from stored raw_text
      if listing.raw_text.present?
        street = extract_street_address(listing.raw_text)
        if street
          listing.update_column(:street_address, street)
          say "   → street address: #{street}"
        end
        sleep 0.5
      end

      # Compute real distance via Nominatim + ORS
      result = DistanceService.compute_for(listing)
      if result
        listing.update_columns(distance_km: result.distance_km, drive_minutes: result.drive_minutes)
        say "   → #{result.distance_km}km / #{result.drive_minutes}min"

        # Recalculate score since drive_minutes affects it
        score_result = ListingScorer.score(listing)
        listing.update_columns(
          score:           score_result[:score],
          score_breakdown: score_result[:breakdown].merge(flags: score_result[:flags])
        )
        say "   → score: #{score_result[:score]}"
      else
        say "   → distance skipped (address too vague or missing API key)"
      end

      sleep 1.1 # Nominatim rate limit
    end
  end

  def down
    remove_column :listings, :street_address
  end

  private

  def extract_street_address(raw_text)
    prompt = <<~PROMPT.strip
      Extract the street address from this rental listing if one is explicitly stated.
      Return JSON only with one field: street_address (string or null). Do not infer or guess.
      Listing text: #{raw_text.truncate(4_000)}
    PROMPT

    result = GeminiExtractor.extract_with_prompts(
      "Return a JSON object only, no markdown, no preamble.",
      prompt
    )
    return nil unless result.success

    result.data["street_address"].presence
  rescue StandardError
    nil
  end
end
