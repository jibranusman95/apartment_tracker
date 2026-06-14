require "net/http"
require "json"

class DistanceService
  NOMINATIM_URL    = "https://nominatim.openstreetmap.org/search"
  ORS_URL          = "https://api.openrouteservice.org/v2/directions/driving-car/json"
  # 603 Michigan Drive, Oakville, ON — pre-geocoded, no need to hit Nominatim every time
  WORKPLACE_COORDS = [ -79.738156, 43.3876959 ].freeze

  Result = Struct.new(:distance_km, :drive_minutes, keyword_init: true)

  def self.compute_for(listing)
    new.compute_for(listing)
  end

  def compute_for(listing)
    api_key = ENV["OPENROUTESERVICE_API_KEY"]
    return nil if api_key.blank?

    origin = geocode_with_fallback(listing)
    return nil unless origin

    summary = fetch_route(api_key, origin, WORKPLACE_COORDS)
    return nil unless summary

    Result.new(
      distance_km:   (summary["distance"].to_f / 1000).round(1),
      drive_minutes: (summary["duration"].to_f / 60).round
    )
  rescue StandardError
    nil
  end

  private

  def geocode_with_fallback(listing)
    # 1. Full street address (cleaned)
    if listing.street_address.present?
      origin = geocode(resolve_address(listing))
      return origin if origin

      # 2. Postal code only (good area-level accuracy)
      postal = listing.street_address.match(/[A-Z]\d[A-Z]\s*\d[A-Z]\d/)&.to_s
      if postal
        origin = geocode("#{postal}, #{listing.city}, ON, Canada")
        return origin if origin
      end
    end

    # 3. Neighbourhood + city
    if listing.neighbourhood.present?
      origin = geocode("#{listing.neighbourhood}, #{listing.city}, ON, Canada")
      return origin if origin
    end

    # 4. City only
    geocode("#{listing.city}, ON, Canada")
  end

  def resolve_address(listing)
    if listing.street_address.present?
      cleaned = listing.street_address
        .gsub(/,?\s*(Unit|Apt\.?|Suite|#)\s*[\w-]+/i, "")  # strip unit/apt/# numbers
        .gsub(/,?\s*[A-Z]\d[A-Z]\s*\d[A-Z]\d/, "")         # strip Canadian postal codes
        .gsub(/,?\s*Canada\s*$/i, "")                        # strip trailing "Canada"
        .gsub(/,?\s*ON\s*$/i, "")                            # strip trailing "ON"
        .strip.gsub(/,\s*$/, "")

      # If city is already in the cleaned address, don't append it again
      if cleaned.match?(/\b#{Regexp.escape(listing.city.to_s)}\b/i)
        "#{cleaned}, ON, Canada"
      else
        "#{cleaned}, #{listing.city}, ON, Canada"
      end
    else
      [ listing.neighbourhood, listing.city, "ON, Canada" ].compact.join(", ")
    end
  end

  # Returns [lon, lat] — ORS expects longitude first
  def geocode(address)
    uri = URI(NOMINATIM_URL)
    uri.query = URI.encode_www_form(q: address, format: "json", limit: 1, countrycodes: "ca")

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "ApartmentTracker/1.0"

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 10) do |http|
      http.request(request)
    end

    return nil unless response.is_a?(Net::HTTPSuccess)

    results = JSON.parse(response.body)
    return nil if results.empty?

    [ results[0]["lon"].to_f, results[0]["lat"].to_f ]
  rescue StandardError
    nil
  end

  def fetch_route(api_key, origin, destination)
    uri = URI(ORS_URL)

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = api_key
    request["Content-Type"]  = "application/json"
    request.body = { coordinates: [ origin, destination ] }.to_json

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 15) do |http|
      http.request(request)
    end

    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).dig("routes", 0, "summary")
  rescue StandardError
    nil
  end
end
