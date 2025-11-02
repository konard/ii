class VkTrendAnalyzer
  def initialize(keyword:, days: 90, client: VkClient.new)
    @keyword = keyword.strip
    @days = [days, 120].min
    @client = client
  end

  def call
    start_time = Time.current - @days.days
    end_time   = Time.current

    data = fetch_and_persist(@keyword, start_time, end_time)

    # If no data found and haven't expanded to 120 days yet, try again with expanded range
    if data.empty? && @days < 120
      @days = 120
      data = fetch_and_persist(@keyword, Time.current - 120.days, end_time)
      expanded = true
    else
      expanded = false
    end

    top10 = data.sort_by { |p| -p[:engagement] }.first(10)

    {
      summary: summarize(data),
      top10: top10,
      topics: extract_topics(top10),
      tips: build_tips(top10),
      expanded: expanded
    }
  end

  private

  def fetch_and_persist(keyword, start_time, end_time)
    res = @client.search_newsfeed(keyword: keyword, start_time: start_time, end_time: end_time)
    items = res.fetch("items", [])
    groups = (res["groups"] || []).index_by { |g| -g["id"] }
    profiles = (res["profiles"] || []).index_by { |p| p["id"] }

    items.map do |item|
      next unless item["post_id"] || item["id"]

      oid = item["owner_id"]
      name = if oid.to_i < 0
        groups.dig(oid, "name")
      else
        p = profiles[oid]
        p ? "#{p['first_name']} #{p['last_name']}".strip : nil
      end

      link_id = item["post_id"] || item["id"]

      record = VkPost.find_or_initialize_by(keyword: keyword, post_id: link_id)

      likes_count = item.dig("likes", "count").to_i
      reposts_count = item.dig("reposts", "count").to_i
      comments_count = item.dig("comments", "count").to_i
      views_count = item.dig("views", "count").to_i
      engagement_value = likes_count + reposts_count + comments_count

      record.assign_attributes(
        owner_id: oid,
        owner_name: name,
        published_at: Time.at(item["date"]),
        likes: likes_count,
        reposts: reposts_count,
        comments: comments_count,
        views: views_count,
        engagement: engagement_value,
        text_snippet: (item["text"] || "")[0, 200],
        link: "https://vk.com/wall#{oid}_#{link_id}"
      )

      record.save!

      {
        post_id: record.post_id,
        owner_id: record.owner_id,
        owner_name: record.owner_name,
        published_at: record.published_at,
        likes: record.likes,
        reposts: record.reposts,
        comments: record.comments,
        views: record.views,
        engagement: record.engagement,
        text_snippet: record.text_snippet,
        link: record.link,
        keyword: keyword
      }
    end.compact
  end

  def summarize(data)
    n = data.size.nonzero? || 1
    {
      total_posts: data.size,
      avg_likes: (data.sum { |x| x[:likes] }.to_f / n).round(1),
      avg_reposts: (data.sum { |x| x[:reposts] }.to_f / n).round(1),
      avg_comments: (data.sum { |x| x[:comments] }.to_f / n).round(1),
      avg_views: (data.sum { |x| x[:views] }.to_f / n).round(1)
    }
  end

  # Simple topic extraction based on common keywords
  def extract_topics(top)
    texts = top.map { |x| x[:text_snippet].to_s.downcase }
    frequent = %w[видео история советы упражнения чек-лист лайфхак боль больница диагноз симптомы лечение профилактика осанка гимнастика]
    frequent.select { |w| texts.any? { |t| t.include?(w) } }
  end

  def build_tips(top)
    tips = []

    # Check if videos are popular
    if top.any? { |x| x[:text_snippet].to_s.downcase.include?("видео") }
      tips << "Встраивай короткое видео (до 60–90 сек.) с понятной демонстрацией."
    else
      tips << "Используй структурированный карусельный пост: проблема → причина → 3 шага решения."
    end

    tips << "Заголовок с болью + обещание результата: \"Шея болит по утрам? 3 упражнения за 5 минут\"."
    tips << "Первый экран/абзац — крючок: цифра, факт или мини-история пациента."
    tips << "CTA в конце: \"Сохраните, чтобы сделать вечером\", \"Задайте вопрос в комментариях\"."
    tips << "Обязательно добавляй иллюстрацию/инфографику до-после."

    tips
  end
end
