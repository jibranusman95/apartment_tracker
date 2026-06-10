class Listing < ApplicationRecord
  STATUSES = %w[active gone].freeze
  INPUT_MODES = %w[link paste].freeze
  LAUNDRY_OPTIONS = %w[in-unit shared none].freeze

  validates :raw_text, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :input_mode, inclusion: { in: INPUT_MODES }, allow_blank: true

  scope :active, -> { where(status: "active") }
  scope :gone, -> { where(status: "gone") }
  scope :by_score, -> { order(score: :desc) }
  scope :under_2k, -> { where("rent <= 2000") }
  scope :two_br, -> { where("bedrooms >= 2") }
  scope :has_parking, -> { where(parking: true) }

  def over_budget?
    rent.present? && rent > 2250
  end

  def budget_label
    return nil unless rent.present?
    if rent <= 2000
      "under_2k"
    elsif rent <= 2250
      "soft_limit"
    else
      "over_budget"
    end
  end

  def gone?
    status == "gone"
  end

  def score_color
    return "gray" if score.nil?
    if score >= 70
      "green"
    elsif score >= 50
      "yellow"
    else
      "red"
    end
  end

  def top_pros
    (ai_pros || []).first(2)
  end

  def needs_review?
    score.nil? && rent.nil?
  end
end
