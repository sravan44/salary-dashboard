# Append-only audit trail: one row per create/update of an employee or salary record.
class CreateVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :versions do |t|
      t.string :item_type, null: false
      t.bigint :item_id, null: false
      t.string :event, null: false
      t.jsonb :object_changes, null: false, default: {} # { "field" => [old, new] }
      t.string :whodunnit                               # actor label (user reference from M7)
      t.datetime :created_at, null: false               # no updated_at: rows are never changed
    end

    add_index :versions, [ :item_type, :item_id, :id ]
    add_check_constraint :versions, "event IN ('create', 'update')", name: "versions_event_known"
  end
end
