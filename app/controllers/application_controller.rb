class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :require_pin

  private

  def require_pin
    return if session[:authenticated]
    return if controller_name == "sessions"

    redirect_to new_session_path
  end
end
