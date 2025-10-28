module Viewrail
  module SharedUtilities
    class ToolbarManager
      @toolbar = nil
      
      class << self
        def get_toolbar
          return @toolbar if @toolbar
          
          @toolbar = UI::Toolbar.new("Viewrail Tools")
          @toolbar
        end
        
        def add_general_buttons
          toolbar = get_toolbar
          
          # Help button
          cmd_help = UI::Command.new("Help") {
            show_help
          }
          cmd_help.small_icon = File.join(File.dirname(__FILE__), "..", "railing_generator", "icons", "help.svg")
          cmd_help.large_icon = File.join(File.dirname(__FILE__), "..", "railing_generator", "icons", "help.svg")
          cmd_help.tooltip = "Help Documentation"
          cmd_help.status_bar_text = "Open Sketchup Tools documentation"
          cmd_help.menu_text = "Help"
          
          # About button
          cmd_about = UI::Command.new("About") {
            show_about
          }
          cmd_about.small_icon = File.join(File.dirname(__FILE__), "..", "stair_generator", "icons", "info.svg")
          cmd_about.large_icon = File.join(File.dirname(__FILE__), "..", "stair_generator", "icons", "info.svg")
          cmd_about.tooltip = "About Viewrail Tools"
          cmd_about.status_bar_text = "About Viewrail SketchUp Extensions"
          cmd_about.menu_text = "About"

          toolbar.add_item(cmd_help)
          toolbar.add_item(cmd_about)
        end
        
        def show_toolbar
          get_toolbar.show if @toolbar
        end
        
        def show_help
          UI.openURL("https://docs.google.com/document/d/1TMCemWotBB-V-BzRuivw-8Cw0oT-DOK59HMGDZd08bc")
        end
        
        def show_about
          UI.messagebox(
            "Viewrail SketchUp Extensions\n\n" +
            "Stair Generator & Railing Generator\n\n" +
            "Creates parametric stairs and railings for architectural visualization.\n\n" +
            "Features:\n" +
            "• Parametric stair generation (Straight, 90°, U-shaped, Switchback)\n" +
            "• Glass railing systems\n" +
            "• Customizable dimensions and spacing\n" +
            "• Live preview and modification tools\n\n" +
            "© 2025 Viewrail",
            MB_OK,
            "About Viewrail Tools"
          )
        end
      end
    end
  end
end