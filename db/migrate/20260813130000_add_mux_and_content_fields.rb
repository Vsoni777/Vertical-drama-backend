class AddMuxAndContentFields < ActiveRecord::Migration[8.1]
  def change
    add_column :series, :banner_image, :string
    add_column :series, :genre, :string
    add_column :series, :is_published, :boolean, default: false, null: false

    add_column :episodes, :coin_cost, :integer, default: 0, null: false
    add_column :episodes, :mux_upload_id, :string
    add_column :episodes, :mux_asset_id, :string
    add_column :episodes, :mux_playback_id, :string
    change_column_default :episodes, :video_status, from: nil, to: 0
    change_column_null :episodes, :video_status, false, 0
    change_column_default :episodes, :locked, from: nil, to: false
    change_column_null :episodes, :locked, false, false
    add_index :episodes, :mux_upload_id, unique: true
    add_index :episodes, :mux_asset_id, unique: true
    add_index :episodes, :mux_playback_id, unique: true
    add_index :episodes, %i[series_id episode_number], unique: true
  end
end
