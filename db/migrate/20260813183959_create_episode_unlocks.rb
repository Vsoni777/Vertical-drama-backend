class CreateEpisodeUnlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :episode_unlocks do |t|
      t.references :user,    null: false, foreign_key: true, index: true
      t.references :episode, null: false, foreign_key: true, index: true

      t.timestamps
    end

    add_index :episode_unlocks, [ :user_id, :episode_id ], unique: true
  end
end
