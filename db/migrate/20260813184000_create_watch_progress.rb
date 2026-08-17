class CreateWatchProgress < ActiveRecord::Migration[8.1]
  def change
    create_table :watch_progresses do |t|
      t.references :user,    null: false, foreign_key: true, index: true
      t.references :episode, null: false, foreign_key: true, index: true
      t.references :series,  null: false, foreign_key: true, index: true
      t.integer :progress_seconds, null: false, default: 0
      t.boolean :completed,        null: false, default: false

      t.timestamps
    end

    add_index :watch_progresses, [ :user_id, :episode_id ], unique: true
    add_index :watch_progresses, [ :user_id, :series_id ]
  end
end
