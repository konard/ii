class VkPost < ApplicationRecord
  validates :keyword, presence: true
  validates :post_id, uniqueness: { scope: :keyword }

  scope :by_keyword, ->(kw) { where(keyword: kw) }
  scope :recent, -> { where("published_at >= ?", 90.days.ago) }
  scope :by_engagement, -> { order(engagement: :desc) }
end
