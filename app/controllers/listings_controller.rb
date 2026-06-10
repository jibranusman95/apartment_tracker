class ListingsController < ApplicationController
  before_action :set_listing, only: %i[show edit update destroy toggle_status]

  def index
    @listings = Listing.by_score

    @listings = @listings.under_2k    if params[:filter] == "under_2k"
    @listings = @listings.two_br      if params[:filter] == "two_br"
    @listings = @listings.has_parking if params[:filter] == "has_parking"
    @listings = @listings.active      unless params[:filter] == "all"
  end

  def show
  end

  def new
    @listing = Listing.new
  end

  def create
    result = ListingCreator.create(listing_create_params)

    if result.respond_to?(:fallback_to_paste) && result.fallback_to_paste
      flash.now[:warning] = "#{result.error} — paste the listing description below instead."
      @listing = Listing.new
      @fallback_to_paste = true
      render :new, status: :unprocessable_entity
      return
    end

    if result.success
      redirect_to listing_path(result.listing), notice: "Listing added!"
    else
      flash.now[:error] = result.error
      @listing = Listing.new
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @listing.update(listing_update_params)
      respond_to do |format|
        format.html { redirect_to listing_path(@listing), notice: "Saved." }
        format.turbo_stream
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @listing.destroy
    redirect_to listings_path, notice: "Listing deleted."
  end

  def toggle_status
    new_status = @listing.gone? ? "active" : "gone"
    @listing.update!(status: new_status)

    respond_to do |format|
      format.html  { redirect_to listing_path(@listing) }
      format.turbo_stream
    end
  end

  # PATCH /listings/:id/update_notes — inline auto-save
  def update_notes
    @listing = Listing.find(params[:id])
    @listing.update(notes: params[:notes])
    head :ok
  end

  # GET /listings/resolve_source?url=... — returns source name for a URL
  def resolve_source
    source = ListingCreator.source_from_url(params[:url])
    render json: { source: source }
  end

  private

  def set_listing
    @listing = Listing.find(params[:id])
  end

  def listing_create_params
    params.require(:listing).permit(
      :url, :raw_text, :input_mode, :source,
      :rent, :bedrooms, :bathrooms, :sqft,
      :parking, :parking_details, :laundry,
      :balcony, :pets_allowed,
      :neighbourhood, :city, :available_date,
      :ai_summary, :notes, :status
    )
  end

  def listing_update_params
    params.require(:listing).permit(
      :url, :source,
      :rent, :bedrooms, :bathrooms, :sqft,
      :parking, :parking_details, :laundry,
      :balcony, :pets_allowed,
      :neighbourhood, :city, :available_date,
      :ai_summary, :notes, :status
    )
  end
end
