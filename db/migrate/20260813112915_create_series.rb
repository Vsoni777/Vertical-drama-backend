class CreateSeries < ActiveRecord::Migration[8.1]
  def change
    create_table :series do |t|
      t.string :title
      t.text :description
      t.string :cover_image
      t.integer :status
      t.datetime :release_date

      t.timestamps
    end
  end
end
