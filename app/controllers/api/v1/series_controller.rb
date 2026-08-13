class Api::V1::SeriesController < Api::BaseController
  before_action :set_series, only: %i[show update destroy]

  def index
    series = Series
      .order(created_at: :desc)
      .page(params[:page])
      .per(20)

    render json: {
      data: series,
      meta: {
        current_page: series.current_page,
        total_pages: series.total_pages,
        total_count: series.total_count
      }
    }
  end

  def show
    render json: @series
  end

  def create
    series = Series.new(series_params)

    if series.save
      render json: series, status: :created
    else
      render json: { errors: series.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  def update
    if @series.update(series_params)
      render json: @series
    else
      render json: { errors: @series.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  def destroy
    @series.destroy
    head :no_content
  end

  private

  def set_series
    @series = Series.find(params[:id])
  end

  def series_params
    params.require(:series)
          .permit(
            :title,
            :description,
            :cover_image,
            :banner_image,
            :genre,
            :is_published
          )
  end
end