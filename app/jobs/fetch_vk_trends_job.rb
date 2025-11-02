class FetchVkTrendsJob < ApplicationJob
  queue_as :default

  def perform(keyword, days = 90)
    VkTrendAnalyzer.new(keyword: keyword, days: days).call
  end
end
