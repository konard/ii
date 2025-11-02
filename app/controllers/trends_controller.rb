class TrendsController < ApplicationController
  def new
    # Render the search form
  end

  def create
    keyword = params.require(:keyword)
    days = (params[:days].presence || 90).to_i

    result = VkTrendAnalyzer.new(keyword: keyword, days: days).call

    @keyword = keyword
    @summary = result[:summary]
    @top10 = result[:top10]
    @expanded = result[:expanded]
    @topics = result[:topics]
    @tips = result[:tips]

    render :show
  rescue ActionController::ParameterMissing => e
    flash.now[:alert] = "Пожалуйста, введите ключевое слово для поиска"
    render :new, status: :unprocessable_entity
  rescue VkClient::VkApiError => e
    flash.now[:alert] = "Ошибка VK API: #{e.message}"
    render :new, status: :unprocessable_entity
  rescue => e
    flash.now[:alert] = "Произошла ошибка: #{e.message}"
    render :new, status: :unprocessable_entity
  end
end
