require "rails_helper"

RSpec.describe Listing, type: :model do
  subject(:listing) { build(:listing) }

  # ── Validations ──────────────────────────────────────────────────────────────

  describe "validations" do
    it { is_expected.to validate_presence_of(:raw_text) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[active gone]) }
    it { is_expected.to allow_value("link", "paste", nil, "").for(:input_mode) }

    it "is invalid with an unknown status" do
      listing.status = "sold"
      expect(listing).not_to be_valid
    end

    it "is valid with minimum required attributes" do
      expect(listing).to be_valid
    end

    it "is valid with a nil url" do
      listing.url = nil
      expect(listing).to be_valid
    end
  end

  # ── Scopes ───────────────────────────────────────────────────────────────────

  describe "scopes" do
    let!(:active_listing) { create(:listing, status: "active", score: 80) }
    let!(:gone_listing)   { create(:listing, :gone, score: 60) }
    let!(:cheap_listing)  { create(:listing, rent: 1800, score: 90) }
    let!(:expensive)      { create(:listing, rent: 2500, score: 20) }
    let!(:two_br)         { create(:listing, bedrooms: 2) }
    let!(:one_br)         { create(:listing, bedrooms: 1) }
    let!(:with_parking)   { create(:listing, parking: true) }
    let!(:no_parking)     { create(:listing, :no_parking) }

    it ".active returns only active listings" do
      expect(Listing.active).to include(active_listing)
      expect(Listing.active).not_to include(gone_listing)
    end

    it ".gone returns only gone listings" do
      expect(Listing.gone).to include(gone_listing)
      expect(Listing.gone).not_to include(active_listing)
    end

    it ".by_score orders by score descending" do
      scores = Listing.by_score.pluck(:score).compact
      expect(scores).to eq(scores.sort.reverse)
    end

    it ".under_2k returns listings with rent <= 2000" do
      expect(Listing.under_2k).to include(cheap_listing)
      expect(Listing.under_2k).not_to include(expensive)
    end

    it ".two_br returns listings with 2+ bedrooms" do
      expect(Listing.two_br).to include(two_br)
      expect(Listing.two_br).not_to include(one_br)
    end

    it ".has_parking returns listings with parking true" do
      expect(Listing.has_parking).to include(with_parking)
      expect(Listing.has_parking).not_to include(no_parking)
    end
  end

  # ── Instance methods ─────────────────────────────────────────────────────────

  describe "#over_budget?" do
    it "returns true when rent > 2250" do
      listing.rent = 2300
      expect(listing.over_budget?).to be true
    end

    it "returns false when rent <= 2250" do
      listing.rent = 2250
      expect(listing.over_budget?).to be false
    end

    it "returns false when rent is nil" do
      listing.rent = nil
      expect(listing.over_budget?).to be false
    end
  end

  describe "#budget_label" do
    it "returns 'under_2k' when rent <= 2000" do
      listing.rent = 1900
      expect(listing.budget_label).to eq("under_2k")
    end

    it "returns 'soft_limit' when rent is 2001–2250" do
      listing.rent = 2100
      expect(listing.budget_label).to eq("soft_limit")
    end

    it "returns 'over_budget' when rent > 2250" do
      listing.rent = 2600
      expect(listing.budget_label).to eq("over_budget")
    end

    it "returns nil when rent is nil" do
      listing.rent = nil
      expect(listing.budget_label).to be_nil
    end
  end

  describe "#gone?" do
    it "returns true when status is 'gone'" do
      listing.status = "gone"
      expect(listing.gone?).to be true
    end

    it "returns false when status is 'active'" do
      listing.status = "active"
      expect(listing.gone?).to be false
    end
  end

  describe "#score_color" do
    it "returns 'green' for score >= 70" do
      listing.score = 70
      expect(listing.score_color).to eq("green")
    end

    it "returns 'yellow' for score 50–69" do
      listing.score = 55
      expect(listing.score_color).to eq("yellow")
    end

    it "returns 'red' for score < 50" do
      listing.score = 30
      expect(listing.score_color).to eq("red")
    end

    it "returns 'gray' for nil score" do
      listing.score = nil
      expect(listing.score_color).to eq("gray")
    end
  end

  describe "#top_pros" do
    it "returns the first 2 pros" do
      listing.ai_pros = ["Pro 1", "Pro 2", "Pro 3"]
      expect(listing.top_pros).to eq(["Pro 1", "Pro 2"])
    end

    it "returns an empty array when ai_pros is nil" do
      listing.ai_pros = nil
      expect(listing.top_pros).to eq([])
    end
  end

  describe "#needs_review?" do
    it "returns true when both score and rent are nil" do
      listing.score = nil
      listing.rent  = nil
      expect(listing.needs_review?).to be true
    end

    it "returns false when rent is present" do
      listing.score = nil
      listing.rent  = 2000
      expect(listing.needs_review?).to be false
    end
  end
end
