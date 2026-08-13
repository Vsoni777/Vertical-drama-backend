class CreateEpisodes < ActiveRecord::Migration[8.1]
  def change
    create_table :episodes do |t|
      t.references :series, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.integer :episode_number
      t.string :thumbnail
      t.integer :duration
      t.integer :video_status
      t.boolean :locked

      t.timestamps
    end
  end
end
