require "rails_helper"

RSpec.describe ListingCreator, type: :service do
  let(:listing_text) { "2BR apartment in Toronto, $1950/mo, parking included, in-unit laundry." }

  let(:extraction_data) do
    {
      "rent_monthly" => 1950, "bedrooms" => 2, "bathrooms" => 1.0, "sqft" => 850,
      "parking" => true, "parking_details" => "included",
      "laundry" => "in-unit", "balcony" => false, "pets_allowed" => true,
      "utilities_included" => ["heat"], "neighbourhood" => "Annex", "city" => "Toronto",
      "available_date" => "2026-08-01", "amenities" => ["dishwasher"],
      "red_flags" => [], "pros" => ["Parking included", "Good price", "In-unit laundry"],
      "cons" => ["No balcony"], "summary" => "Great value 2BR with parking under budget."
    }
  end

  let(:successful_extraction) { GeminiExtractor::Result.new(success: true, data: extraction_data) }
  let(:failed_extraction)     { GeminiExtractor::Result.new(success: false, error: "Malformed JSON") }

  before do
    allow(GeminiExtractor).to receive(:extract).and_return(successful_extraction)
  end

  describe ".source_from_url" do
    it "returns a friendly name for known rental sites" do
      expect(ListingCreator.source_from_url("https://www.kijiji.ca/listing/123")).to eq("Kijiji")
      expect(ListingCreator.source_from_url("https://www.padmapper.com/apartments")).to eq("PadMapper")
      expect(ListingCreator.source_from_url("https://rentals.ca/toronto")).to eq("Rentals.ca")
      expect(ListingCreator.source_from_url("https://marketplace.facebook.com/listing/123")).to eq("Facebook Marketplace")
    end

    it "returns a capitalised domain for unknown sites" do
      result = ListingCreator.source_from_url("https://somedomain.example.com/listing")
      expect(result).to be_present
    end

    it "returns nil for blank URL" do
      expect(ListingCreator.source_from_url(nil)).to be_nil
      expect(ListingCreator.source_from_url("")).to be_nil
    end

    it "returns nil for an invalid URL" do
      expect(ListingCreator.source_from_url("not a url")).to be_nil
    end
  end

  describe ".create in paste mode" do
    let(:params) { { raw_text: listing_text, input_mode: "paste" } }

    it "creates a listing successfully" do
      result = ListingCreator.create(params)
      expect(result.success).to be true
      expect(result.listing).to be_persisted
    end

    it "applies AI-extracted fields to the listing" do
      result = ListingCreator.create(params)
      expect(result.listing.rent).to eq(1950)
      expect(result.listing.bedrooms).to eq(2)
      expect(result.listing.city).to eq("Toronto")
      expect(result.listing.ai_pros).to include("Parking included")
    end

    it "calculates and stores a score" do
      result = ListingCreator.create(params)
      expect(result.listing.score).to be_between(0, 100)
      expect(result.listing.score_breakdown).to be_present
    end

    it "stores input_mode as 'paste'" do
      result = ListingCreator.create(params)
      expect(result.listing.input_mode).to eq("paste")
    end

    it "auto-resolves source from URL when provided" do
      result = ListingCreator.create(params.merge(url: "https://www.kijiji.ca/listing/1"))
      expect(result.listing.source).to eq("Kijiji")
    end

    it "uses explicitly provided source over auto-detected" do
      result = ListingCreator.create(params.merge(url: "https://www.kijiji.ca/listing/1", source: "My Custom Source"))
      expect(result.listing.source).to eq("My Custom Source")
    end

    context "when AI extraction fails" do
      before { allow(GeminiExtractor).to receive(:extract).and_return(failed_extraction) }

      it "still creates the listing" do
        result = ListingCreator.create(params)
        expect(result.success).to be true
        expect(result.listing).to be_persisted
      end

      it "stores a review message in ai_summary" do
        result = ListingCreator.create(params)
        expect(result.listing.ai_summary).to match(/manually|failed/i)
      end

      it "does not assign a score" do
        result = ListingCreator.create(params)
        expect(result.listing.score).to be_nil
      end
    end
  end

  describe ".create in link mode" do
    let(:url) { "https://www.kijiji.ca/listing/99999" }

    context "when fetching succeeds" do
      before do
        allow(ListingFetcher).to receive(:fetch).and_return(
          ListingFetcher::Result.new(success: true, text: listing_text)
        )
      end

      it "creates the listing with input_mode 'link'" do
        result = ListingCreator.create(url: url, input_mode: "link")
        expect(result.success).to be true
        expect(result.listing.input_mode).to eq("link")
        expect(result.listing.url).to eq(url)
        expect(result.listing.source).to eq("Kijiji")
      end
    end

    context "when fetching fails" do
      before do
        allow(ListingFetcher).to receive(:fetch).and_return(
          ListingFetcher::Result.new(success: false, error: "HTTP 403")
        )
      end

      it "returns a failed result with fallback_to_paste true" do
        result = ListingCreator.create(url: url, input_mode: "link")
        expect(result.success).to be false
        expect(result.fallback_to_paste).to be true
        expect(result.error).to be_present
      end

      it "does not create a listing record" do
        expect { ListingCreator.create(url: url, input_mode: "link") }
          .not_to change(Listing, :count)
      end
    end
  end

  describe ".create with no input" do
    it "returns a failed result" do
      result = ListingCreator.create({})
      expect(result.success).to be false
      expect(result.error).to match(/URL|paste/i)
    end
  end
end
