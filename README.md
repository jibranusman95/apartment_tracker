# 🏠 Home Finder

> A private, mobile-first apartment hunting tracker for two people — paste a listing link or description, let AI extract and score it, then compare everything side by side.

Built with **Rails 8 · PostgreSQL · Gemini 2.5 Flash · Tailwind CSS · Hotwire**

---

## What it does

You and your partner share a single PIN. Add listings by pasting a URL or copying the description text — the app fetches the page, strips the noise, sends it to Gemini, and returns a fully structured card scored out of 100 against your criteria (max $2,250/mo, parking required, prefer 2BR, bigger is better).

Every listing gets:

- **AI extraction** — rent, bedrooms, bathrooms, sqft, parking, laundry, balcony, pets, utilities, neighbourhood, amenities, red flags, pros, cons, and a 2-sentence honest summary
- **Source detection** — the site it came from (Kijiji, PadMapper, Facebook Marketplace, etc.) auto-detected from the URL
- **Weighted score** — 100-point scale with colour-coded badges and a per-category breakdown
- **Shared notes** — a free-text field that auto-saves as you type, visible to both of you
- **Gone toggle** — grey out listings that are no longer available without deleting them

---

## Screenshots

| Dashboard | Detail view | Add listing |
|---|---|---|
| Score badges, filter pills, pros tags | Full breakdown + AI summary | Link or paste mode |

---

## Scoring

| Category | Points | Criteria |
|---|---|---|
| 💰 Price | 30 | ≤ $2,000 = 30 · $2,001–$2,150 = 23 · $2,151–$2,250 = 16 · > $2,250 = 0 ⚠️ |
| 🛏 Bedrooms | 20 | 2 BR / 2 BR+Den = 20 · 1 BR+Den = 16 · 1 BR = 10 · Studio = 0 |
| 📐 Sq. Ft. | 20 | Scaled relative to all listings in the database · null = 10 |
| 🚗 Parking | 10 | Included = 10 · Extra cost = 5 · None = 0 ⚠️ |
| 🚘 Drive time | 10 | < 20 min = 10 · 20–42 min = 4–9 · > 42 min = 0 ⚠️ |
| 🧺 Laundry | 5 | In-unit = 5 · Shared/none = 0 |
| ✨ Amenities | 5 | +2 dishwasher · +2 gym/pool · +1 any other · max 5 |

Bedrooms are stored as decimals — 1 BR + Den is scored as 1.5–1.7, 2 BR + Den as 2.5–2.7 (higher toward X.7 if the den is spacious or has a window/closet).

Score badges are **green ≥ 70 · yellow 50–69 · red < 50**. Listings over $2,250, without parking, or more than 42 min from work are flagged directly on the card.

---

## Tech stack

| | |
|---|---|
| **Runtime** | Ruby 3.3 · Rails 8.1 |
| **Database** | PostgreSQL (JSONB for arrays) |
| **AI** | Google Gemini 2.5 Flash — direct HTTP, no SDK |
| **HTML scraping** | HTTParty + Nokogiri |
| **Frontend** | Hotwire/Turbo · Tailwind CSS v4 · Stimulus |
| **Auth** | Shared 4-digit PIN · 7-day session cookie |
| **Tests** | RSpec · FactoryBot · WebMock · Capybara |
| **Deploy** | Render |

---

## Getting started

### Prerequisites

