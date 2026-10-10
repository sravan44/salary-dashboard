# People who can sign in. Roles combine (a user may hold several); access is their union.
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :roles, array: true, null: false, default: []
      t.timestamps
    end
    add_index :users, :email, unique: true
    # The database itself refuses a user with no role or an unknown role.
    add_check_constraint :users, "cardinality(roles) > 0 AND roles <@ ARRAY['viewer', 'hr_manager', 'admin']::varchar[]",
                         name: "users_roles_valid"
  end
end
