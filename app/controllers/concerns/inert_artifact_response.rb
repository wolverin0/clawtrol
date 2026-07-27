# frozen_string_literal: true

module InertArtifactResponse
  extend ActiveSupport::Concern

  private

  def render_inert_html_source(content, filename: "artifact.html")
    response.headers["Content-Disposition"] = ActionDispatch::Http::ContentDisposition.format(
      disposition: "attachment",
      filename: filename
    )
    response.headers["Content-Security-Policy"] = "sandbox; default-src 'none'"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Cache-Control"] = "private, no-store"
    render plain: content.to_s, content_type: "text/plain; charset=utf-8", layout: false
  end
end
