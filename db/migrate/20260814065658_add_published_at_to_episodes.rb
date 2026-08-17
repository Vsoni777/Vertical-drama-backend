class AddPublishedAtToEpisodes < ActiveRecord::Migration[8.1]
  def change
    add_column :episodes, :published_at, :string
  end
end
