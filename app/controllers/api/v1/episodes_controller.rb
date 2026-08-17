class Api::V1::EpisodesController < Api::BaseController
  before_action :set_series
  before_action :set_episode, only: %i[show update destroy create_upload playback unlock]
  before_action :normalize_published_at, only: %i[create update]
  before_action :require_admin!, only: %i[create update destroy create_upload]

  def index
    episodes = if current_user.admin?
                 @series.episodes.ordered
               else
                 @series.episodes.where('published_at IS NULL OR published_at <= ?', Time.current).ordered
               end
    unlocked_ids = current_user.episode_unlocks.where(episode: episodes).pluck(:episode_id).to_set
    progress_map = current_user.watch_progresses.where(episode: episodes).index_by(&:episode_id)

    render json: { data: episodes.map { |ep| episode_json(ep, unlocked_ids, progress_map) } }
  end

  def show
    if !current_user.admin? && @episode.published_at.present? && @episode.published_at > Time.current
      return render json: { error: "Episode not yet published" }, status: :forbidden
    end

    render json: { data: episode_json(@episode) }
  end

  def create
    episode = @series.episodes.new(episode_params)
    if episode.save
      render json: { data: episode_json(episode) }, status: :created
    else
      render json: { errors: episode.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @episode.update(episode_params)
      render json: { data: episode_json(@episode) }
    else
      render json: { errors: @episode.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @episode.destroy
    head :no_content
  end

  def create_upload
    drm_config_id = ENV["MUX_DRM_CONFIG_ID"]
    
    new_asset_settings = {}
    
    if drm_config_id.present?
      new_asset_settings[:advanced_playback_policies] = [{ policy: "drm" }]
      new_asset_settings[:drm_configuration_id] = drm_config_id
    end

    upload = MuxVideo.create_direct_upload!(
      episode_id:  @episode.id,
      cors_origin: request.headers["Origin"],
      new_asset_settings: new_asset_settings
    )
    @episode.update!(mux_upload_id: upload.fetch("id"), video_status: :uploading)
    render json: { data: { upload_id: upload.fetch("id"), upload_url: upload.fetch("url") } }, status: :created
  rescue MuxVideo::Error => e
    Rails.logger.error("[Mux] Direct upload failed: #{e.message}")
    render json: { error: "Unable to create video upload" }, status: :bad_gateway
  end

  def unlock
    return render(json: { error: "Episode is free" },       status: :unprocessable_entity) if @episode.free?
    return render(json: { error: "Already unlocked" },      status: :unprocessable_entity) if current_user.unlocked?(@episode)
    return render(json: { error: "Insufficient coins" },    status: :payment_required)     if current_user.coin_balance < @episode.coin_cost

    ActiveRecord::Base.transaction do
      current_user.coin_transactions.create!(
        amount:           -@episode.coin_cost,
        transaction_type: :unlock,
        description:      "Unlocked: #{@episode.title}"
      )
      current_user.episode_unlocks.create!(episode: @episode)
    end

    render json: { data: { episode_id: @episode.id, coin_balance: current_user.reload.coin_balance } }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def playback
    unless @episode.streamable?
      return render json: {
        error: "Video is not ready yet",
        video_status: @episode.video_status
      }, status: :conflict
    end

    unless current_user.can_watch?(@episode)
      return render json: { error: "Access denied" }, status: :forbidden
    end

    begin
      token = MuxPlaybackToken.generate(@episode.mux_playback_id)
    rescue MuxPlaybackToken::ConfigurationError => e
      Rails.logger.error("[Mux] Token error: #{e.message}")
      return render json: { error: "Playback is temporarily unavailable" }, status: :service_unavailable
    end

    render json: {
      data: {
        playback_id:    @episode.mux_playback_id,
        playback_token: token,
        playback_url:   "https://stream.mux.com/#{@episode.mux_playback_id}.m3u8?token=#{token}"
      }
    }
  end

  private

  def set_series
    @series = Series.find(params[:series_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Series not found" }, status: :not_found
  end

  def set_episode
    @episode = @series.episodes.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Episode not found" }, status: :not_found
  end

  def episode_params
    params.require(:episode).permit(
      :title, :description, :episode_number,
      :duration, :locked, :coin_cost, :thumbnail, :published_at, :scheduled_at
    )
  end

  def normalize_published_at
    return unless params[:episode]

    if params[:episode].key?(:release_at)
      params[:episode][:published_at] = params[:episode].delete(:release_at)
    end

    if params[:episode][:published_at].present?
      # let ActiveRecord parse the datetime string
    else
      params[:episode][:published_at] = nil
    end
  end

  def episode_json(episode, unlocked_ids = Set.new, progress_map = {})
    progress = progress_map[episode.id]
    episode.as_json(
      only: %i[id series_id title description episode_number thumbnail duration locked coin_cost video_status published_at scheduled_at created_at updated_at]
    ).merge(
      "unlocked"         => unlocked_ids.include?(episode.id),
      "progress_seconds" => progress&.progress_seconds || 0,
      "completed"        => progress&.completed        || false,
      "streamable"       => episode.streamable?,
      "published"        => episode.published?
    )
  end
end
