# Every request needs a signed-in user (401 otherwise); `require_permission` narrows by role (403).
# The session token travels in an HttpOnly, SameSite=Lax cookie, so scripts cannot read it and
# other sites cannot send it with their POSTs. Mutations are JSON-only, which a plain HTML form
# on another site cannot produce without a CORS preflight that this app never allows.
module Authentication
  extend ActiveSupport::Concern

  COOKIE = :session_token

  included do
    before_action :require_json_body, if: -> { request.post? || request.patch? || request.put? }
    before_action :require_sign_in
  end

  class_methods do
    def allow_signed_out(**options) = skip_before_action(:require_sign_in, **options)

    def require_permission(permission, **options)
      before_action(-> { forbid unless Current.user.can?(permission) }, **options)
    end
  end

  private

  def require_sign_in
    session = Session.find_active(cookies[COOKIE])
    return render_error(:unauthorized, "unauthenticated", "Please sign in") unless session

    Current.session = session
    Current.user = session.user
    Current.actor = session.user.email
  end

  def require_json_body
    return if request.media_type == "application/json"

    render_error(:unsupported_media_type, "json_required", "Send the request body as application/json")
  end

  def forbid = render_error(:forbidden, "forbidden", "Your role does not allow this")

  def start_session(user)
    _session, token = Session.start(user, ip_address: request.remote_ip, user_agent: request.user_agent)
    cookies[COOKIE] = { value: token, httponly: true, same_site: :lax, secure: request.ssl? }
  end

  def end_session
    Current.session.destroy
    cookies.delete(COOKIE)
  end
end
