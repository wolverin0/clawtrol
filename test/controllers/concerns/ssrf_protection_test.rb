# frozen_string_literal: true

require "test_helper"

class SsrfProtectionTest < ActiveSupport::TestCase
  # Include the concern in a test class
  class TestHost
    include SsrfProtection
    # Make private methods public for testing
    public :safe_outbound_url?, :private_ip?
  end

  setup do
    @host = TestHost.new
  end

  # === Safe URLs ===

  test "allows external HTTPS URLs" do
    assert @host.safe_outbound_url?("https://api.openai.com/v1/chat/completions")
  end

  test "allows external HTTP URLs" do
    assert @host.safe_outbound_url?("http://api.example.com/test")
  end

  # === Blocked: Loopback ===

  test "blocks localhost" do
    refute @host.safe_outbound_url?("http://localhost:8080/api")
  end

  test "blocks 127.0.0.1" do
    refute @host.safe_outbound_url?("http://127.0.0.1:5432/test")
  end

  test "blocks 127.x.x.x range" do
    refute @host.safe_outbound_url?("http://127.0.0.2/test")
  end

  test "blocks IPv6 loopback ::1" do
    refute @host.safe_outbound_url?("http://[::1]:8080/test")
  end

  # === Blocked: Private networks ===

  test "blocks 10.x.x.x" do
    refute @host.safe_outbound_url?("http://10.0.0.1/api")
  end

  test "blocks 172.16-31.x.x" do
    refute @host.safe_outbound_url?("http://172.16.0.1/api")
    refute @host.safe_outbound_url?("http://172.31.255.255/api")
  end

  test "allows 172.32.x.x (not private)" do
    assert @host.safe_outbound_url?("http://172.32.0.1/api")
  end

  test "blocks 192.168.x.x" do
    refute @host.safe_outbound_url?("http://192.168.100.186:4001/api")
    refute @host.safe_outbound_url?("http://192.168.1.1/api")
  end

  test "blocks 0.x.x.x" do
    refute @host.safe_outbound_url?("http://0.0.0.0/test")
  end

  # === Blocked: Link-local ===

  test "blocks 169.254.x.x link-local" do
    refute @host.safe_outbound_url?("http://169.254.169.254/latest/meta-data/")
  end

  # === Blocked: Internal TLDs ===

  test "blocks .internal TLD" do
    refute @host.safe_outbound_url?("http://service.internal/api")
  end

  test "blocks .local TLD" do
    refute @host.safe_outbound_url?("http://myhost.local:3000/test")
  end

  # === Edge cases ===

  test "rejects invalid URIs" do
    refute @host.safe_outbound_url?("not a url")
  end

  test "rejects empty URL" do
    refute @host.safe_outbound_url?("")
  end

  test "rejects nil URL" do
    refute @host.safe_outbound_url?(nil)
  end

  test "rejects non-HTTP schemes" do
    refute @host.safe_outbound_url?("ftp://files.example.com/test")
    refute @host.safe_outbound_url?("file:///etc/passwd")
  end

  test "rejects URL without host" do
    refute @host.safe_outbound_url?("http:///path")
  end

  # === private_ip? helper ===

  test "private_ip identifies private addresses" do
    assert @host.private_ip?("127.0.0.1")
    assert @host.private_ip?("10.0.0.1")
    assert @host.private_ip?("192.168.1.1")
    assert @host.private_ip?("172.16.0.1")
  end

  test "private_ip allows public addresses" do
    refute @host.private_ip?("8.8.8.8")
    refute @host.private_ip?("1.1.1.1")
    refute @host.private_ip?("203.0.113.1")
  end
end
