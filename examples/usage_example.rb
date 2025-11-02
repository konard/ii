#!/usr/bin/env ruby
# frozen_string_literal: true

# Примеры использования VK Trends Analyzer
# Запуск в Rails консоли: rails runner examples/usage_example.rb

puts "=" * 60
puts "VK Trends Analyzer - Примеры использования"
puts "=" * 60

# Пример 1: Базовый анализ
puts "\n[Пример 1] Базовый анализ ключевого слова"
puts "-" * 60

keyword = "фитнес"
puts "Анализируем ключевое слово: '#{keyword}'"

result = VkTrendAnalyzer.new(keyword: keyword, days: 90).call

puts "\nРезультаты:"
puts "  Найдено постов: #{result[:summary][:total_posts]}"
puts "  Топ постов: #{result[:top10].size}"
puts "  Темы: #{result[:topics].join(', ')}"
puts "  Период расширен: #{result[:expanded] ? 'Да' : 'Нет'}"

# Пример 2: Работа с базой данных
puts "\n\n[Пример 2] Поиск сохраненных постов в БД"
puts "-" * 60

posts = VkPost.by_keyword(keyword).recent.by_engagement.limit(5)
puts "Найдено постов в БД: #{posts.count}"

posts.each_with_index do |post, i|
  puts "\n#{i + 1}. #{post.owner_name || post.owner_id}"
  puts "   Вовлеченность: #{post.engagement}"
  puts "   Лайки: #{post.likes}, Репосты: #{post.reposts}, Комментарии: #{post.comments}"
  puts "   Ссылка: #{post.link}"
end

# Пример 3: Фоновая задача
puts "\n\n[Пример 3] Запуск анализа в фоновой задаче"
puts "-" * 60

keywords = ["здоровье", "спорт", "питание"]
puts "Запускаем анализ для ключевых слов: #{keywords.join(', ')}"

keywords.each do |kw|
  FetchVkTrendsJob.perform_later(kw, 90)
  puts "  ✓ Задача для '#{kw}' добавлена в очередь"
end

puts "\nЗадачи будут выполнены фоново через Solid Queue"
puts "Проверить статус: rails solid_queue:status"

# Пример 4: Сравнение нескольких ключевых слов
puts "\n\n[Пример 4] Сравнение эффективности ключевых слов"
puts "-" * 60

comparison_keywords = ["йога", "пилатес", "растяжка"]
results = {}

comparison_keywords.each do |kw|
  data = VkTrendAnalyzer.new(keyword: kw, days: 30).call
  results[kw] = {
    total_posts: data[:summary][:total_posts],
    avg_engagement: data[:top10].map { |p| p[:engagement] }.sum / [data[:top10].size, 1].max
  }
end

puts "\nСравнение (последние 30 дней):"
results.sort_by { |_, v| -v[:avg_engagement] }.each do |kw, stats|
  puts "  #{kw.ljust(15)} - Постов: #{stats[:total_posts].to_s.rjust(4)}, Средняя вовлеченность топ-10: #{stats[:avg_engagement].round(1)}"
end

# Пример 5: Экспорт данных
puts "\n\n[Пример 5] Экспорт топовых постов в CSV"
puts "-" * 60

require 'csv'

keyword_for_export = "медицина"
result = VkTrendAnalyzer.new(keyword: keyword_for_export).call

csv_file = "exports/vk_trends_#{keyword_for_export}_#{Time.now.strftime('%Y%m%d')}.csv"
FileUtils.mkdir_p('exports')

CSV.open(csv_file, 'w') do |csv|
  csv << ['#', 'Автор', 'Дата', 'Лайки', 'Репосты', 'Комментарии', 'Просмотры', 'Вовлеченность', 'Ссылка']

  result[:top10].each_with_index do |post, i|
    csv << [
      i + 1,
      post[:owner_name] || post[:owner_id],
      post[:published_at]&.strftime('%d.%m.%Y'),
      post[:likes],
      post[:reposts],
      post[:comments],
      post[:views],
      post[:engagement],
      post[:link]
    ]
  end
end

puts "✓ Данные экспортированы в: #{csv_file}"

puts "\n" + "=" * 60
puts "Примеры выполнены!"
puts "=" * 60
