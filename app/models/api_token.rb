# A simple bearer token a user generates in the admin to authenticate API clients
# (e.g. a native macOS app). No OAuth — clients send "Authorization: Bearer <token>".
class ApiToken < ApplicationRecord
  belongs_to :user

  has_secure_token :token

  validates :name, presence: true

  # Look up an active token and stamp its usage. Returns nil for unknown tokens.
  def self.authenticate(token)
    return nil if token.blank?

    find_by(token: token)&.tap { |t| t.touch(:last_used_at) }
  end
end
