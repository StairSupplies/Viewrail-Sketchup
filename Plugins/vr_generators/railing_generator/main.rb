require 'erb'
require 'sketchup.rb'
require_relative '../viewrail_shared/utilities'
require_relative '../viewrail_shared/toolbar_manager'
require_relative 'tools/glass_railing_face_tool'
require_relative 'tools/cable_railing_tool'

module Viewrail
  module RailingGenerator
    class << self

    end

    unless file_loaded?(__FILE__)
      toolbar = Viewrail::SharedUtilities::ToolbarManager.get_toolbar

      cmd_glass_railing = UI::Command.new("Glass Railing") {
        Viewrail::RailingGenerator::Tools::GlassRailingTool.show
      }

      cmd_glass_railing.small_icon = File.join(File.dirname(__FILE__), "icons", "add_glass_railing.svg")
      cmd_glass_railing.large_icon = File.join(File.dirname(__FILE__), "icons", "add_glass_railing.svg")
      cmd_glass_railing.tooltip = "Create Glass Railing"
      cmd_glass_railing.status_bar_text = "Select vertical faces to create glass railings"
      cmd_glass_railing.menu_text = "Glass Railing"

      toolbar.add_item(cmd_glass_railing)

      cmd_cable_railing = UI::Command.new("Cable Railing") {
        Viewrail::RailingGenerator::Tools::CableRailingTool.show
      }

      cmd_cable_railing.small_icon = File.join(File.dirname(__FILE__), "icons", "add_post_railing.svg")
      cmd_cable_railing.large_icon = File.join(File.dirname(__FILE__), "icons", "add_post_railing.svg")
      cmd_cable_railing.tooltip = "Create Cable Railing"
      cmd_cable_railing.status_bar_text = "Select vertical faces to create cable railings"
      cmd_cable_railing.menu_text = "Cable Railing"

      toolbar.add_item(cmd_cable_railing)
      toolbar.add_separator

      menu = UI.menu("Extensions")
      railing_menu = menu.add_submenu("Railing Generator")
      railing_menu.add_item(cmd_glass_railing)
      railing_menu.add_item(cmd_cable_railing)

      file_loaded(__FILE__)
    end
  end
end