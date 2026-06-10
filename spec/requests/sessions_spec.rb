require "rails_helper"

RSpec.describe "Sessions", type: :request do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("APP_PIN").and_return("1234")
  end

  describe "GET /session/new" do
    it "shows the PIN entry screen" do
      get new_session_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("PIN")
    end

    it "redirects to root if already authenticated" do
      post session_path, params: { pin: "1234" }
      get new_session_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /session" do
    context "with the correct PIN" do
      it "redirects to the dashboard" do
        post session_path, params: { pin: "1234" }
        expect(response).to redirect_to(root_path)
      end

      it "sets the authenticated session flag" do
        post session_path, params: { pin: "1234" }
        expect(session[:authenticated]).to be true
      end
    end

    context "with an incorrect PIN" do
      it "re-renders the PIN form with an error" do
        post session_path, params: { pin: "9999" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Wrong PIN")
      end

      it "does not set the session" do
        post session_path, params: { pin: "9999" }
        expect(session[:authenticated]).to be_nil
      end
    end

    context "when APP_PIN is not configured" do
      before { allow(ENV).to receive(:[]).with("APP_PIN").and_return("") }

      it "shows a configuration error" do
        post session_path, params: { pin: "1234" }
        expect(response.body).to include("APP_PIN")
      end
    end
  end

  describe "DELETE /session" do
    it "clears the session and redirects to PIN screen" do
      post session_path, params: { pin: "1234" }
      delete session_path
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "authentication guard" do
    it "redirects unauthenticated requests to the PIN screen" do
      get root_path
      expect(response).to redirect_to(new_session_path)
    end

    it "allows access after authentication" do
      post session_path, params: { pin: "1234" }
      get root_path
      expect(response).to have_http_status(:ok)
    end
  end
end
