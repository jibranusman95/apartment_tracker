require "rails_helper"

RSpec.describe "Listings system", type: :system do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("APP_PIN").and_return("1234")
  end

  let(:extraction_data) do
    {
      "rent_monthly" => 1850, "bedrooms" => 2, "bathrooms" => 1.0, "sqft" => 900,
      "parking" => true, "parking_details" => "included", "laundry" => "in-unit",
      "balcony" => true, "pets_allowed" => true, "utilities_included" => [ "heat", "water" ],
      "neighbourhood" => "The Annex", "city" => "Toronto", "available_date" => "2026-08-01",
      "amenities" => [ "dishwasher", "gym" ], "red_flags" => [],
      "pros" => [ "Under budget", "Parking included", "Great location" ],
      "cons" => [ "Older building" ],
      "summary" => "Excellent 2BR with all must-haves under budget. Highly recommended."
    }
  end

  before do
    allow(GeminiExtractor).to receive(:extract).and_return(
      GeminiExtractor::Result.new(success: true, data: extraction_data)
    )
  end

  # ── PIN screen ─────────────────────────────────────────────────────────────

  describe "PIN authentication" do
    it "shows the PIN screen for unauthenticated users" do
      visit root_path
      expect(page).to have_current_path(new_session_path)
      expect(page).to have_content("PIN")
    end

    it "unlocks the app with the correct PIN" do
      visit new_session_path
      fill_in "pin", with: "1234"
      click_button "Unlock"
      expect(page).to have_current_path(root_path)
      expect(page).to have_content("Home Finder")
    end

    it "shows an error for the wrong PIN" do
      visit new_session_path
      fill_in "pin", with: "0000"
      click_button "Unlock"
      expect(page).to have_content("Wrong PIN")
      expect(page).to have_current_path(session_path)
    end
  end

  # ── Dashboard ──────────────────────────────────────────────────────────────

  describe "Dashboard" do
    before { browser_sign_in }

    let!(:listing_a) { create(:listing, neighbourhood: "Annex", rent: 1900, score: 85, status: "active") }
    let!(:listing_b) { create(:listing, neighbourhood: "Parkdale", rent: 2100, score: 60, status: "active") }
    let!(:gone_listing) { create(:listing, :gone, neighbourhood: "Leslieville") }

    it "shows active listings sorted by score" do
      visit root_path
      cards = all(".rounded-2xl").map(&:text)
      annex_pos   = cards.index { |c| c.include?("Annex") }
      parkdale_pos = cards.index { |c| c.include?("Parkdale") }
      expect(annex_pos).to be < parkdale_pos
    end

    it "does not show gone listings by default" do
      visit root_path
      expect(page).not_to have_content("Leslieville")
    end

    it "shows all listings including gone when filter=all" do
      visit root_path(filter: "all")
      expect(page).to have_content("Leslieville")
    end

    it "shows the listing count" do
      visit root_path
      expect(page).to have_content("2 listings")
    end

    it "shows score badges colour-coded" do
      visit root_path
      expect(page).to have_content("85")
      expect(page).to have_content("60")
    end

    it "shows parking status icons" do
      visit root_path
      expect(page).to have_content("🚗 Parking")
    end

    it "shows budget badges" do
      visit root_path
      expect(page).to have_content("Under $2k").or have_content("Soft Limit")
    end

    it "shows top 2 pros as tags" do
      visit root_path
      expect(page).to have_content(listing_a.ai_pros.first)
    end

    it "navigates to detail view on card tap" do
      visit root_path
      click_link listing_a.neighbourhood
      expect(page).to have_current_path(listing_path(listing_a))
    end

    it "has the + FAB button" do
      visit root_path
      expect(page).to have_link("+", href: new_listing_path)
    end

    context "filter pills" do
      let!(:under_2k) { create(:listing, rent: 1800, neighbourhood: "Cheap Area", score: 88) }
      let!(:over_2k)  { create(:listing, rent: 2400, neighbourhood: "Pricey Place", score: 30) }

      it "filters to under $2k" do
        visit root_path
        click_link "Under $2k"
        expect(page).to have_content("Cheap Area")
        expect(page).not_to have_content("Pricey Place")
      end
    end
  end

  # ── Add listing form ───────────────────────────────────────────────────────
  # Mode-switching relies on JS — requires a real browser.

  describe "Add listing (paste mode)", :js do
    before { browser_sign_in }

    it "successfully submits a pasted listing and redirects to detail" do
      visit new_listing_path
      click_button "📋 Paste Text"
      fill_in "Listing Description", with: "2BR in The Annex, Toronto. $1850/mo. Parking, in-unit laundry, balcony."
      click_button "Extract & Score with AI ✨"

      expect(page).to have_content("Listing added!")
      expect(page).to have_content("The Annex")
      expect(page).to have_content("$1,850")
    end

    it "shows extracted pros" do
      visit new_listing_path
      click_button "📋 Paste Text"
      fill_in "Listing Description", with: "2BR Toronto apartment $1850/mo parking"
      click_button "Extract & Score with AI ✨"
      expect(page).to have_content("Under budget").or have_content("Parking included")
    end

    it "allows adding a source manually" do
      visit new_listing_path
      click_button "📋 Paste Text"
      fill_in "Listing Description", with: "2BR Toronto $1850/mo"
      fill_in "Source / Website", with: "Facebook Marketplace"
      click_button "Extract & Score with AI ✨"
      expect(page).to have_content("Facebook Marketplace")
    end
  end

  # ── Detail view ───────────────────────────────────────────────────────────

  describe "Listing detail view" do
    before { browser_sign_in }
    let(:listing) { create(:listing, :with_url) }

    it "shows all key listing details" do
      visit listing_path(listing)
      expect(page).to have_content(listing.neighbourhood)
      expect(page).to have_content(listing.score.to_s)
      expect(page).to have_content("Score Breakdown")
      expect(page).to have_content("Pros")
    end

    it "shows the source badge" do
      visit listing_path(listing)
      expect(page).to have_content(listing.source)
    end

    it "shows the original URL as a link" do
      visit listing_path(listing)
      expect(page).to have_link(href: listing.url)
    end

    it "shows pros and cons" do
      visit listing_path(listing)
      expect(page).to have_content("Pros")
      expect(page).to have_content(listing.ai_pros.first)
      expect(page).to have_content("Cons")
    end

    it "shows the AI summary" do
      visit listing_path(listing)
      expect(page).to have_content(listing.ai_summary)
    end

    it "has a collapsible original text section" do
      visit listing_path(listing)
      expect(page).to have_css("details summary", text: /Show original text/i)
    end
  end

  # ── Notes auto-save ────────────────────────────────────────────────────────
  # Requires a real browser (JS). Covered by request spec update_notes otherwise.

  describe "Notes field", :js do
    before { browser_sign_in }
    let(:listing) { create(:listing, notes: nil) }

    it "auto-saves notes on blur" do
      visit listing_path(listing)
      fill_in "listing-notes", with: "Really liked this one, follow up Monday"
      find("h2", text: "Notes").click
      sleep 1
      expect(listing.reload.notes).to eq("Really liked this one, follow up Monday")
    end
  end

  # ── Mark as gone ───────────────────────────────────────────────────────────

  describe "Mark as Gone" do
    before { browser_sign_in }
    let(:listing) { create(:listing, status: "active") }

    it "marks a listing as gone and shows overlay on dashboard" do
      visit listing_path(listing)
      click_button "Mark as Gone"
      expect(listing.reload.gone?).to be true
    end

    it "can restore a gone listing" do
      listing.update!(status: "gone")
      visit listing_path(listing)
      click_button "Mark as Available"
      expect(listing.reload.gone?).to be false
    end
  end

  # ── Delete ─────────────────────────────────────────────────────────────────
  # `accept_confirm` requires a real browser. The underlying DELETE action is
  # covered by the request spec. JS confirmation tested here when Chrome is available.

  describe "Delete listing", :js do
    before { browser_sign_in }
    let!(:listing) { create(:listing) }

    it "deletes the listing and returns to dashboard" do
      visit listing_path(listing)
      accept_confirm { click_button "Delete Listing" }
      expect(page).to have_current_path(root_path)
      expect(Listing.count).to eq(0)
    end
  end
end
