#!/usr/bin/env ruby
# frozen_string_literal: true

# Эксперимент для тестирования VkTrendAnalyzer
# Запуск: ruby experiments/test_vk_analyzer.rb

require_relative '../app/services/vk_client'
require_relative '../app/services/vk_trend_analyzer'
require_relative '../app/models/vk_post'

# Мок для ActiveRecord (если Rails не загружен)
unless defined?(ActiveRecord)
  class VkPost
    def self.find_or_initialize_by(**attrs)
      new(attrs)
    end

    def initialize(attrs = {})
      @attrs = attrs
    end

    def assign_attributes(attrs)
      @attrs.merge!(attrs)
    end

    def save!
      puts "Would save: #{@attrs.inspect}"
      self
    end

    def method_missing(name, *args)
      @attrs[name] || @attrs[name.to_s]
    end
  end
end

# Мок для Time.current
class Time
  def self.current
    Time.now
  end
end

puts "=" * 60
puts "VK Trends Analyzer - Тестовый эксперимент"
puts "=" * 60

# Проверка наличия токена
unless ENV['VK_API_TOKEN']
  puts "\n⚠️  ВНИМАНИЕ: VK_API_TOKEN не установлен!"
  puts "Установите переменную окружения или создайте .env файл"
  puts "\nПример:"
  puts "  export VK_API_TOKEN=your_token_here"
  puts "  ruby experiments/test_vk_analyzer.rb"
  exit 1
end

# Тест 1: Проверка VkClient
puts "\n[1] Тест VkClient"
puts "-" * 60

begin
  client = VkClient.new
  puts "✓ VkClient инициализирован"
  puts "  API URL: #{VkClient::VK_API_URL}"
  puts "  API Version: #{ENV['VK_API_VERSION'] || '5.199'}"
rescue => e
  puts "✗ Ошибка: #{e.message}"
  exit 1
end

# Тест 2: Простой поиск
puts "\n[2] Тест поиска (keyword: 'здоровье', последние 7 дней)"
puts "-" * 60

begin
  start_time = Time.current - 7 * 24 * 60 * 60 # 7 дней назад
  end_time = Time.current

  result = client.search_newsfeed(
    keyword: "здоровье",
    start_time: start_time,
    end_time: end_time,
    count: 10
  )

  items_count = result.fetch("items", []).size
  puts "✓ Запрос выполнен успешно"
  puts "  Найдено постов: #{items_count}"
  puts "  Профилей: #{result.fetch('profiles', []).size}"
  puts "  Групп: #{result.fetch('groups', []).size}"

  if items_count > 0
    first_post = result["items"].first
    puts "\n  Пример первого поста:"
    puts "    Owner ID: #{first_post['owner_id']}"
    puts "    Лайки: #{first_post.dig('likes', 'count')}"
    puts "    Репосты: #{first_post.dig('reposts', 'count')}"
    puts "    Текст (первые 100 символов): #{first_post['text']&.[](0, 100)}"
  end
rescue VkClient::VkApiError => e
  puts "✗ Ошибка VK API: #{e.message}"
  puts "  Проверьте права доступа вашего токена"
  exit 1
rescue => e
  puts "✗ Ошибка: #{e.message}"
  puts "  #{e.backtrace.first(3).join("\n  ")}"
  exit 1
end

# Тест 3: VkTrendAnalyzer (без сохранения в БД)
puts "\n[3] Тест VkTrendAnalyzer (keyword: 'спорт', 7 дней)"
puts "-" * 60

begin
  # Создаем мок для модели, если Rails не загружен
  unless defined?(Rails)
    class VkPost
      def slice(*keys)
        result = {}
        keys.each { |k| result[k] = @attrs[k] }
        result
      end
    end
  end

  analyzer = VkTrendAnalyzer.new(keyword: "спорт", days: 7, client: client)

  # Переопределяем метод fetch_and_persist для теста (без БД)
  def analyzer.fetch_and_persist(keyword, start_time, end_time)
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
      likes_count = item.dig("likes", "count").to_i
      reposts_count = item.dig("reposts", "count").to_i
      comments_count = item.dig("comments", "count").to_i
      views_count = item.dig("views", "count").to_i

      {
        post_id: link_id,
        owner_id: oid,
        owner_name: name,
        published_at: Time.at(item["date"]),
        likes: likes_count,
        reposts: reposts_count,
        comments: comments_count,
        views: views_count,
        engagement: likes_count + reposts_count + comments_count,
        text_snippet: (item["text"] || "")[0, 200],
        link: "https://vk.com/wall#{oid}_#{link_id}",
        keyword: keyword
      }
    end.compact
  end

  result = analyzer.call

  puts "✓ Анализ выполнен успешно"
  puts "\n  Статистика:"
  puts "    Всего постов: #{result[:summary][:total_posts]}"
  puts "    Среднее лайков: #{result[:summary][:avg_likes]}"
  puts "    Среднее репостов: #{result[:summary][:avg_reposts]}"
  puts "    Среднее комментариев: #{result[:summary][:avg_comments]}"
  puts "    Среднее просмотров: #{result[:summary][:avg_views]}"

  puts "\n  Топ-3 поста:"
  result[:top10].first(3).each_with_index do |post, i|
    puts "    #{i + 1}. #{post[:owner_name] || post[:owner_id]}"
    puts "       Вовлеченность: #{post[:engagement]} (лайки: #{post[:likes]}, репосты: #{post[:reposts]}, комментарии: #{post[:comments]})"
    puts "       Ссылка: #{post[:link]}"
  end

  puts "\n  Обнаруженные темы: #{result[:topics].join(', ')}" if result[:topics].any?
  puts "\n  Рекомендации:"
  result[:tips].each { |tip| puts "    • #{tip}" }

rescue => e
  puts "✗ Ошибка: #{e.message}"
  puts "  #{e.backtrace.first(5).join("\n  ")}"
  exit 1
end

puts "\n" + "=" * 60
puts "✓ Все тесты пройдены успешно!"
puts "=" * 60
puts "\nДля использования в Rails приложении:"
puts "  1. Установите зависимости: bundle install"
puts "  2. Создайте БД: rails db:create db:migrate"
puts "  3. Запустите сервер: rails server"
puts "  4. Откройте браузер: http://localhost:3000"
