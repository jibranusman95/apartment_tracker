require "net/http"
require "json"

class GeminiExtractor
  BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"
  MODELS   = %w[gemini-2.5-flash gemini-3.1-flash-lite gemini-2.5-flash-lite].freeze

  SYSTEM_PROMPT = <<~PROMPT.strip
    You are a helpful assistant that extracts structured information from apartment rental listing descriptions.
    Return a JSON object only, no markdown, no preamble, no explanation. If a field is not mentioned, return null.
  PROMPT

  USER_PROMPT_TEMPLATE = <<~PROMPT.strip
    Extract the following fields from this rental listing and return as JSON:
    - rent_monthly (integer)
    - bedrooms (integer)
    - bathrooms (decimal)
    - sqft (integer or null)
    - parking (boolean)
    - parking_details (string: e.g. 'included', 'extra $150/mo', 'street only')
    - laundry (string: 'in-unit', 'shared', 'none', or null)
    - balcony (boolean)
    - pets_allowed (boolean)
    - utilities_included (array of strings, e.g. ['heat', 'water'])
    - neighbourhood (string)
    - city (string)
    - available_date (string)
    - amenities (array of notable features)
    - red_flags (array of any concerns or missing info)
    - pros (array of exactly 3 top selling points, written as short punchy phrases)
    - cons (array of up to 3 drawbacks, written as short punchy phrases)
    - summary (2 sentences max: honest take on this listing given the criteria of max budget $2250, parking required, preferring 2 bedrooms, bigger is better)
    - distance_km (decimal or null: estimated driving distance in km from the listing address to 603 Michigan Drive, Oakville, ON. Use your knowledge of the area. If address is too vague, return null)
    - drive_minutes (integer or null: estimated driving time in minutes from the listing address to 603 Michigan Drive, Oakville, ON under normal traffic conditions)

    Listing text: %{text}
  PROMPT

  Result = Struct.new(:success, :data, :error, keyword_init: true)

  def self.extract(text)
    new.extract_with_prompts(SYSTEM_PROMPT, USER_PROMPT_TEMPLATE % { text: text.truncate(12_000) })
  end

  def self.extract_with_prompts(system_prompt, user_prompt)
    new.extract_with_prompts(system_prompt, user_prompt)
  end

  def extract_with_prompts(system_prompt, user_prompt)
    api_key = api_key!
    return Result.new(success: false, error: "GEMINI_API_KEY is not configured") if api_key.blank?

    last_error = nil

    MODELS.each do |model|
      response = call_api(api_key, system_prompt, user_prompt, model)
      code = response.code.to_i

      # Rate limited or overloaded — try next model
      if [ 429, 503, 500 ].include?(code)
        last_error = "rate_limited"
        next
      end

      unless response.is_a?(Net::HTTPSuccess)
        last_error = "Gemini API error (#{code}): #{response.body.truncate(200)}"
        next
      end

      parsed = JSON.parse(response.body)
      raw_content = parsed.dig("candidates", 0, "content", "parts", 0, "text")
      next if raw_content.blank?

      json_text = raw_content.gsub(/\A```(?:json)?\n?/, "").gsub(/\n?```\z/, "").strip
      data = JSON.parse(json_text)
      return Result.new(success: true, data: data)
    end

    error_msg = last_error == "rate_limited" \
      ? "Daily AI limit reached — try again tomorrow, or fill in the fields manually." \
      : (last_error || "Gemini returned an empty response")
    Result.new(success: false, error: error_msg)
  rescue JSON::ParserError
    Result.new(success: false, error: "Gemini returned malformed JSON — you can fill in fields manually")
  rescue StandardError => e
    Result.new(success: false, error: "AI extraction failed: #{e.message.truncate(150)}")
  end

  private

  def api_key!
    ENV["GEMINI_API_KEY"]
  end

  def call_api(api_key, system_prompt, user_prompt, model)
    uri = URI("#{BASE_URL}/#{model}:generateContent?key=#{api_key}")

    payload = {
      systemInstruction: {
        parts: [ { text: system_prompt } ]
      },
      contents: [
        {
          role: "user",
          parts: [ { text: user_prompt } ]
        }
      ],
      generationConfig: {
        temperature: 0.1,
        responseMimeType: "application/json"
      }
    }

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30
    http.open_timeout = 10

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = payload.to_json

    http.request(request)
  end
end
