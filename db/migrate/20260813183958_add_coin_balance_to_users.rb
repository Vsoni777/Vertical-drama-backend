class AddCoinBalanceToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :coin_balance, :integer, null: false, default: 0
  end
end
