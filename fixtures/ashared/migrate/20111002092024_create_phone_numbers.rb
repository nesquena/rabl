class CreatePhoneNumbers < ActiveRecord::Migration
  def self.up
    create_table :phone_numbers do |t|
      t.integer :user_id
      t.boolean :is_primary
      t.string :area_code
      t.string :prefix
      t.string :suffix
      t.string :name
    end
  end

  def self.down
    drop_table :phone_numbers
  end
end
