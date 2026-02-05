require "test_helper"

# System tests with Capybara + Selenium
#
# REQUIREMENTS:
# - Chrome/Chromium must be installed for headless browser tests
# - Install on Ubuntu: sudo apt install chromium-browser
# - Or download from: https://www.google.com/chrome/
#
# If Chrome is not available, tests will use rack_test driver which
# cannot execute JavaScript but is useful for basic page rendering tests.

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Check if Chrome/Chromium is available
  CHROME_AVAILABLE = system("which google-chrome > /dev/null 2>&1") ||
                     system("which chromium-browser > /dev/null 2>&1") ||
                     system("which chromium > /dev/null 2>&1")

  if CHROME_AVAILABLE
    driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400] do |options|
      # Disable sandbox for CI/Docker environments
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("--disable-gpu")
      # Enable logging for debugging
      options.add_argument("--enable-logging")
      options.add_argument("--v=1")
    end
  else
    # Fallback to rack_test (no JS support, but works without browser)
    driven_by :rack_test

    def self.chrome_warning_shown?
      @chrome_warning_shown ||= false
    end

    def self.chrome_warning_shown!
      @chrome_warning_shown = true
    end

    setup do
      unless ApplicationSystemTestCase.chrome_warning_shown?
        puts "\n" + "=" * 70
        puts "⚠️  WARNING: Chrome/Chromium not found!"
        puts "   System tests are running with :rack_test driver (no JS support)."
        puts ""
        puts "   To enable full browser testing, install Chrome:"
        puts "     Ubuntu: sudo apt install chromium-browser"
        puts "     Or download: https://www.google.com/chrome/"
        puts "=" * 70 + "\n"
        ApplicationSystemTestCase.chrome_warning_shown!
      end
    end
  end

  # Screenshot on failure for debugging
  teardown do
    if CHROME_AVAILABLE && !passed?
      # Save screenshot to tmp/screenshots with timestamp
      timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
      test_name = name.gsub(/[^a-z0-9]/i, "_")
      screenshot_path = Rails.root.join("tmp", "screenshots", "#{test_name}_#{timestamp}.png")

      begin
        save_screenshot(screenshot_path)
        puts "\n📸 Screenshot saved: #{screenshot_path}"
      rescue => e
        puts "\n⚠️  Could not save screenshot: #{e.message}"
      end
    end
  end

  # Sign in via the actual login form
  # This works reliably with Selenium since we use the real auth flow
  def sign_in_as(user, password: "password123")
    visit new_session_path

    fill_in "Email", with: user.email_address
    fill_in "Password", with: password
    click_button "Sign in"

    # Wait for redirect to complete
    assert_no_current_path new_session_path, wait: 5
  end

  # Alternative: Direct cookie-based sign in (for non-Selenium drivers)
  def sign_in_via_cookie(user)
    session = user.sessions.create!

    if CHROME_AVAILABLE
      # For Selenium, use form-based login instead
      sign_in_as(user)
    else
      # For rack_test, set cookie directly
      page.driver.browser.set_cookie("session_id=#{session.id}")
    end
  end

  # Wait helpers for async operations
  def wait_for_turbo
    return unless CHROME_AVAILABLE

    # Wait for Turbo to finish processing
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop until page.evaluate_script("typeof Turbo === 'undefined' || !Turbo.session.drive")
    end
  rescue Timeout::Error
    # Continue if timeout - Turbo may not be loaded
  end

  def wait_for_stimulus
    return unless CHROME_AVAILABLE

    # Wait for Stimulus controllers to connect
    sleep 0.1
  end
end
