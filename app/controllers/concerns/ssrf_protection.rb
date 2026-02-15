# frozen_string_literal: true

# Shared SSRF protection for controllers that make outbound HTTP requests
# to user-provided URLs (model provider testing, webhook config, etc.).
#
# Usage:
#   include SsrfProtection
#
#   def test_endpoint
#     unless safe_outbound_url?(params[:url])
#       render json: { error: "URL points to private/internal network" }, status: :forbidden
#       return
#     end
#     # ... make request ...
#   end
module SsrfProtection
  extend ActiveSupport::Concern

  PRIVATE_HOST_PATTERNS = [
    /\A127\./,                         # loopback IPv4
    /\A10\./,                          # private 10.x
    /\A172\.(1[6-9]|2\d|3[0-1])\./,   # private 172.16-31.x
    /\A192\.168\./,                    # private 192.168.x
    /\A0\./,                           # 0.0.0.0/8
    /\Alocalhost\z/i,                  # localhost
    /\A\[?::1\]?\z/,                   # IPv6 loopback
    /\A169\.254\./,                    # link-local
    /\.internal\z/i,                   # internal TLDs
    /\.local\z/i                       # mDNS
  ].freeze

  private

  # Returns true if the URL points to a safe (non-internal) host.
  # Returns false for private IPs, loopback, link-local, and internal TLDs.
  #
  # @param url [String] the URL to validate
  # @return [Boolean]
  def safe_outbound_url?(url)
    uri = URI.parse(url.to_s)
    return false unless uri.host.present?
    return false unless %w[http https].include?(uri.scheme)

    host = uri.host.downcase.delete_prefix("[").delete_suffix("]")
    return false if PRIVATE_HOST_PATTERNS.any? { |pattern| host.match?(pattern) }

    # Resolve DNS to check for private IPs (defense in depth)
    begin
      addrs = Resolv.getaddresses(host)
      return false if addrs.any? { |addr| private_ip?(addr) }
    rescue Resolv::ResolvError
      # DNS resolution failed — allow (could be valid unreachable host)
    end

    true
  rescue URI::InvalidURIError
    false
  end

  def private_ip?(addr)
    PRIVATE_HOST_PATTERNS.any? { |pattern| addr.match?(pattern) }
  end
end
