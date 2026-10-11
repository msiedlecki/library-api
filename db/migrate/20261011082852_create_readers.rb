class CreateReaders < ActiveRecord::Migration[8.1]
  def change
    create_table :readers do |t|
      t.string :card_number, null: false
      t.string :full_name, null: false
      t.string :email, null: false
      t.timestamps

      t.check_constraint "card_number ~ '^[0-9]{6}$'", name: "readers_card_number_format"
    end

    add_index :readers, :card_number, unique: true
    add_index :readers, :email, unique: true
    add_index :readers, "LOWER(email)", unique: true, name: "index_readers_on_lower_email"
  end
end
