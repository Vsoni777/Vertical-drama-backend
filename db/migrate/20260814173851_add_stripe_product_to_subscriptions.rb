class AddStripeProductToSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :subscriptions, :stripe_price_id, :string
  end
end
