require "rails_helper"

RSpec.describe ListingFetcher, type: :service do
  let(:valid_url) { "https://www.kijiji.ca/listing/12345" }

  let(:listing_html) do
    <<~HTML
      <html>
        <head><title>2BR Apartment Downtown Toronto</title></head>
        <body>
          <nav>Navigation</nav>
          <main>
            <h1>Beautiful 2 Bedroom Apartment</h1>
            <p>Spacious 900 sqft unit available August 1st. $2100/mo includes parking and heat.
               In-unit laundry, balcony with city views. No pets. Downtown Toronto, steps to subway.</p>
            <p>Contact landlord at example@email.com</p>
          </main>
          <footer>Footer content</footer>
          <script>alert('js')</script>
        </body>
      </html>
    HTML
  end

  describe ".fetch" do
    context "when the URL is reachable and returns good content" do
      before do
        stub_request(:get, valid_url)
          .to_return(status: 200, body: listing_html, headers: { "Content-Type" => "text/html" })
      end

      it "returns a successful result" do
        result = ListingFetcher.fetch(valid_url)
        expect(result.success).to be true
      end

      it "extracts text from the main element" do
        result = ListingFetcher.fetch(valid_url)
        expect(result.text).to include("2 Bedroom Apartment")
        expect(result.text).to include("900 sqft")
      end

      it "strips out script tags" do
        result = ListingFetcher.fetch(valid_url)
        expect(result.text).not_to include("alert")
      end

      it "strips out nav and footer content" do
        result = ListingFetcher.fetch(valid_url)
        expect(result.text).not_to include("Navigation")
        expect(result.text).not_to include("Footer content")
      end
    end

    context "when the server returns a non-200 status" do
      before do
        stub_request(:get, valid_url).to_return(status: 404, body: "Not Found")
      end

      it "returns a failed result with an error message" do
        result = ListingFetcher.fetch(valid_url)
        expect(result.success).to be false
        expect(result.error).to match(/HTTP 404/)
      end
    end

    context "when the URL times out" do
      before do
        stub_request(:get, valid_url).to_timeout
      end

      it "returns a failed result" do
        result = ListingFetcher.fetch(valid_url)
        expect(result.success).to be false
        expect(result.error).to be_present
      end
    end

    context "when the page appears to be behind a login wall" do
      before do
        stub_request(:get, valid_url)
          .to_return(status: 200, body: "<html><body><p>Please sign in.</p></body></html>")
      end

      it "returns a failed result indicating a login wall" do
        result = ListingFetcher.fetch(valid_url)
        expect(result.success).to be false
        expect(result.error).to match(/login|content/i)
      end
    end

    context "when the URL has a connection error" do
      before do
        stub_request(:get, valid_url).to_raise(SocketError.new("getaddrinfo: Name or service not known"))
      end

      it "returns a failed result with a user-friendly message" do
        result = ListingFetcher.fetch(valid_url)
        expect(result.success).to be false
        expect(result.error).not_to match(/getaddrinfo/)
      end
    end
  end
end
