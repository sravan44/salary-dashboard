# Server-side sign-in sessions. The browser holds a random token in an HttpOnly cookie; only its
# SHA-256 digest is stored, so a database leak does not hand out live sessions.
class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end
    add_index :sessions, :token_digest, unique: true
  end
end
