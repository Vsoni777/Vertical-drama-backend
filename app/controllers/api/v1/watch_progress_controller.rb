class Api::V1::WatchProgressController < Api::BaseController
  # GET /api/v1/watch_progress — continue-watching list
  def index
    progresses = current_user.watch_progresses
                             .includes(:episode, :series)
                             .where(completed: false)
                             .order(updated_at: :desc)
                             .limit(20)

    render json: {
      data: progresses.map do |wp|
        {
          series_id:        wp.series_id,
          series_title:     wp.series.title,
          episode_id:       wp.episode_id,
          episode_number:   wp.episode.episode_number,
          episode_title:    wp.episode.title,
          progress_seconds: wp.progress_seconds,
          updated_at:       wp.updated_at
        }
      end
    }
  end

  # PATCH /api/v1/watch_progress
  def update
    episode = Episode.find(params[:episode_id])
    series  = episode.series

    progress = current_user.watch_progresses.find_or_initialize_by(
      episode: episode,
      series:  series
    )

    progress.update!(
      progress_seconds: params[:progress_seconds].to_i,
      completed:        params[:completed] == true || params[:completed] == "true"
    )

    render json: { data: { episode_id: episode.id, progress_seconds: progress.progress_seconds, completed: progress.completed } }
  end
end
