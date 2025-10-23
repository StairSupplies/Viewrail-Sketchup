require 'erb'
require 'sketchup.rb'
require_relative '../viewrail_shared/utilities'
require_relative 'tools/glass_railing_face_tool'

module Viewrail
  module RailingGenerator
    class << self
      def show_about
        UI.messagebox(
          "Railing Generator Extension\n\n" +
          "Creates various types of railings for architectural visualization.\n\n" +
          "Features:\n" +
          "• Glass railing systems\n" +
          "• Customizable dimensions and spacing\n" +
          "• Live preview while drawing\n\n" +
          "© 2025 Viewrail",
          MB_OK,
          "About Railing Generator"
        )
      end
    end

    unless file_loaded?(__FILE__)
      toolbar = UI::Toolbar.new("Railing Generator")

      cmd_glass_railing = UI::Command.new("Glass Railing") {
        Viewrail::RailingGenerator::Tools::GlassRailingTool.show
      }

      cmd_glass_railing.small_icon = File.join(File.dirname(__FILE__), "icons", "add_glass_railing.svg")
      cmd_glass_railing.large_icon = File.join(File.dirname(__FILE__), "icons", "add_glass_railing.svg")
      cmd_glass_railing.tooltip = "Create Glass Railing"
      cmd_glass_railing.status_bar_text = "Select vertical faces to create glass railings"
      cmd_glass_railing.menu_text = "Glass Railing"

      cmd_about = UI::Command.new("About") {
        show_about
      }
     cmd_about.small_icon = File.join(File.dirname(__FILE__), "..", "stair_generator", "icons", "logo-black.svg")
      cmd_about.large_icon = File.join(File.dirname(__FILE__), "..", "stair_generator", "icons", "logo-black.svg")
      cmd_about.tooltip = "About Railing Generator"
      cmd_about.status_bar_text = "About Railing Generator Extension"
      cmd_about.menu_text = "About"

      toolbar = toolbar.add_item(cmd_glass_railing)
      toolbar = toolbar.add_separator
      toolbar = toolbar.add_item(cmd_about)
      toolbar.show

      menu = UI.menu("Extensions")
      railing_menu = menu.add_submenu("Railing Generator")
      railing_menu.add_item(cmd_glass_railing)
      railing_menu.add_separator
      railing_menu.add_item(cmd_about)

      file_loaded(__FILE__)
    end
  end
end