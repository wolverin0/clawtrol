# frozen_string_literal: true

module DiffHelper
  def render_diff_line(line)
    case line[:type]
    when :hunk
      content_tag(:tr, class: "bg-blue-900/20 text-blue-300") do
        content_tag(:td, "", class: "w-10 text-right pr-2 select-none text-content-muted border-r border-border") +
        content_tag(:td, "", class: "w-10 text-right pr-2 select-none text-content-muted border-r border-border") +
        content_tag(:td, line[:content], class: "pl-2 py-0.5")
      end

    when :addition
      content_tag(:tr, class: "bg-green-900/30") do
        content_tag(:td, "", class: "w-10 text-right pr-2 select-none text-content-muted border-r border-border") +
        content_tag(:td, line[:new_num], class: "w-10 text-right pr-2 select-none text-green-400/60 border-r border-border") +
        content_tag(:td, class: "pl-2 py-0.5 text-green-300") do
          content_tag(:span, "+", class: "select-none text-green-500 mr-1") + h(line[:content])
        end
      end

    when :deletion
      content_tag(:tr, class: "bg-red-900/30") do
        content_tag(:td, line[:old_num], class: "w-10 text-right pr-2 select-none text-red-400/60 border-r border-border") +
        content_tag(:td, "", class: "w-10 text-right pr-2 select-none text-content-muted border-r border-border") +
        content_tag(:td, class: "pl-2 py-0.5 text-red-300") do
          content_tag(:span, "-", class: "select-none text-red-500 mr-1") + h(line[:content])
        end
      end

    when :context
      content_tag(:tr, class: "hover:bg-bg-elevated/30") do
        content_tag(:td, line[:old_num], class: "w-10 text-right pr-2 select-none text-content-muted border-r border-border") +
        content_tag(:td, line[:new_num], class: "w-10 text-right pr-2 select-none text-content-muted border-r border-border") +
        content_tag(:td, class: "pl-2 py-0.5 text-content-secondary") do
          content_tag(:span, " ", class: "select-none mr-1") + h(line[:content])
        end
      end

    when :meta
      content_tag(:tr, class: "bg-bg-elevated/50 text-content-muted italic") do
        content_tag(:td, "", class: "w-10 border-r border-border") +
        content_tag(:td, "", class: "w-10 border-r border-border") +
        content_tag(:td, line[:content], class: "pl-2 py-0.5")
      end

    else
      ""
    end
  end
end
