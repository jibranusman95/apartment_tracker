class SessionsController < ApplicationController
  skip_before_action :require_pin

  def new
    redirect_to root_path if session[:authenticated]
  end

  def create
    entered = params[:pin].to_s.strip
    correct = ENV["APP_PIN"].to_s.strip

    if correct.blank?
      flash.now[:error] = "APP_PIN is not configured — ask your admin."
      render :new, status: :unprocessable_entity
      return
    end

    if ActiveSupport::SecurityUtils.secure_compare(entered, correct)
      session[:authenticated] = true
      session[:authenticated_at] = Time.current.to_i
      redirect_to root_path, notice: "Welcome back!"
    else
      flash.now[:error] = "Wrong PIN. Try again."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to new_session_path, notice: "Signed out."
  end
end
