module SessionHelpers
  # Sign in with the app PIN for request specs
  def sign_in_with_pin(pin = ENV.fetch("APP_PIN", "1234"))
    post session_path, params: { pin: pin }
  end

  # Sign in via the browser for system specs
  def browser_sign_in(pin = "1234")
    visit new_session_path
    fill_in "pin", with: pin
    click_button "Unlock"
  end
end
