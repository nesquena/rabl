class CreateRablTestTables < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string  :username
      t.string  :email
      t.string  :location
      t.boolean :is_admin
      t.timestamps
    end

    create_table :posts do |t|
      t.integer :user_id
      t.string  :title
      t.text    :body
      t.timestamps
    end

    create_table :phone_numbers do |t|
      t.integer :user_id
      t.boolean :is_primary
      t.string  :area_code
      t.string  :prefix
      t.string  :suffix
      t.string  :name
    end
  end
end
