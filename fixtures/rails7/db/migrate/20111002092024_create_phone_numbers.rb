class CreatePhoneNumbers < ActiveRecord::Migration[6.0]
  def change
    create_table :phone_numbers do |t|
      t.integer :user_id
      t.boolean :is_primary
      t.string :area_code
      t.string :prefix
      t.string :suffix
      t.string :name
    end
  end
end
