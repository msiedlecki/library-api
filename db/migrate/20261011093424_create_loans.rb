class CreateLoans < ActiveRecord::Migration[8.1]
  def change
    create_table :loans do |t|
      t.references :book,   null: false, foreign_key: { on_delete: :restrict }
      t.references :reader, null: false, foreign_key: { on_delete: :restrict }
      t.datetime :borrowed_at, null: false
      t.date     :due_on,      null: false
      t.datetime :returned_at
      t.datetime :reminder_3d_sent_at
      t.datetime :reminder_due_sent_at
      t.timestamps

      t.check_constraint "returned_at IS NULL OR returned_at >= borrowed_at", name: "loans_returned_after_borrowed"
    end

    add_index :loans, :book_id, unique: true, where: "returned_at IS NULL", name: "index_loans_one_active_per_book"
    add_index :loans, :due_on, where: "returned_at IS NULL", name: "index_loans_active_on_due_on"
  end
end
