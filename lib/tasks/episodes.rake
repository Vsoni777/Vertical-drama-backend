namespace :episodes do
  desc "Release scheduled episodes (set locked=false where published_at <= now)"
  task release_scheduled: :environment do
    Rake::Task['environment'].invoke
    ReleaseScheduledEpisodesJob.perform_now
    puts "Released scheduled episodes"
  end
end
