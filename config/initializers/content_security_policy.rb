# frozen_string_literal: true

# Content Security Policy (CSP) — defense-in-depth against XSS.
#
# Currently in REPORT-ONLY mode: logs violations to browser console
# without breaking anything. Flip to enforcing once baseline is clean.
#
# See: https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data, :blob, "https:"
    policy.object_src  :none
    policy.script_src  :self, :unsafe_inline  # unsafe_inline needed for Stimulus/Turbo; tighten with nonces later
    policy.style_src   :self, :unsafe_inline  # unsafe_inline needed for Tailwind utility classes
    policy.connect_src :self, "ws:", "wss:"   # ActionCable / Turbo Streams WebSocket
    policy.frame_src   :self                  # Showcase iframes are same-origin
    policy.base_uri    :self
    policy.form_action :self
  end

  # Report violations without enforcing (safe to deploy immediately).
  # To enforce: set this to false or remove it entirely.
  config.content_security_policy_report_only = true
end
