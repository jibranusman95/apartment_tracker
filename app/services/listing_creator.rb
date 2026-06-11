class ListingCreator
  Result = Struct.new(:success, :listing, :error, :fallback_to_paste, keyword_init: true)

  # Friendly names for well-known rental sites
  SOURCE_NAMES = {
    "kijiji.ca"          => "Kijiji",
    "kijiji.com"         => "Kijiji",
    "craigslist.org"     => "Craigslist",
    "facebook.com"       => "Facebook Marketplace",
    "fb.com"             => "Facebook Marketplace",
    "rentals.ca"         => "Rentals.ca",
    "padmapper.com"      => "PadMapper",
    "zumper.com"         => "Zumper",
    "apartments.com"     => "Apartments.com",
    "realtor.ca"         => "Realtor.ca",
    "realtor.com"        => "Realtor.com",
    "zillow.com"         => "Zillow",
    "hotpads.com"        => "HotPads",
    "viewit.ca"          => "ViewIt",
    "gottarent.com"      => "GottaRent",
    "liv.rent"           => "Liv.rent",
    "jumbo.ca"           => "Jumbo",
    "marketplace.facebook.com" => "Facebook Marketplace"
  }.freeze

  def self.create(params)
    new(params).create
  end

  def initialize(params)
    @url         = params[:url].presence
    @pasted_text = params[:raw_text].presence
    @source      = params[:source].presence
    @input_mode  = params[:input_mode] || (@url ? "link" : "paste")
  end

  def create
    raw_text, input_mode, fallback = resolve_text
    return raw_text if raw_text.is_a?(Result)

    extraction = GeminiExtractor.extract(raw_text)

    listing = Listing.new(
      url:        @url,
      raw_text:   raw_text,
      input_mode: input_mode,
      source:     resolve_source,
      status:     "active"
    )

    if extraction.success
      apply_extraction(listing, extraction.data)
      result = ListingScorer.score(listing)
      listing.score           = result[:score]
      listing.score_breakdown = result[:breakdown].merge(flags: result[:flags])
    else
      listing.ai_summary = "AI extraction failed — please fill in fields manually."
    end

    if listing.save
      reschedule_sqft_scores if extraction.success && listing.sqft.present?
      Result.new(success: true, listing: listing)
    else
      Result.new(success: false, error: listing.errors.full_messages.to_sentence)
    end
  end

  # Public so it can be called from the form to pre-populate source
  def self.source_from_url(url)
    return nil if url.blank?
    uri = URI.parse(url.strip)
    host = uri.host.to_s.sub(/\Awww\./, "")
    SOURCE_NAMES[host] || host.split(".").first(2).join(".").capitalize
  rescue URI::InvalidURIError
    nil
  end

  private

  def resolve_text
    if @input_mode == "link" && @url.present?
      fetch_result = ListingFetcher.fetch(@url)
      unless fetch_result.success
        return Result.new(
          success: false,
          error: fetch_result.error,
          fallback_to_paste: true
        )
      end
      [ fetch_result.text, "link", false ]
    elsif @pasted_text.present?
      [ @pasted_text, "paste", false ]
    else
      [ Result.new(success: false, error: "Please provide a URL or paste the listing text"), nil, false ]
    end
  end

  def resolve_source
    return @source if @source.present?
    self.class.source_from_url(@url)
  end

  def apply_extraction(listing, data)
    listing.rent               = data["rent_monthly"]
    listing.bedrooms           = data["bedrooms"]
    listing.bathrooms          = data["bathrooms"]
    listing.sqft               = data["sqft"]
    listing.parking            = data["parking"]
    listing.parking_details    = data["parking_details"]
    listing.laundry            = data["laundry"]
    listing.balcony            = data["balcony"]
    listing.pets_allowed       = data["pets_allowed"]
    listing.utilities_included = Array(data["utilities_included"])
    listing.neighbourhood      = data["neighbourhood"]
    listing.city               = data["city"]
    listing.available_date     = data["available_date"]
    listing.amenities          = Array(data["amenities"])
    listing.red_flags          = Array(data["red_flags"])
    listing.ai_pros            = Array(data["pros"])
    listing.ai_cons            = Array(data["cons"])
    listing.ai_summary         = data["summary"]
    listing.distance_km        = data["distance_km"]
    listing.drive_minutes      = data["drive_minutes"]
  end

  def reschedule_sqft_scores
    Listing.where.not(sqft: nil).find_each do |l|
      result = ListingScorer.score(l)
      l.update_columns(
        score: result[:score],
        score_breakdown: result[:breakdown].merge(flags: result[:flags])
      )
    end
  end
end
