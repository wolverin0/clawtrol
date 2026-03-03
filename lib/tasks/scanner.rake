namespace :scanner do
  desc "Scan all GET routes without parameters for 500 errors"
  task dead_routes: :environment do
    puts "Scanning dead/empty routes..."

    results = DeadRouteScanner.scan

    results.each do |result|
      if result[:exception].present?
        puts "💥 #{result[:path]} -> Exception: #{result[:exception]}"
      elsif result[:status] >= 500
        puts "❌ #{result[:path]} -> #{result[:status]}"
      elsif result[:status] == 404
        puts "⚠️ #{result[:path]} -> #{result[:status]}"
      else
        puts "✅ #{result[:path]} -> #{result[:status]}"
      end
    end

    failed_routes = results.select { |result| result[:failed] }

    if failed_routes.any?
      puts "\nFound #{failed_routes.count} potential dead/empty routes."
      # We do not fail the build for 404s necessarily, just logging them
    else
      puts "\nAll scanned routes are OK."
    end
  end
end
