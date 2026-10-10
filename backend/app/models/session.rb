# A signed-in browser. The cookie holds a random token; only its SHA-256 digest is stored.
class Session < ApplicationRecord
  TTL = 12.hours

  belongs_to :user

  # Returns the session and the plain token (to put in the cookie; never stored).
  def self.start(user, ip_address: nil, user_agent: nil)
    token = SecureRandom.urlsafe_base64(32)
    session = create!(user:, token_digest: digest(token), expires_at: TTL.from_now,
                      ip_address:, user_agent: user_agent&.truncate(255))
    [ session, token ]
  end

  def self.find_active(token)
    return nil if token.blank?

    includes(:user).where("expires_at > ?", Time.current).find_by(token_digest: digest(token))
  end

  def self.digest(token) = Digest::SHA256.hexdigest(token)
end
