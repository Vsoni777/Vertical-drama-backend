class Api::V1::SeriesController < Api::BaseController
  before_action :set_series, only: %i[show update destroy]
  before_action :require_admin!, only: %i[create update destroy]

  def index
    series = Series.order(created_at: :desc).page(params[:page]).per(20)
    render json: {
      data: series.map { |s| series_json(s) },
      meta: {
        current_page: series.current_page,
        total_pages:  series.total_pages,
        total_count:  series.total_count
      }
    }
  end

  def show
    render json: { data: series_json(@series) }
  end

  def create
    series = Series.new(series_params)
    series.thumbnail_image.attach(params[:series][:thumbnail_image]) if params.dig(:series, :thumbnail_image).present?

    if series.save
      render json: { data: series_json(series) }, status: :created
    else
      render json: { errors: series.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    series_params_data = series_params
    @series.thumbnail_image.attach(params[:series][:thumbnail_image]) if params.dig(:series, :thumbnail_image).present?

    if @series.update(series_params_data)
      render json: { data: series_json(@series) }
    else
      render json: { errors: @series.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @series.destroy
    head :no_content
  end

  private

  def set_series
    @series = Series.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Series not found" }, status: :not_found
  end

  def series_params
    params.require(:series).permit(
      :title, :description, :cover_image,
      :banner_image, :genre, :is_published, :thumbnail
    )
  end

  def series_json(s)
    s.as_json(
      only: %i[id title description genre is_published cover_image banner_image created_at updated_at]
    ).merge(
      "thumbnail_url" => s.thumbnail_url,
      "status"        => s.is_published ? "Published" : "Draft",
      "episode_count" => s.episodes.count
    )
  end
end
