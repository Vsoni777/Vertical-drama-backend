class CreateCoinTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :coin_transactions do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.integer :amount,           null: false
      t.integer :transaction_type, null: false, default: 0
      t.string  :description

      t.timestamps
    end
  end
end
