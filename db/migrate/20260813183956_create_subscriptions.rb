class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string  :plan,   null: false, default: "monthly"
      t.integer :status, null: false, default: 0
      t.datetime :started_at
      t.datetime :ends_at
      t.string :stripe_subscription_id

      t.timestamps
    end

    add_index :subscriptions, :status
    add_index :subscriptions, [ :user_id, :status ]
  end
end
