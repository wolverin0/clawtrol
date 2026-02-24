namespace :daily_digest do
  desc "Send Daily Executive Digest via Telegram"
  task send: :environment do
    puts "Starting Daily Executive Digest..."
    DailyExecutiveDigestService.call
    puts "Daily Executive Digest completed."
  end
end
