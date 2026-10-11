# Lets a request reach the demo email inbox only when the inbox is on and the session cookie belongs to an
# Admin. The inbox shows set-password and reset links; an Admin can already set anyone's password, so this
# gives them nothing new. The cookie is SameSite=Lax, so another site can't use it to clear the inbox.
module EmailInboxConstraint
  def self.matches?(request)
    return false unless Rails.configuration.x.email_inbox

    session = Session.find_active(request.cookie_jar[Authentication::COOKIE])
    session.present? && session.user.can?(:manage_users)
  end
end
