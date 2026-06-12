FactoryBot.define do
  factory :listing do
    raw_text      { Faker::Lorem.paragraphs(number: 4).join("\n\n") }
    input_mode    { "paste" }
    url           { nil }
    source        { nil }
    rent          { 1950 }
    bedrooms      { 2.0 }
    bathrooms     { 1.0 }
    sqft          { 850 }
    parking       { true }
    parking_details { "included" }
    laundry       { "in-unit" }
    balcony       { true }
    pets_allowed  { true }
    utilities_included { [ "heat", "water" ] }
    neighbourhood { Faker::Address.community }
    city          { "Oakville" }
    available_date { "2026-08-01" }
    amenities     { [ "dishwasher", "gym" ] }
    red_flags     { [] }
    ai_pros       { [ "Spacious layout", "Prime location", "Parking included" ] }
    ai_cons       { [ "Older building" ] }
    ai_summary    { "A solid 2BR in a great neighbourhood. Well within budget with parking included." }
    drive_minutes { 25 }
    distance_km   { nil }
    score         { 80 }
    score_breakdown { { "price" => 30, "bedrooms" => 20, "sqft" => 10, "parking" => 10, "drive_time" => 7, "laundry" => 5, "amenities" => 5, "flags" => [] } }
    notes         { nil }
    status        { "active" }

    trait :gone do
      status { "gone" }
    end

    trait :over_budget do
      rent { 2600 }
      score { 20 }
      score_breakdown { { "price" => 0, "bedrooms" => 20, "sqft" => 5, "parking" => 10, "drive_time" => 7, "laundry" => 5, "amenities" => 3, "flags" => [ "OVER HARD LIMIT" ] } }
    end

    trait :no_parking do
      parking { false }
      parking_details { nil }
      score { 55 }
      score_breakdown { { "price" => 30, "bedrooms" => 20, "sqft" => 5, "parking" => 0, "drive_time" => 7, "laundry" => 5, "amenities" => 3, "flags" => [ "MISSING MUST-HAVE: No parking" ] } }
    end

    trait :too_far do
      city          { "Kitchener" }
      drive_minutes { 65 }
      distance_km   { 95.0 }
      score { 60 }
      score_breakdown { { "price" => 30, "bedrooms" => 20, "sqft" => 10, "parking" => 10, "drive_time" => 0, "laundry" => 5, "amenities" => 5, "flags" => [ "TOO FAR: 65 min drive" ] } }
    end

    trait :one_br_den do
      bedrooms { 1.6 }
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
