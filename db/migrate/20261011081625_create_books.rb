class CreateBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :books do |t|
      t.string   :serial_number, null: false
      t.string   :title, null: false
      t.string   :author, null: false
      t.datetime :discarded_at
      t.timestamps

      t.check_constraint "serial_number ~ '^[0-9]{6}$'", name: "books_serial_number_format"
      t.check_constraint "length(trim(title)) > 0",      name: "books_title_not_blank"
      t.check_constraint "length(trim(author)) > 0",     name: "books_author_not_blank"
    end

    add_index :books, :serial_number, unique: true
  end
end
