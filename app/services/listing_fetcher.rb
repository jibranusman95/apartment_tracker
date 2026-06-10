require "httparty"
require "nokogiri"

class ListingFetcher
  TIMEOUT = 10
  MAX_CONTENT_LENGTH = 15_000
  LOGIN_WALL_PATTERNS = [
    /sign.?in/i, /log.?in/i, /create.?account/i, /register/i,
    /please.+log.?in/i, /access.+denied/i, /401/i, /403/i,
    /captcha/i
  ].freeze

  Result = Struct.new(:success, :text, :error, keyword_init: true)

  def self.fetch(url)
    new(url).fetch
  end

  def initialize(url)
    @url = url
  end

  def fetch
    response = HTTParty.get(
      @url,
      timeout: TIMEOUT,
      follow_redirects: true,
      headers: {
        "User-Agent" => "Mozilla/5.0 (compatible; ApartmentTracker/1.0)",
        "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language" => "en-US,en;q=0.5"
      }
    )

    unless response.success?
      return Result.new(success: false, error: "Could not fetch the page (HTTP #{response.code})")
    end

    body = response.body.to_s
    text = extract_text(body)

    if text.length < 100
      return Result.new(success: false, error: "Page returned too little content — it may require a login")
    end

    if login_wall?(text)
      return Result.new(success: false, error: "This page appears to require a login to view")
    end

    Result.new(success: true, text: text.truncate(MAX_CONTENT_LENGTH))
  rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
    Result.new(success: false, error: "Could not reach that URL: #{e.class.name.demodulize}")
  rescue StandardError => e
    Result.new(success: false, error: "Something went wrong fetching that link")
  end

  private

  def extract_text(html)
    doc = Nokogiri::HTML(html)

    # Remove noise elements
    %w[script style nav footer header aside .nav .navbar .footer .header
       .sidebar .advertisement .ad .cookie-banner noscript].each do |selector|
      doc.css(selector).remove
    end

    # Try to find main content in priority order
    content_node = doc.at_css("main, article, [role='main'], .listing-detail,
      .listing-content, .property-detail, #listing, #content, .content")

    target = content_node || doc.at_css("body") || doc

    # Extract and clean text
    text = target.text
    text.gsub!(/\t+/, " ")
    text.gsub!(/[ ]{2,}/, " ")
    text.gsub!(/\n{3,}/, "\n\n")
    text.strip
  end

  def login_wall?(text)
    sample = text.first(500).downcase
    LOGIN_WALL_PATTERNS.any? { |pat| pat.match?(sample) } &&
      text.length < 300
  end
end
