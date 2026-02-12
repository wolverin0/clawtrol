namespace :api do
  desc "Create an API token for a user by email"
  task :create_token, [ :email ] => :environment do |_t, args|
    email = args[:email]

    if email.blank?
      puts "Usage: rails api:create_token[user@example.com]"
      exit 1
    end

    user = User.find_by(email_address: email.downcase)

    if user.nil?
      puts "Error: User with email '#{email}' not found"
      exit 1
    end

    token = user.api_tokens.create!(name: "CLI Token #{Time.current.strftime('%Y-%m-%d %H:%M')}")

    puts "API Token created successfully!"
    puts "=" * 50
    puts "User: #{user.email_address}"
    puts "Token Name: #{token.name}"
    puts "Token: #{token.token}"
    puts "=" * 50
    puts ""
    puts "Use this token in the Authorization header:"
    puts "  Authorization: Bearer #{token.token}"
  end

  desc "List all API tokens for a user"
  task :list_tokens, [ :email ] => :environment do |_t, args|
    email = args[:email]

    if email.blank?
      puts "Usage: rails api:list_tokens[user@example.com]"
      exit 1
    end

    user = User.find_by(email_address: email.downcase)

    if user.nil?
      puts "Error: User with email '#{email}' not found"
      exit 1
    end

    tokens = user.api_tokens

    if tokens.empty?
      puts "No API tokens found for #{user.email_address}"
    else
      puts "API Tokens for #{user.email_address}:"
      puts "=" * 70
      tokens.each do |token|
        last_used = token.last_used_at ? token.last_used_at.strftime("%Y-%m-%d %H:%M") : "Never"
        puts "  Name: #{token.name}"
        puts "  Token: #{token.token[0..7]}...#{token.token[-8..]}"
        puts "  Last used: #{last_used}"
        puts "  Created: #{token.created_at.strftime('%Y-%m-%d %H:%M')}"
        puts "-" * 70
      end
    end
  end

  desc "Revoke an API token"
  task :revoke_token, [ :token ] => :environment do |_t, args|
    token_value = args[:token]

    if token_value.blank?
      puts "Usage: rails api:revoke_token[token_value]"
      exit 1
    end

    token = ApiToken.find_by(token: token_value)

    if token.nil?
      puts "Error: Token not found"
      exit 1
    end

    token.destroy!
    puts "Token revoked successfully"
  end
end
