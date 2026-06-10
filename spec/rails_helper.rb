require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "webmock/rspec"
WebMock.disable_net_connect!(allow_localhost: true)
require "capybara/rails"

Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join("spec/fixtures") ]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.include SessionHelpers, type: :request
  config.include SessionHelpers, type: :system

  # Capybara / system spec driver
  # Requires Google Chrome for :js examples. Rack::Test is the fallback for non-JS specs.
  CHROME_AVAILABLE = system("which google-chrome chromium-browser chromium > /dev/null 2>&1")

  config.before(:each, type: :system) do |example|
    if example.metadata[:js]
      if CHROME_AVAILABLE || ENV["CI"]
        driven_by :selenium, using: :headless_chrome,
                             screen_size: [ 390, 844 ],
                             options: { args: %w[--headless --no-sandbox --disable-gpu] }
      else
        skip "Skipped: requires Chrome (not installed). Run with Chrome to execute JS system specs."
      end
    else
      driven_by :rack_test
    end
  end
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
