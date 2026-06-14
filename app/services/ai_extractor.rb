# Top-level orchestrator. Tries GeminiExtractor first, then OpenAI-compatible
# providers (Groq, OpenRouter) as fallbacks. All providers share the same prompts.
class AIExtractor
  SYSTEM_PROMPT = <<~PROMPT.strip
    You are a helpful assistant that extracts structured information from apartment rental listing descriptions.
    Return a JSON object only, no markdown, no preamble, no explanation. If a field is not mentioned, return null.
  PROMPT

  USER_PROMPT_TEMPLATE = <<~PROMPT.strip
    Extract the following fields from this rental listing and return as JSON:
    - rent_monthly (integer)
    - bedrooms (decimal: use 1.0 for 1 bedroom, 2.0 for 2 bedrooms, etc. For a bedroom + den, use a value between X.5 and X.7 where X is the bedroom count — use X.5 as the baseline and increase toward X.7 if the den is described as spacious, has a window, closet, or other amenities that make it more usable as a room)
    - bathrooms (decimal)
    - sqft (integer or null)
    - parking (boolean)
    - parking_details (string: e.g. 'included', 'extra $150/mo', 'street only')
    - laundry (string: 'in-unit', 'shared', 'none', or null)
    - balcony (boolean)
    - pets_allowed (boolean)
    - utilities_included (array of strings, e.g. ['heat', 'water'])
    - street_address (string or null: full street address if explicitly stated in the listing, e.g. "123 Main St". Do not infer or guess — only extract if present)
    - neighbourhood (string)
    - city (string)
    - available_date (string)
    - amenities (array of notable features)
    - red_flags (array of any concerns or missing info)
    - pros (array of exactly 3 top selling points, written as short punchy phrases)
    - cons (array of up to 3 drawbacks, written as short punchy phrases)
    - summary (2 sentences max: honest take on this listing given the criteria of max budget $2250, parking required, preferring 2 bedrooms, bigger is better)

    Listing text: %{text}
  PROMPT

  Result = Struct.new(:success, :data, :error, keyword_init: true)

  def self.extract(text)
    new.extract(text)
  end

  def extract(text)
    user_prompt = USER_PROMPT_TEMPLATE % { text: text.truncate(12_000) }

    # 1. Try Gemini (handles its own model fallback chain internally)
    result = GeminiExtractor.extract_with_prompts(SYSTEM_PROMPT, user_prompt)
    return result if result.success

    # 2. Try OpenAI-compatible providers (Groq, OpenRouter)
    result = OpenaiCompatibleExtractor.extract(SYSTEM_PROMPT, user_prompt)
    return result if result.success

    Result.new(
      success: false,
      error: "Daily AI limit reached across all providers — try again later or fill in the fields manually."
    )
  end
end
