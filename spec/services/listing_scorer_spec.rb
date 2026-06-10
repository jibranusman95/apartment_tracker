require "rails_helper"

RSpec.describe ListingScorer, type: :service do
  def score_listing(attrs = {})
    listing = build(:listing, attrs)
    ListingScorer.score(listing)
  end

  # ── Price scoring ─────────────────────────────────────────────────────────

  describe "price scoring (40 pts max)" do
    it "awards 40 pts for rent <= $2000" do
      result = score_listing(rent: 2000)
      expect(result[:breakdown][:price]).to eq(40)
      expect(result[:flags]).not_to include(match(/OVER/))
    end

    it "awards 25 pts for rent $2001–$2150" do
      result = score_listing(rent: 2100)
      expect(result[:breakdown][:price]).to eq(25)
    end

    it "awards 10 pts for rent $2151–$2250" do
      result = score_listing(rent: 2200)
      expect(result[:breakdown][:price]).to eq(10)
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

  describe "parking scoring (25 pts max)" do
    it "awards 25 pts when parking is true and included in rent" do
      result = score_listing(parking: true, parking_details: "included")
      expect(result[:breakdown][:parking]).to eq(25)
    end

    it "awards 10 pts when parking is true but costs extra" do
      result = score_listing(parking: true, parking_details: "extra $150/mo")
      expect(result[:breakdown][:parking]).to eq(10)
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

  describe "bedroom scoring (15 pts max)" do
    it "awards 15 pts for 2+ bedrooms" do
      expect(score_listing(bedrooms: 2)[:breakdown][:bedrooms]).to eq(15)
      expect(score_listing(bedrooms: 3)[:breakdown][:bedrooms]).to eq(15)
    end

    it "awards 8 pts for 1 bedroom" do
      expect(score_listing(bedrooms: 1)[:breakdown][:bedrooms]).to eq(8)
    end

    it "awards 0 pts for studio (0 bedrooms)" do
      expect(score_listing(bedrooms: 0)[:breakdown][:bedrooms]).to eq(0)
    end

    it "awards 0 pts for nil bedrooms" do
      expect(score_listing(bedrooms: nil)[:breakdown][:bedrooms]).to eq(0)
    end
  end

  # ── Sqft scoring ──────────────────────────────────────────────────────────

  describe "sqft scoring (10 pts max, relative)" do
    it "awards 5 pts (neutral) when sqft is nil" do
      result = score_listing(sqft: nil)
      expect(result[:breakdown][:sqft]).to eq(5)
    end

    it "awards 5 pts when it is the only listing with sqft" do
      # Only one record exists so min == max
      create(:listing, sqft: 800)
      listing = build(:listing, sqft: 800)
      result = ListingScorer.score(listing)
      expect(result[:breakdown][:sqft]).to eq(5)
    end

    it "awards 10 pts for the largest sqft relative to others" do
      create(:listing, sqft: 500)
      create(:listing, sqft: 700)
      listing = build(:listing, sqft: 1000)
      result = ListingScorer.score(listing)
      expect(result[:breakdown][:sqft]).to eq(10)
    end

    it "awards 0 pts for the smallest sqft relative to others" do
      create(:listing, sqft: 700)
      create(:listing, sqft: 1000)
      listing = build(:listing, sqft: 500)
      result = ListingScorer.score(listing)
      expect(result[:breakdown][:sqft]).to eq(0)
    end
  end

  # ── Balcony scoring ───────────────────────────────────────────────────────

  describe "balcony scoring (5 pts)" do
    it "awards 5 pts when balcony is true" do
      expect(score_listing(balcony: true)[:breakdown][:balcony]).to eq(5)
    end

    it "awards 0 pts when balcony is false" do
      expect(score_listing(balcony: false)[:breakdown][:balcony]).to eq(0)
    end
  end

  # ── Amenity scoring ───────────────────────────────────────────────────────

  describe "amenity bonus scoring (5 pts cap)" do
    it "awards 2 pts for in-unit laundry" do
      result = score_listing(laundry: "in-unit", amenities: [], balcony: false)
      expect(result[:breakdown][:amenities]).to be >= 2
    end

    it "awards 1 pt for dishwasher" do
      result = score_listing(laundry: "shared", amenities: [ "dishwasher" ], balcony: false)
      expect(result[:breakdown][:amenities]).to be >= 1
    end

    it "awards 1 pt for gym/pool" do
      result = score_listing(laundry: "shared", amenities: [ "gym" ], balcony: false)
      expect(result[:breakdown][:amenities]).to be >= 1
    end

    it "caps amenity score at 5" do
      result = score_listing(laundry: "in-unit", amenities: [ "dishwasher", "gym", "pool", "rooftop" ])
      expect(result[:breakdown][:amenities]).to eq(5)
    end
  end

  # ── Total score ───────────────────────────────────────────────────────────

  describe "total score" do
    it "returns a score between 0 and 100" do
      result = score_listing
      expect(result[:score]).to be_between(0, 100)
    end

    it "returns maximum 100 for a perfect listing" do
      result = score_listing(
        rent: 1800, bedrooms: 2, sqft: nil,
        parking: true, parking_details: "included",
        balcony: true, laundry: "in-unit",
        amenities: [ "dishwasher", "gym" ]
      )
      expect(result[:score]).to be <= 100
      expect(result[:score]).to be >= 85
    end

    it "returns a low score for a bad listing" do
      result = score_listing(
        rent: 2600, bedrooms: 0, sqft: nil,
        parking: false, balcony: false, laundry: "none", amenities: []
      )
      expect(result[:score]).to be < 20
    end
  end
end
