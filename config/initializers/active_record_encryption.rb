# frozen_string_literal: true

# Wire ActiveRecord::Encryption keys from ENV in production deploys that
# don't use Rails credentials (no master.key on disk). Keys are generated
# at first deploy and persisted in /etc/clawtrol/clawtrol.env. Rotating any
# of these makes existing encrypted columns undecryptable — the rescue in
# app/models/user.rb returns nil for those fields so the app keeps serving.
%i[primary_key deterministic_key key_derivation_salt].each do |key|
  env_name = "ACTIVE_RECORD_ENCRYPTION_#{key.to_s.upcase}"
  value = ENV[env_name]
  Rails.application.config.active_record.encryption.public_send("#{key}=", value) if value.present?
end
