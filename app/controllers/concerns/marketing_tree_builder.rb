# frozen_string_literal: true

module MarketingTreeBuilder
  extend ActiveSupport::Concern

  included do
    attr_reader :tree_builder_root_path
  end

  # Build a directory tree for the marketing root with optional search
  def build_tree(root_path, search_query = "")
    tree = { name: "marketing", path: "", type: :directory, children: [] }

    return tree unless Dir.exist?(root_path)

    @tree_builder_root_path = root_path

    entries = Dir.glob("#{root_path}/**/*", File::FNM_DOTMATCH).reject { |f| File.basename(f).start_with?(".") }

    entries.each do |full_path|
      relative = full_path.sub("#{root_path}/", "")
      next if search_query.present? && !relative.downcase.include?(search_query.downcase)

      parts = relative.split("/")
      insert_into_tree(tree, parts, File.directory?(full_path), relative)
    end

    sort_tree(tree)
    tree
  end

  private

  # Insert a path into the tree structure
  def insert_into_tree(tree, parts, is_dir, full_relative_path)
    current = tree

    parts.each_with_index do |part, index|
      is_last = index == parts.length - 1
      existing = current[:children].find { |c| c[:name] == part }

      if existing
        current = existing
      else
        node = {
          name: part,
          path: parts[0..index].join("/"),
          type: is_last && !is_dir ? :file : :directory,
          children: []
        }
        node[:extension] = File.extname(part).downcase if node[:type] == :file
        current[:children] << node
        current = node
      end
    end
  end

  # Sort tree: directories first, then files, alphabetically
  def sort_tree(node)
    return unless node[:children]

    node[:children].sort_by! { |c| [c[:type] == :directory ? 0 : 1, c[:name].downcase] }
    node[:children].each { |child| sort_tree(child) }
  end
end