- Ruby 3.3+
- PostgreSQL
- A [Google Gemini API key](https://aistudio.google.com/app/apikey) (free tier works)

### Setup

```bash
git clone <repo-url>
cd apartment_tracker

bundle install

cp .env.example .env
# Edit .env — set APP_PIN and GEMINI_API_KEY

bin/rails db:create db:migrate

bin/dev        # starts Puma + Tailwind watcher
```

Open `http://localhost:3000` and enter your PIN.

### Environment variables

| Variable | Description |
|---|---|
| `APP_PIN` | 4-digit PIN shared between both users (e.g. `1234`) |
| `GEMINI_API_KEY` | Your Google Gemini API key |
| `DATABASE_URL` | Set automatically by Heroku/Railway — override locally if needed |

---

## Adding a listing

**Mode 1 — Link:** Paste any rental URL. The app fetches the page server-side, strips navigation and scripts, and sends the cleaned text to Gemini. If the page is behind a login wall or the fetch fails, it falls back gracefully to Mode 2 with a friendly message.

**Mode 2 — Paste:** Copy and paste the listing description directly. The original URL can still be saved for reference.

Both modes run through the same AI extraction and scoring pipeline.

### Which sites work with a URL?

| Site | URL auto-fetch | Notes |
|---|---|---|
| Kijiji | ✅ Works | Most reliable |
| Rentals.ca | ✅ Works | |
| PadMapper | ✅ Works | |
| Zumper | ✅ Works | |
| Liv.rent | ✅ Works | |
| ViewIt | ✅ Works | |
| GottaRent | ✅ Works | |
| Jumbo | ✅ Works | |
| Craigslist | ✅ Works | |
| Realtor.ca | ⚠️ Usually works | Some listings require login |
| Apartments.com | ⚠️ Usually works | |
| Zillow / HotPads | ⚠️ Hit or miss | May block scrapers |
| Facebook Marketplace | ❌ Copy-paste only | Requires Facebook login |

When a URL fetch fails the app tells you clearly and drops you straight into paste mode — just copy the listing text and continue.

---

## Source detection

The app automatically identifies which site a listing came from based on the URL domain and displays it as a badge on every card and detail view. This works regardless of whether you used URL mode or paste mode.

Recognised sites: **Kijiji · Rentals.ca · PadMapper · Zumper · Facebook Marketplace · Realtor.ca · Liv.rent · ViewIt · GottaRent · Jumbo · Apartments.com · Zillow · HotPads · Craigslist**

Unknown domains are capitalised and shown as-is. You can always edit the source field manually.

---

## Running tests

```bash
# All tests
APP_PIN=1234 GEMINI_API_KEY=test bundle exec rspec

# By layer
bundle exec rspec spec/models
bundle exec rspec spec/services
bundle exec rspec spec/requests
bundle exec rspec spec/system      # requires Chrome for JS specs
```

**152 examples · 0 failures** (2 system specs pending Chrome for JS interactions)

| Suite | Examples | What's covered |
|---|---|---|
| Models | 28 | Validations, scopes, all helper methods |
| Services | 59 | Every scoring branch, HTTP stubs, JSON parsing, source detection |
| Requests | 38 | Full CRUD, PIN auth, all filters, notes auto-save, resolve_source |
| System | 27 | Full browser flows via Capybara (rack_test + headless Chrome) |

HTTP calls to Gemini and external listing URLs are fully stubbed via WebMock — no real network calls in the test suite.

---

## Deploying to Heroku

```bash
heroku create your-app-name
heroku addons:create heroku-postgresql:essential-0

heroku config:set APP_PIN=your_pin
heroku config:set GEMINI_API_KEY=your_gemini_key
heroku config:set RAILS_MASTER_KEY=$(cat config/master.key)

git push heroku main
```

`bin/release` runs `db:migrate` automatically on every deploy.

---

## Project structure

```
app/
  controllers/
    sessions_controller.rb     # PIN auth
    listings_controller.rb     # CRUD + toggle + notes + resolve_source
  models/
    listing.rb                 # Validations, scopes, helpers
  services/
    listing_fetcher.rb         # HTTParty + Nokogiri scraper
    gemini_extractor.rb        # Gemini 2.5 Flash API client
    listing_scorer.rb          # 100-point weighted scoring
    listing_creator.rb         # Orchestrator + source_from_url
  views/
    sessions/new               # PIN screen
    listings/index             # Dashboard with filter pills
    listings/show              # Detail view + notes + score breakdown
    listings/new               # Add listing (link or paste)
    listings/edit              # Manual field editing
spec/
  models/                      # Model unit tests
  services/                    # Service unit tests (all HTTP stubbed)
  requests/                    # Controller integration tests
  system/                      # End-to-end Capybara tests
```

---

## License

Private — personal use only.
