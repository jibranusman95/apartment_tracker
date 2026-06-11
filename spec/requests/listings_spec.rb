require "rails_helper"

RSpec.describe "Listings", type: :request do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("APP_PIN").and_return("1234")
    sign_in_with_pin("1234")
  end

  let(:extraction_data) do
    {
      "rent_monthly" => 1950, "bedrooms" => 2, "bathrooms" => 1.0, "sqft" => 800,
      "parking" => true, "parking_details" => "included", "laundry" => "in-unit",
      "balcony" => true, "pets_allowed" => false, "utilities_included" => [ "heat" ],
      "neighbourhood" => "Annex", "city" => "Toronto", "available_date" => "2026-08-01",
      "amenities" => [ "dishwasher" ], "red_flags" => [],
      "pros" => [ "Parking", "Good price", "Laundry" ],
      "cons" => [ "No pets" ],
      "summary" => "Solid 2BR under budget."
    }
  end

  before do
    allow(GeminiExtractor).to receive(:extract).and_return(
      GeminiExtractor::Result.new(success: true, data: extraction_data)
    )
  end

  # ── Dashboard ──────────────────────────────────────────────────────────────

  describe "GET /" do
    let!(:active)   { create(:listing, status: "active", score: 80) }
    let!(:gone_one) { create(:listing, :gone, score: 50) }

    it "returns 200 and shows active listings" do
      get root_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(active.neighbourhood)
    end

    it "hides gone listings by default" do
      get root_path
      expect(response.body).not_to include(gone_one.neighbourhood)
    end

    it "shows all listings with filter=all" do
      get root_path, params: { filter: "all" }
      expect(response.body).to include(active.neighbourhood)
      expect(response.body).to include(gone_one.neighbourhood)
    end

    it "filters to under $2k listings" do
      cheap  = create(:listing, rent: 1800, score: 90)
      pricey = create(:listing, rent: 2500, score: 20)
      get root_path, params: { filter: "under_2k" }
      expect(response.body).to include(cheap.neighbourhood)
      expect(response.body).not_to include(pricey.neighbourhood)
    end

    it "filters to 2BR listings" do
      two_br = create(:listing, bedrooms: 2, neighbourhood: "Two BR Area")
      one_br = create(:listing, bedrooms: 1, neighbourhood: "One BR Area")
      get root_path, params: { filter: "two_br" }
      expect(response.body).to include("Two BR Area")
      expect(response.body).not_to include("One BR Area")
    end

    it "filters to listings with parking" do
      park    = create(:listing, parking: true,  neighbourhood: "Park Street")
      no_park = create(:listing, parking: false, neighbourhood: "No Park Ave")
      get root_path, params: { filter: "has_parking" }
      expect(response.body).to include("Park Street")
      expect(response.body).not_to include("No Park Ave")
    end
  end

  # ── New listing form ───────────────────────────────────────────────────────

  describe "GET /listings/new" do
    it "renders the new listing form" do
      get new_listing_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Add Listing")
    end
  end

  # ── Create listing ─────────────────────────────────────────────────────────

  describe "POST /listings (paste mode)" do
    let(:valid_params) do
      { listing: { raw_text: "Nice 2BR apartment in Toronto $1950/mo parking included",
                   input_mode: "paste" } }
    end

    it "creates a listing and redirects to detail" do
      expect { post listings_path, params: valid_params }
        .to change(Listing, :count).by(1)
      expect(response).to redirect_to(listing_path(Listing.last))
    end

    it "stores the raw text" do
      post listings_path, params: valid_params
      expect(Listing.last.raw_text).to include("2BR")
    end

    it "applies AI-extracted data" do
      post listings_path, params: valid_params
      expect(Listing.last.rent).to eq(1950)
      expect(Listing.last.city).to eq("Toronto")
    end

    it "assigns a score" do
      post listings_path, params: valid_params
      expect(Listing.last.score).to be_present
    end

    it "stores the source when provided" do
      post listings_path, params: { listing: valid_params[:listing].merge(source: "Kijiji") }
      expect(Listing.last.source).to eq("Kijiji")
    end

    context "when AI extraction fails" do
      before do
        allow(GeminiExtractor).to receive(:extract).and_return(
          GeminiExtractor::Result.new(success: false, error: "Malformed JSON")
        )
      end

      it "still creates the listing" do
        expect { post listings_path, params: valid_params }
          .to change(Listing, :count).by(1)
      end
    end

    context "when no text or URL is provided" do
      it "re-renders the form with an error" do
        post listings_path, params: { listing: { input_mode: "paste" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "POST /listings (link mode with fetch fallback)" do
    before do
      allow(ListingFetcher).to receive(:fetch).and_return(
        ListingFetcher::Result.new(success: false, error: "HTTP 403")
      )
    end

    it "re-renders the form with a warning and fallback mode" do
      post listings_path, params: { listing: { url: "https://example.com/listing", input_mode: "link" } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to match(/paste|description/i)
    end
  end

  # ── Show ───────────────────────────────────────────────────────────────────

  describe "GET /listings/:id" do
    let(:listing) { create(:listing) }

    it "renders the detail view" do
      get listing_path(listing)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(listing.neighbourhood)
    end

    it "shows the source badge when source is present" do
      listing.update!(source: "Kijiji")
      get listing_path(listing)
      expect(response.body).to include("Kijiji")
    end

    it "shows the score breakdown" do
      get listing_path(listing)
      expect(response.body).to include("Score Breakdown")
    end
  end

  # ── Toggle status ──────────────────────────────────────────────────────────

  describe "PATCH /listings/:id/toggle_status" do
    let(:listing) { create(:listing, status: "active") }

    it "marks an active listing as gone" do
      patch toggle_status_listing_path(listing)
      expect(listing.reload.status).to eq("gone")
    end

    it "marks a gone listing back to active" do
      listing.update!(status: "gone")
      patch toggle_status_listing_path(listing)
      expect(listing.reload.status).to eq("active")
    end
  end

  # ── Notes auto-save ────────────────────────────────────────────────────────

  describe "PATCH /listings/:id/update_notes" do
    let(:listing) { create(:listing, notes: nil) }

    it "updates the notes and returns 200" do
      patch update_notes_listing_path(listing), params: { notes: "Great location, needs follow-up" }
      expect(response).to have_http_status(:ok)
      expect(listing.reload.notes).to eq("Great location, needs follow-up")
    end

    it "allows clearing notes" do
      listing.update!(notes: "Some old note")
      patch update_notes_listing_path(listing), params: { notes: "" }
      expect(response).to have_http_status(:ok)
      expect(listing.reload.notes).to eq("")
    end
  end

  # ── Resolve source ─────────────────────────────────────────────────────────

  describe "GET /listings/resolve_source" do
    it "returns the source name for a known URL" do
      get resolve_source_listings_path, params: { url: "https://www.kijiji.ca/listing/123" }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["source"]).to eq("Kijiji")
    end

    it "returns a source for an unknown domain" do
      get resolve_source_listings_path, params: { url: "https://somedomain.ca/listing/1" }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["source"]).to be_present
    end

    it "returns nil source for blank URL" do
      get resolve_source_listings_path, params: { url: "" }
      json = JSON.parse(response.body)
      expect(json["source"]).to be_nil
    end
  end

  # ── Edit / Update ──────────────────────────────────────────────────────────

  describe "PATCH /listings/:id" do
    let(:listing) { create(:listing) }

    it "updates editable fields" do
      patch listing_path(listing), params: {
        listing: { rent: 2100, notes: "Updated note", source: "PadMapper" }
      }
      listing.reload
      expect(listing.rent).to eq(2100)
      expect(listing.notes).to eq("Updated note")
      expect(listing.source).to eq("PadMapper")
    end

    it "redirects to the detail view after save" do
      patch listing_path(listing), params: { listing: { rent: 1800 } }
      expect(response).to redirect_to(listing_path(listing))
    end
  end

  # ── Delete ─────────────────────────────────────────────────────────────────

  describe "DELETE /listings/:id" do
    let!(:listing) { create(:listing) }

    it "destroys the listing and redirects to dashboard" do
      expect { delete listing_path(listing) }
        .to change(Listing, :count).by(-1)
      expect(response).to redirect_to(root_path)
    end
  end
end
