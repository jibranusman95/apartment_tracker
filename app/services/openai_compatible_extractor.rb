require "net/http"
require "json"

# Handles any provider that speaks the OpenAI chat completions API format.
# Used for Groq and OpenRouter.
class OpenaiCompatibleExtractor
  RATE_LIMIT_CODES = [ 429, 503, 500 ].freeze

  Provider = Struct.new(:name, :api_url, :api_key_env, :models, keyword_init: true)

  PROVIDERS = [
    Provider.new(
      name:        "Groq",
      api_url:     "https://api.groq.com/openai/v1/chat/completions",
      api_key_env: "GROQ_API_KEY",
      models:      %w[llama-3.3-70b-versatile meta-llama/llama-4-scout-17b-16e-instruct llama-3.1-8b-instant]
    ),
    Provider.new(
      name:        "OpenRouter",
      api_url:     "https://openrouter.ai/api/v1/chat/completions",
      api_key_env: "OPENROUTER_API_KEY",
      models:      %w[nvidia/nemotron-3-ultra-550b-a55b:free nex-agi/nex-n2-pro:free google/gemma-4-26b-a4b-it:free nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free]
    )
  ].freeze

  Result = Struct.new(:success, :data, :error, keyword_init: true)

  def self.extract(system_prompt, user_prompt)
    new.extract(system_prompt, user_prompt)
  end

  def extract(system_prompt, user_prompt)
    PROVIDERS.each do |provider|
      api_key = ENV[provider.api_key_env]
      next if api_key.blank?

      provider.models.each do |model|
        response = call_api(provider.api_url, api_key, model, system_prompt, user_prompt)
        next if RATE_LIMIT_CODES.include?(response.code.to_i)
        next unless response.is_a?(Net::HTTPSuccess)

        raw = JSON.parse(response.body).dig("choices", 0, "message", "content").to_s
        next if raw.blank?

        json_text = raw.gsub(/\A```(?:json)?\n?/, "").gsub(/\n?```\z/, "").strip
        data = JSON.parse(json_text)
        return Result.new(success: true, data: data)
      rescue JSON::ParserError
        next
      end
    end

    Result.new(success: false, error: "openai_providers_exhausted")
  rescue StandardError => e
    Result.new(success: false, error: "openai_providers_exhausted")
  end

  private

  def call_api(api_url, api_key, model, system_prompt, user_prompt)
    uri = URI(api_url)
    payload = {
      model: model,
      messages: [
        { role: "system", content: system_prompt },
        { role: "user",   content: user_prompt }
      ],
      temperature: 0.1,
      response_format: { type: "json_object" }
    }

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30
    http.open_timeout = 10

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"]  = "application/json"
    request["Authorization"] = "Bearer #{api_key}"
    request.body = payload.to_json

    http.request(request)
  end
end
