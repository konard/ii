require "faraday"
require "faraday/retry"

class VkClient
  VK_API_URL = "https://api.vk.com/method".freeze

  class VkApiError < StandardError; end

  def initialize(token: ENV.fetch("VK_API_TOKEN"), version: ENV.fetch("VK_API_VERSION", "5.199"))
    @token = token
    @version = version
    @conn = Faraday.new(VK_API_URL) do |f|
      f.request :retry, max: 3, interval: 0.2, backoff_factor: 2
      f.response :json
      f.adapter Faraday.default_adapter
    end
  end

  def search_newsfeed(keyword:, start_time:, end_time:, count: 200)
    resp = @conn.get("newsfeed.search", {
      q: keyword,
      count: count,
      extended: 1,
      start_time: start_time.to_i,
      end_time: end_time.to_i,
      access_token: @token,
      v: @version
    })

    body = resp.body
    raise VkApiError, body.dig("error", "error_msg") || "Unknown VK API error" if body["error"]

    body["response"] || {}
  end
end
