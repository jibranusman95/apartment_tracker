FactoryBot.define do
  factory :listing do
    raw_text      { Faker::Lorem.paragraphs(number: 4).join("\n\n") }
    input_mode    { "paste" }
    url           { nil }
    source        { nil }
    rent          { 1950 }
    bedrooms      { 2 }
    bathrooms     { 1.0 }
    sqft          { 850 }
    parking       { true }
    parking_details { "included" }
    laundry       { "in-unit" }
    balcony       { true }
    pets_allowed  { true }
    utilities_included { [ "heat", "water" ] }
    neighbourhood { Faker::Address.community }
    city          { "Toronto" }
    available_date { "2026-08-01" }
    amenities     { [ "dishwasher", "gym" ] }
    red_flags     { [] }
    ai_pros       { [ "Spacious layout", "Prime location", "Parking included" ] }
    ai_cons       { [ "No pets policy", "Older building" ] }
    ai_summary    { "A solid 2BR in a great neighbourhood. Well within budget with parking included." }
    score         { 87 }
    score_breakdown { { "price" => 40, "parking" => 25, "bedrooms" => 15, "sqft" => 7, "balcony" => 5, "amenities" => 5, "flags" => [] } }
    notes         { nil }
    status        { "active" }

    trait :gone do
      status { "gone" }
    end

    trait :over_budget do
      rent { 2600 }
      score { 35 }
      score_breakdown { { "price" => 0, "parking" => 25, "bedrooms" => 15, "sqft" => 5, "balcony" => 0, "amenities" => 0, "flags" => [ "OVER HARD LIMIT" ] } }
    end

    trait :no_parking do
      parking { false }
      parking_details { nil }
      score { 50 }
      score_breakdown { { "price" => 25, "parking" => 0, "bedrooms" => 15, "sqft" => 5, "balcony" => 5, "amenities" => 0, "flags" => [ "MISSING MUST-HAVE: No parking" ] } }
    end

    trait :studio do
      bedrooms { 0 }
      bathrooms { 1.0 }
    end

    trait :with_url do
      url    { "https://www.kijiji.ca/v-apartments-condos/toronto/2br-downtown/12345" }
      source { "Kijiji" }
      input_mode { "link" }
    end

    trait :unscored do
      score { nil }
      score_breakdown { nil }
    end
  end
end
