class ListingScorer
  # Returns { score: Integer, breakdown: Hash, flags: Array }

  def self.score(listing)
    new(listing).score
  end

  def initialize(listing)
    @listing = listing
  end

  def score
    breakdown = {}
    flags = []

    breakdown[:price]     = price_score(flags)
    breakdown[:parking]   = parking_score(flags)
    breakdown[:bedrooms]  = bedroom_score
    breakdown[:sqft]      = sqft_score
    breakdown[:balcony]   = balcony_score
    breakdown[:amenities] = amenity_score

    total = breakdown.values.sum

    { score: total.clamp(0, 100), breakdown: breakdown, flags: flags }
  end

  private

  def price_score(flags)
    rent = @listing.rent
    return 0 if rent.nil?

    if rent <= 2000
      40
    elsif rent <= 2150
      25
    elsif rent <= 2250
      10
    else
      flags << "OVER HARD LIMIT"
      0
    end
  end

  def parking_score(flags)
    parking = @listing.parking
    details = @listing.parking_details.to_s.downcase

    if parking == true
      if details.match?(/extra|additional|\$/)
        10
      else
        25
      end
    elsif parking == false
      flags << "MISSING MUST-HAVE: No parking"
      0
    else
      0
    end
  end

  def bedroom_score
    beds = @listing.bedrooms
    return 0 if beds.nil?

    beds >= 2 ? 15 : (beds == 1 ? 8 : 0)
  end

  def sqft_score
    sqft = @listing.sqft
    return 5 if sqft.nil?

    all_sqft = Listing.where.not(sqft: nil).pluck(:sqft)
    return 5 if all_sqft.size <= 1

    min_sqft = all_sqft.min.to_f
    max_sqft = all_sqft.max.to_f
    return 5 if min_sqft == max_sqft

    ((sqft - min_sqft) / (max_sqft - min_sqft) * 10).round.clamp(0, 10)
  end

  def balcony_score
    @listing.balcony ? 5 : 0
  end

  def amenity_score
    pts = 0
    amenities_text = (@listing.amenities || []).map(&:downcase).join(" ")

    pts += 2 if @listing.laundry.to_s.match?(/in.?unit/)
    pts += 1 if amenities_text.include?("dishwasher")
    pts += 1 if amenities_text.match?(/gym|pool|fitness/)
    # +1 for any other notable amenity
    pts += 1 if @listing.amenities.present? && @listing.amenities.length > 0 && pts < 5

    pts.clamp(0, 5)
  end
end
