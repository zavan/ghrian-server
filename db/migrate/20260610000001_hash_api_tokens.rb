class HashApiTokens < ActiveRecord::Migration[8.0]
  # Store only a SHA-256 digest of each token (plus a short prefix for display)
  # instead of the plaintext. Existing tokens are backfilled from their plaintext
  # value, so live clients keep working after this migration.
  def up
    add_column :api_tokens, :token_digest, :string
    add_column :api_tokens, :token_prefix, :string

    ApiToken.reset_column_information
    ApiToken.find_each do |record|
      raw = record.read_attribute(:token)
      next if raw.blank?

      record.update_columns(
        token_digest: Digest::SHA256.hexdigest(raw),
        token_prefix: raw[0, 12]
      )
    end

    remove_index :api_tokens, :token
    remove_column :api_tokens, :token
    add_index :api_tokens, :token_digest, unique: true
  end

  def down
    add_column :api_tokens, :token, :string
    remove_index :api_tokens, :token_digest
    remove_column :api_tokens, :token_digest
    remove_column :api_tokens, :token_prefix
    add_index :api_tokens, :token, unique: true
  end
end
