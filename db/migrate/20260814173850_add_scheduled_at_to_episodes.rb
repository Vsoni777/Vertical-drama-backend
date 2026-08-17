class AddScheduledAtToEpisodes < ActiveRecord::Migration[8.1]
  def change
    add_column :episodes, :scheduled_at, :datetime
  end
end
