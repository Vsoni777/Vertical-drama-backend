class Api::V1::EpisodesController < Api::BaseController
  before_action :set_series
  before_action :set_episode, only: %i[
    show
    update
    destroy
  ]

  def index
    render json: @series.episodes
                        .order(:episode_number)
  end

  def show
    render json: @episode
  end

  def create
    episode = @series.episodes.new(
      episode_params
    )

    if episode.save
      render json: episode,
             status: :created
    else
      render json: {
        errors: episode.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def update
    if @episode.update(episode_params)
      render json: @episode
    else
      render json: {
        errors: @episode.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def destroy
    @episode.destroy
    head :no_content
  end

  private

  def set_series
    @series = Series.find(
      params[:series_id]
    )
  end

  def set_episode
    @episode = @series.episodes.find( params[:series_id])
  end

  def episode_params
    params.require(:episode)
          .permit(
            :title,
            :description,
            :episode_number,
            :duration,
            :is_free,
            :coin_cost
          )
  end
end