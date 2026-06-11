require "net/http"
require "json"

class DistanceService
  BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"
  MODELS   = %w[gemini-2.5-flash gemini-3.1-flash-lite gemini-2.5-flash-lite].freeze
  WORKPLACE = "603 Michigan Drive, Oakville, ON"

  Result = Struct.new(:distance_km, :drive_minutes, keyword_init: true)

  def self.compute_for(listing)
    new.compute_for(listing)
  end

  def compute_for(listing)
    address = [ listing.neighbourhood, listing.city, "ON, Canada" ].compact.join(", ")
    return nil if address.blank?

    api_key = ENV["GEMINI_API_KEY"]
    return nil if api_key.blank?

    prompt = <<~PROMPT.strip
      Estimate the driving distance in km and driving time in minutes from "#{address}" to "#{WORKPLACE}".
      Return JSON only with two fields: distance_km (decimal) and drive_minutes (integer).
      Use typical road routes in the Greater Toronto Area. If the address is too vague to estimate, return null for both fields.
    PROMPT

    response = nil
    MODELS.each do |model|
      r = call_api(api_key, prompt, model)
      next if [ 429, 503, 500 ].include?(r.code.to_i)
      response = r
      break
    end
    return nil unless response&.is_a?(Net::HTTPSuccess)

    parsed = JSON.parse(response.body)
    raw = parsed.dig("candidates", 0, "content", "parts", 0, "text").to_s
    json_text = raw.gsub(/\A```(?:json)?\n?/, "").gsub(/\n?```\z/, "").strip
    data = JSON.parse(json_text)

    return nil if data["distance_km"].nil? && data["drive_minutes"].nil?

    Result.new(
      distance_km:   data["distance_km"]&.to_f&.round(1),
      drive_minutes: data["drive_minutes"]&.to_i
    )
  rescue StandardError
    nil
  end

  private

  def call_api(api_key, prompt, model)
    uri = URI("#{BASE_URL}/#{model}:generateContent?key=#{api_key}")

    payload = {
      contents: [ { role: "user", parts: [ { text: prompt } ] } ],
      generationConfig: { temperature: 0.1, responseMimeType: "application/json" }
    }

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 15
    http.open_timeout = 10

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = payload.to_json

    http.request(request)
  end
end
