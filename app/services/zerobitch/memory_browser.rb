# frozen_string_literal: true

require "json"
require "fileutils"

module Zerobitch
  class MemoryBrowser
    WORKSPACE_BASE = Rails.root.join("storage", "zerobitch", "workspaces")
    # ZeroClaw stores memory in SQLite at these common paths
    SQLITE_PATHS = %w[memory.db .zeroclaw/memory.db data/memory.db].freeze

    class << self
      def entries(agent_id, limit: 50)
        rows = sqlite_entries(agent_id, limit: limit)
        return rows if rows.any?

        fallback_files(agent_id).first(limit)
      end

      def search(agent_id, query, limit: 50)
        rows = sqlite_search(agent_id, query, limit: limit)
        return rows if rows.any?

        q = query.to_s.downcase
        fallback_files(agent_id)
          .select { |row| row[:content].to_s.downcase.include?(q) }
          .first(limit)
      end

      def search_all(query, limit: 50)
        results = []
        AgentRegistry.all.each do |agent|
          agent_results = search(agent[:id], query, limit: 10)
          agent_results.each { |r| r[:agent_id] = agent[:id]; r[:agent_name] = agent[:name]; r[:agent_emoji] = agent[:emoji] }
          results.concat(agent_results)
        end
        results.first(limit)
      end

      def transfer(from_agent_id, to_agent_id, entry_ids: nil)
        source_entries = entries(from_agent_id, limit: 500)
        source_entries = source_entries.select { |e| entry_ids.include?(e[:id]) } if entry_ids&.any?
        return { transferred: 0, error: "No entries to transfer" } if source_entries.empty?

        # Write to target agent's memory dir as a transfer file
        target_dir = WORKSPACE_BASE.join(to_agent_id.to_s, "memory")
        FileUtils.mkdir_p(target_dir)

        timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
        transfer_file = target_dir.join("transfer_from_#{from_agent_id}_#{timestamp}.md")

        content = "# Memory Transfer from #{from_agent_id}\n"
        content += "# Transferred at #{Time.current.iso8601}\n\n"
        source_entries.each do |entry|
          content += "## #{entry[:timestamp]}\n#{entry[:content]}\n\n"
        end

        File.write(transfer_file, content)
        { transferred: source_entries.size, file: transfer_file.to_s }
      end

      def db_path_for(agent_id)
        base = WORKSPACE_BASE.join(agent_id.to_s)
        SQLITE_PATHS.each do |rel|
          path = base.join(rel)
          return path.to_s if File.exist?(path)
        end
        nil
      end

      private

      def sqlite_entries(agent_id, limit: 50)
        db_path = db_path_for(agent_id)
        return [] unless db_path

        # Use sqlite3 CLI for read-only access (no gem dependency)
        cmd = ["sqlite3", "-json", "-readonly", db_path,
               "SELECT * FROM memories ORDER BY created_at DESC LIMIT #{limit.to_i}"]
        stdout, _stderr, status = Open3.capture3(*cmd)
        return [] unless status.success?

        parse_sqlite_json(stdout, "sqlite")
      rescue StandardError
        # Try alternate table names
        alt_tables(agent_id, db_path, limit)
      end

      def sqlite_search(agent_id, query, limit: 50)
        db_path = db_path_for(agent_id)
        return [] unless db_path

        safe_q = query.to_s.gsub("'", "''")
        cmd = ["sqlite3", "-json", "-readonly", db_path,
               "SELECT * FROM memories WHERE content LIKE '%#{safe_q}%' ORDER BY created_at DESC LIMIT #{limit.to_i}"]
        stdout, _stderr, status = Open3.capture3(*cmd)
        return [] unless status.success?

        parse_sqlite_json(stdout, "sqlite")
      rescue StandardError
        []
      end

      def alt_tables(agent_id, db_path, limit)
        # Discover tables
        stdout, _, status = Open3.capture3("sqlite3", "-readonly", db_path, ".tables")
        return [] unless status.success?

        tables = stdout.split.map(&:strip)
        memory_table = tables.find { |t| t =~ /memor|knowledge|fact|recall/i } || tables.first
        return [] unless memory_table

        stdout, _, status = Open3.capture3("sqlite3", "-json", "-readonly", db_path,
                                           "SELECT * FROM #{memory_table} LIMIT #{limit.to_i}")
        return [] unless status.success?

        parse_sqlite_json(stdout, "sqlite:#{memory_table}")
      rescue StandardError
        []
      end

      def parse_sqlite_json(json_str, source)
        rows = JSON.parse(json_str)
        rows.map do |row|
          {
            id: row["id"]&.to_s || row["rowid"]&.to_s || SecureRandom.hex(4),
            source: source,
            timestamp: row["created_at"] || row["timestamp"] || row["updated_at"] || "",
            content: row["content"] || row["text"] || row["value"] || row.values.join(" | "),
            metadata: row.except("id", "content", "text", "value", "created_at", "updated_at", "timestamp")
          }
        end
      rescue JSON::ParserError
        []
      end

      def fallback_files(agent_id)
        memory_dir = WORKSPACE_BASE.join(agent_id.to_s, "memory")
        workspace_dir = WORKSPACE_BASE.join(agent_id.to_s)

        files = []
        [memory_dir, workspace_dir].each do |dir|
          next unless Dir.exist?(dir)
          Dir.glob(dir.join("**", "*.{md,txt,json}")).each { |f| files << f if File.file?(f) }
        end

        files.flat_map do |path|
          content = File.read(path).to_s
          [{
            id: "file-#{Digest::MD5.hexdigest(path)[0..7]}",
            source: path.to_s.sub(Rails.root.to_s + "/", ""),
            timestamp: File.mtime(path).iso8601,
            content: content.truncate(2000)
          }]
        end.reject { |row| row[:content].blank? }
      rescue StandardError
        []
      end
    end
  end
end
