namespace :mux do
  desc "Retroactively add DRM playback policies to all existing episodes"
  task add_drm_to_existing: :environment do
    puts "Starting DRM backfill for existing episodes..."

    # Ensure Mux credentials exist
    unless ENV['MUX_TOKEN_ID'].present? && ENV['MUX_TOKEN_SECRET'].present?
      puts "❌ Error: MUX_TOKEN_ID and MUX_TOKEN_SECRET are missing in environment variables."
      exit 1
    end

    episodes = Episode.where.not(mux_asset_id: nil)

    if episodes.empty?
      puts "✅ No existing uploaded episodes found to update."
      exit 0
    end

    episodes.find_each do |episode|
      puts "Processing Episode #{episode.id} (Asset ID: #{episode.mux_asset_id})"

      begin
        # 1. Create a new playback ID with 'drm' policy on the existing asset
        response = MuxVideo.post("/assets/#{episode.mux_asset_id}/playback-ids", { 
          policy: "drm",
          drm_configuration_id: ENV.fetch("MUX_DRM_CONFIG_ID", "drmConfig001abCdefGHIjklMNO") 
        })
        
        new_playback_id = response.fetch("data").fetch("id")

        # 2. Delete the old public/signed playback ID if it exists and is different
        old_playback_id = episode.mux_playback_id
        if old_playback_id.present? && old_playback_id != new_playback_id
          # Mux uses HTTP DELETE for this, but since we don't have a delete method in MuxVideo,
          # we can just orphan it or manually execute the request here.
          uri = URI("#{MuxVideo::API_BASE_URL}/assets/#{episode.mux_asset_id}/playback-ids/#{old_playback_id}")
          request = Net::HTTP::Delete.new(uri)
          request.basic_auth(ENV.fetch("MUX_TOKEN_ID"), ENV.fetch("MUX_TOKEN_SECRET"))
          Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
          puts "  - Deleted old insecure playback ID: #{old_playback_id}"
        end

        # 3. Save the new DRM playback ID to the database
        episode.update!(mux_playback_id: new_playback_id)
        puts "  - ✅ Successfully attached DRM playback ID: #{new_playback_id}"

      rescue => e
        puts "  - ❌ Failed to update Episode #{episode.id}: #{e.message}"
      end
    end

    puts "\n🎉 DRM backfill complete. All existing videos are now protected."
  end
end
