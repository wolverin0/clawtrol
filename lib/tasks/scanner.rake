namespace :scanner do
  desc "Scan all GET routes without parameters for 500 errors"
  task dead_routes: :environment do
    require 'net/http'

    puts "Scanning dead/empty routes..."
    routes = Rails.application.routes.routes.select do |route|
      route.verb == "GET" && 
      route.path.spec.to_s !~ /:/ && 
      !route.internal && 
      !route.path.spec.to_s.start_with?("/rails/") &&
      !route.path.spec.to_s.start_with?("/assets/") &&
      !route.path.spec.to_s.start_with?("/cable") &&
      route.path.spec.to_s.length > 2
    end.map { |r| r.path.spec.to_s.gsub('(.:format)', '') }.uniq

    app = ActionDispatch::Integration::Session.new(Rails.application)
    
    failed_routes = []

    routes.each do |path|
      begin
        app.get(path)
        status = app.response.status
        if status >= 500
          puts "❌ #{path} -> #{status}"
          failed_routes << path
        elsif status == 404
          puts "⚠️ #{path} -> #{status}"
          failed_routes << path
        else
          puts "✅ #{path} -> #{status}"
        end
      rescue => e
        puts "💥 #{path} -> Exception: #{e.message}"
        failed_routes << path
      end
    end

    if failed_routes.any?
      puts "\nFound #{failed_routes.count} potential dead/empty routes."
      # We do not fail the build for 404s necessarily, just logging them
    else
      puts "\nAll scanned routes are OK."
    end
  end
end