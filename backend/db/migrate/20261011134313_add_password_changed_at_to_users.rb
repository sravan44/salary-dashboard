# When the user's own password was last set. NULL = invited, no password chosen yet (the account holds
# a random placeholder nobody knows). Existing accounts already have a real password: backfilled.
class AddPasswordChangedAtToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :password_changed_at, :datetime
    execute "UPDATE users SET password_changed_at = created_at"
  end

  def down
    remove_column :users, :password_changed_at
  end
end
