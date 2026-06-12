class ListingsController < ApplicationController
  before_action :set_listing, only: %i[show edit update destroy toggle_status toggle_favorite]

  CITY_FILTERS = %w[Oakville Burlington Mississauga Milton Hamilton].freeze

  def index
    @listings = Listing.by_score

    case params[:filter]
    when "under_2k"        then @listings = @listings.under_2k
    when "two_br"          then @listings = @listings.two_br
    when "one_br"          then @listings = @listings.one_br
    when "has_parking"     then @listings = @listings.has_parking
    when "in_suite"        then @listings = @listings.in_suite_laundry
    when "favorited"       then @listings = @listings.favorited
    when "ideal"           then @listings = @listings.ideal
    when *CITY_FILTERS     then @listings = @listings.where("city ILIKE ?", params[:filter])
    end

    @listings = @listings.active unless params[:filter] == "all"

    @active_cities = CITY_FILTERS.select do |city|
      Listing.active.where("city ILIKE ?", city).exists?
    end

    @first_listing = @listings.first
  end

  def show
    if @listing.distance_km.nil? && @listing.drive_minutes.nil?
      result = DistanceService.compute_for(@listing)
      if result
        @listing.update_columns(distance_km: result.distance_km, drive_minutes: result.drive_minutes)
      end
    end
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
      redirect_to listing_path(@listing, back: params[:back]), notice: "Saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @listing.destroy
    redirect_to root_path, notice: "Listing deleted."
  end

  def toggle_status
    new_status = @listing.gone? ? "active" : "gone"
    @listing.update!(status: new_status)
    notice = new_status == "gone" ? "Marked as gone." : "Marked as available again."
    redirect_to listing_path(@listing), notice: notice
  end

  def toggle_favorite
    @listing.toggle_favorite!
    label = @listing.favorited? ? "Added to favourites." : "Removed from favourites."
    redirect_back fallback_location: root_path, notice: label
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
