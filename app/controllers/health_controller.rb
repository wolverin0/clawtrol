# frozen_string_literal: true

# Deep health check used by external monitors. /up stays as the Rails default
# process-alive probe (returns 200 just because the boot finished). /health
# additionally validates that the DB read path, Solid Queue, Solid Cache, and
# the Active Record encryption keys are functional. Anything broken returns
# 503 with a JSON body that names the failing subsystem.
class HealthController < ApplicationController
  allow_unauthenticated_access

  def show
    checks = {
      database: check_database,
      solid_queue: check_solid_queue,
      cache: check_cache,
      ar_encryption: check_ar_encryption
    }

    if checks.values.all? { |v| v[:ok] }
      render json: { status: "ok", time: Time.current.iso8601, checks: checks }
    else
      render json: { status: "degraded", time: Time.current.iso8601, checks: checks }, status: :service_unavailable
    end
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute("SELECT 1")
    { ok: true }
  rescue StandardError => e
    { ok: false, error: "#{e.class}: #{e.message}".truncate(200) }
  end

  def check_solid_queue
    SolidQueue::Job.connection.execute("SELECT 1")
    { ok: true }
  rescue StandardError => e
    { ok: false, error: "#{e.class}: #{e.message}".truncate(200) }
  end

  def check_cache
    Rails.cache.write("health_check", Time.current.to_i, expires_in: 30.seconds)
    Rails.cache.read("health_check") ? { ok: true } : { ok: false, error: "cache write/read mismatch" }
  rescue StandardError => e
    { ok: false, error: "#{e.class}: #{e.message}".truncate(200) }
  end

  # If AR encryption is misconfigured, every encrypted attribute read will
  # blow up at request time. Cheap to verify here.
  def check_ar_encryption
    return { ok: true, skipped: true } unless ActiveRecord::Encryption.config.primary_key.present?

    test_value = "health-#{SecureRandom.hex(4)}"
    encrypted = ActiveRecord::Encryption.encryptor.encrypt(test_value)
    decrypted = ActiveRecord::Encryption.encryptor.decrypt(encrypted)
    decrypted == test_value ? { ok: true } : { ok: false, error: "encrypt/decrypt mismatch" }
  rescue StandardError => e
    { ok: false, error: "#{e.class}: #{e.message}".truncate(200) }
  end
end
