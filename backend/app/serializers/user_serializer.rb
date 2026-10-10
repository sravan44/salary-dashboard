# JSON shapes for users. Never includes the password digest.
module UserSerializer
  module_function

  def summary(user)
    { id: user.id, email: user.email, roles: user.roles, created_at: user.created_at.iso8601 }
  end

  # What the browser needs about the signed-in user, including what they may do.
  def session(user)
    { id: user.id, email: user.email, roles: user.roles, permissions: user.permissions }
  end
end
