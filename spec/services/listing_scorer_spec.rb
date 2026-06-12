require "rails_helper"

RSpec.describe ListingScorer, type: :service do
  def score_listing(attrs = {})
    listing = build(:listing, attrs)
    ListingScorer.score(listing)
  end

  # ── Price scoring ─────────────────────────────────────────────────────────

  describe "price scoring (30 pts max)" do
    it "awards 30 pts for rent <= $2000" do
      result = score_listing(rent: 2000)
      expect(result[:breakdown][:price]).to eq(30)
      expect(result[:flags]).not_to include(match(/OVER/))
    end

    it "awards 23 pts for rent $2001–$2150" do
      result = score_listing(rent: 2100)
      expect(result[:breakdown][:price]).to eq(23)
    end

    it "awards 16 pts for rent $2151–$2250" do
      result = score_listing(rent: 2200)
      expect(result[:breakdown][:price]).to eq(16)
    end

    it "awards 0 pts and flags OVER HARD LIMIT for rent > $2250" do
      result = score_listing(rent: 2500)
      expect(result[:breakdown][:price]).to eq(0)
      expect(result[:flags]).to include("OVER HARD LIMIT")
    end

    it "awards 0 pts for nil rent" do
      result = score_listing(rent: nil)
      expect(result[:breakdown][:price]).to eq(0)
    end
  end

  # ── Parking scoring ───────────────────────────────────────────────────────

  describe "parking scoring (10 pts max)" do
    it "awards 10 pts when parking is included in rent" do
      result = score_listing(parking: true, parking_details: "included")
      expect(result[:breakdown][:parking]).to eq(10)
    end

    it "awards 5 pts when parking costs extra" do
      result = score_listing(parking: true, parking_details: "extra $150/mo")
      expect(result[:breakdown][:parking]).to eq(5)
    end

    it "awards 0 pts and adds flag when parking is false" do
      result = score_listing(parking: false, parking_details: nil)
      expect(result[:breakdown][:parking]).to eq(0)
      expect(result[:flags]).to include("MISSING MUST-HAVE: No parking")
    end

    it "awards 0 pts for nil parking" do
      result = score_listing(parking: nil)
      expect(result[:breakdown][:parking]).to eq(0)
    end
  end

  # ── Bedroom scoring ───────────────────────────────────────────────────────

  describe "bedroom scoring (20 pts max)" do
    it "awards 20 pts for 2 bedrooms" do
      expect(score_listing(bedrooms: 2)[:breakdown][:bedrooms]).to eq(20)
    end

    it "awards 20 pts for 2 BR + den (2.5–2.7)" do
      expect(score_listing(bedrooms: 2.5)[:breakdown][:bedrooms]).to eq(20)
      expect(score_listing(bedrooms: 2.7)[:breakdown][:bedrooms]).to eq(20)
    end

    it "awards 16 pts for 1 BR + den (1.5–1.7)" do
      expect(score_listing(bedrooms: 1.5)[:breakdown][:bedrooms]).to eq(16)
      expect(score_listing(bedrooms: 1.7)[:breakdown][:bedrooms]).to eq(16)
    end

    it "awards 10 pts for 1 bedroom" do
      expect(score_listing(bedrooms: 1)[:breakdown][:bedrooms]).to eq(10)
    end

    it "awards 0 pts for studio (0 bedrooms)" do
      expect(score_listing(bedrooms: 0)[:breakdown][:bedrooms]).to eq(0)
    end

    it "awards 0 pts for nil bedrooms" do
      expect(score_listing(bedrooms: nil)[:breakdown][:bedrooms]).to eq(0)
    end
  end

  # ── Sqft scoring ──────────────────────────────────────────────────────────

  describe "sqft scoring (20 pts max, relative)" do
    it "awards 10 pts (neutral) when sqft is nil" do
      result = score_listing(sqft: nil)
      expect(result[:breakdown][:sqft]).to eq(10)
    end

    it "awards 10 pts when it is the only listing with sqft" do
      create(:listing, sqft: 800)
      listing = build(:listing, sqft: 800)
      result = ListingScorer.score(listing)
      expect(result[:breakdown][:sqft]).to eq(10)
    end

    it "awards 20 pts for the largest sqft relative to others" do
      create(:listing, sqft: 500)
      create(:listing, sqft: 700)
      listing = build(:listing, sqft: 1000)
      result = ListingScorer.score(listing)
      expect(result[:breakdown][:sqft]).to eq(20)
    end

    it "awards 0 pts for the smallest sqft relative to others" do
      create(:listing, sqft: 700)
      create(:listing, sqft: 1000)
      listing = build(:listing, sqft: 500)
      result = ListingScorer.score(listing)
      expect(result[:breakdown][:sqft]).to eq(0)
    end
  end

  # ── Drive time scoring ────────────────────────────────────────────────────

  describe "drive time scoring (10 pts max)" do
    it "awards 10 pts for under 20 min drive" do
      expect(score_listing(drive_minutes: 10)[:breakdown][:drive_time]).to eq(10)
      expect(score_listing(drive_minutes: 19)[:breakdown][:drive_time]).to eq(10)
    end

    it "awards 9 pts at the 20 min boundary" do
      expect(score_listing(drive_minutes: 20)[:breakdown][:drive_time]).to eq(9)
    end

    it "awards 4 pts at the 42 min boundary" do
      expect(score_listing(drive_minutes: 42)[:breakdown][:drive_time]).to eq(4)
    end

    it "awards between 4 and 9 pts for 20–42 min drive" do
      result = score_listing(drive_minutes: 31)
      expect(result[:breakdown][:drive_time]).to be_between(4, 9)
    end

    it "awards 0 pts and flags TOO FAR for drive > 42 min" do
      result = score_listing(drive_minutes: 65)
      expect(result[:breakdown][:drive_time]).to eq(0)
      expect(result[:flags]).to include("TOO FAR: 65 min drive")
    end

    it "awards 0 pts for nil drive_minutes" do
      expect(score_listing(drive_minutes: nil)[:breakdown][:drive_time]).to eq(0)
    end
  end

  # ── Laundry scoring ───────────────────────────────────────────────────────

  describe "laundry scoring (5 pts)" do
    it "awards 5 pts for in-unit laundry" do
      expect(score_listing(laundry: "in-unit")[:breakdown][:laundry]).to eq(5)
    end

    it "awards 0 pts for shared laundry" do
      expect(score_listing(laundry: "shared")[:breakdown][:laundry]).to eq(0)
    end

    it "awards 0 pts for no laundry" do
      expect(score_listing(laundry: "none")[:breakdown][:laundry]).to eq(0)
    end
  end

  # ── Amenity scoring ───────────────────────────────────────────────────────

  describe "amenity bonus scoring (5 pts cap)" do
    it "awards 2 pts for dishwasher" do
      result = score_listing(laundry: "shared", amenities: [ "dishwasher" ])
      expect(result[:breakdown][:amenities]).to be >= 2
    end

    it "awards 2 pts for gym/pool" do
      result = score_listing(laundry: "shared", amenities: [ "gym" ])
      expect(result[:breakdown][:amenities]).to be >= 2
    end

    it "caps amenity score at 5" do
      result = score_listing(laundry: "shared", amenities: [ "dishwasher", "gym", "pool", "rooftop" ])
      expect(result[:breakdown][:amenities]).to eq(5)
    end
  end

  # ── Total score ───────────────────────────────────────────────────────────

  describe "total score" do
    it "returns a score between 0 and 100" do
      result = score_listing
      expect(result[:score]).to be_between(0, 100)
    end

    it "returns a high score for a great nearby listing" do
      result = score_listing(
        rent: 1800, bedrooms: 2, sqft: nil,
        parking: true, parking_details: "included",
        laundry: "in-unit", amenities: [ "dishwasher", "gym" ],
        drive_minutes: 15
      )
      expect(result[:score]).to be <= 100
      expect(result[:score]).to be >= 85
    end

    it "returns a low score for a bad listing" do
      result = score_listing(
        rent: 2600, bedrooms: 0, sqft: nil,
        parking: false, laundry: "none", amenities: [],
        drive_minutes: 90
      )
      expect(result[:score]).to be < 20
    end

    it "flags both OVER HARD LIMIT and TOO FAR when applicable" do
      result = score_listing(rent: 2600, drive_minutes: 65)
      expect(result[:flags]).to include("OVER HARD LIMIT")
      expect(result[:flags]).to include("TOO FAR: 65 min drive")
    end
  end
end
