# A simple bearer token a user generates in the admin to authenticate API clients
# (e.g. a native macOS app). No OAuth — clients send "Authorization: Bearer <token>".
#
# Only a SHA-256 digest of the token is stored; the plaintext is shown once, right
# after generation, and is unrecoverable afterwards (a lost token is revoked and
# recreated). `token_prefix` keeps the first few characters around so a token can
# still be identified in the list.
class ApiToken < ApplicationRecord
  belongs_to :user

  validates :name, presence: true

  before_create :generate_token

  # The plaintext token, available only in memory right after generation.
  attr_reader :token

  # Look up an active token by its digest and stamp its usage. Returns nil for
  # unknown tokens.
  def self.authenticate(token)
    return nil if token.blank?

    find_by(token_digest: digest(token))&.tap { |t| t.touch(:last_used_at) }
  end

  def self.digest(token)
    Digest::SHA256.hexdigest(token)
  end

  private
    def generate_token
      @token = "ghr_#{SecureRandom.urlsafe_base64(32)}"
      self.token_digest = self.class.digest(@token)
      self.token_prefix = @token[0, 12]
    end
end
