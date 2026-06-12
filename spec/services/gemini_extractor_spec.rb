require "rails_helper"

RSpec.describe GeminiExtractor, type: :service do
  let(:sample_text) do
    "Beautiful 2BR/1BA in Downtown Toronto. $1,950/mo, parking included, in-unit laundry,
     balcony, dishwasher. 850 sqft. Available Aug 1. No pets. Heat/water included."
  end

  let(:gemini_url) { "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" }

  let(:valid_json_response) do
    {
      "candidates" => [ {
        "content" => {
          "parts" => [ {
            "text" => {
              rent_monthly: 1950, bedrooms: 2, bathrooms: 1.0, sqft: 850,
              parking: true, parking_details: "included",
              laundry: "in-unit", balcony: true, pets_allowed: false,
              utilities_included: [ "heat", "water" ],
              neighbourhood: "Downtown", city: "Toronto",
              available_date: "2026-08-01",
              amenities: [ "dishwasher", "balcony" ],
              red_flags: [],
              pros: [ "Parking included", "In-unit laundry", "Great location" ],
              cons: [ "No pets" ],
              summary: "Solid 2BR under budget with parking and laundry included. Good value for Downtown Toronto."
            }.to_json
          } ]
        }
      } ]
    }.to_json
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return("test-api-key")
  end

  describe ".extract" do
    context "with a successful API response" do
      before do
        stub_request(:post, /generativelanguage\.googleapis\.com/)
          .to_return(status: 200, body: valid_json_response, headers: { "Content-Type" => "application/json" })
      end

      it "returns a successful result" do
        result = GeminiExtractor.extract(sample_text)
        expect(result.success).to be true
      end

      it "parses all expected fields" do
        result = GeminiExtractor.extract(sample_text)
        expect(result.data["rent_monthly"]).to eq(1950)
        expect(result.data["bedrooms"]).to eq(2)
        expect(result.data["parking"]).to be true
        expect(result.data["laundry"]).to eq("in-unit")
        expect(result.data["city"]).to eq("Toronto")
      end

      it "parses array fields correctly" do
        result = GeminiExtractor.extract(sample_text)
        expect(result.data["pros"]).to be_an(Array)
        expect(result.data["pros"].length).to eq(3)
        expect(result.data["utilities_included"]).to include("heat", "water")
      end
    end

    context "when the API returns malformed JSON" do
      before do
        malformed = { "candidates" => [ { "content" => { "parts" => [ { "text" => "not json at all" } ] } } ] }.to_json
        stub_request(:post, /generativelanguage\.googleapis\.com/)
          .to_return(status: 200, body: malformed, headers: { "Content-Type" => "application/json" })
      end

      it "returns a failed result with a user-friendly error" do
        result = GeminiExtractor.extract(sample_text)
        expect(result.success).to be false
        expect(result.error).to match(/malformed JSON|manually/i)
      end
    end

    context "when the API returns markdown-wrapped JSON" do
      before do
        json_payload = { rent_monthly: 1950, bedrooms: 2, bathrooms: 1.0, sqft: 850,
                         parking: true, parking_details: "included", laundry: "in-unit",
                         balcony: true, pets_allowed: false, utilities_included: [],
                         neighbourhood: "Downtown", city: "Toronto", available_date: "2026-08-01",
                         amenities: [], red_flags: [], pros: [ "a", "b", "c" ], cons: [], summary: "Good unit." }
        markdown_wrapped = "```json\n#{json_payload.to_json}\n```"
        wrapped_response = { "candidates" => [ { "content" => { "parts" => [ { "text" => markdown_wrapped } ] } } ] }.to_json

        stub_request(:post, /generativelanguage\.googleapis\.com/)
          .to_return(status: 200, body: wrapped_response, headers: { "Content-Type" => "application/json" })
      end

      it "strips markdown fences and parses successfully" do
        result = GeminiExtractor.extract(sample_text)
        expect(result.success).to be true
        expect(result.data["rent_monthly"]).to eq(1950)
      end
    end

    context "when all models are rate limited" do
      before do
        stub_request(:post, /generativelanguage\.googleapis\.com/)
          .to_return(status: 429, body: "Rate limited")
      end

      it "returns a failed result with a daily limit message" do
        result = GeminiExtractor.extract(sample_text)
        expect(result.success).to be false
        expect(result.error).to match(/limit|tomorrow|manually/i)
      end
    end

    context "when GEMINI_API_KEY is not set" do
      it "returns a failed result with a message about the missing key" do
        extractor = GeminiExtractor.new
        allow(extractor).to receive(:api_key!).and_return(nil)
        result = extractor.extract_with_prompts(GeminiExtractor::SYSTEM_PROMPT, sample_text)
        expect(result.success).to be false
        expect(result.error).to match(/GEMINI_API_KEY/i)
      end
    end
  end
end
