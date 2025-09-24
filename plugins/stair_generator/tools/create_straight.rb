require 'erb'
require_relative '../../viewrail_shared/utilities'

module Viewrail
  module StairGenerator
    module Tools
      class StraightStairMenu
        def self.show
          # Get persistent values from the main module
          last_values = Viewrail::StairGenerator.last_form_values(:straight)

          # Create the HTML dialog
          dialog = UI::HtmlDialog.new(
            {
              :dialog_title => "Stair Form - Straight",
              :preferences_key => "com.viewrail.stair_generator",
              :scrollable => false,
              :resizable => false,
              :width => 500,
              :height => 720,
              :left => 100,
              :top => 100,
              :min_width => 500,
              :min_height => 720,
              :max_width => 500,
              :max_height => 820,
              :style => UI::HtmlDialog::STYLE_DIALOG
            }
          )

          # Render the HTML content from ERB template
          begin
            renderer = Viewrail::SharedUtilities::FormRenderer.new(last_values)
            html_content = renderer.render("C:/Viewrail-Sketchup/plugins/stair_generator/forms/stair_form.html.erb")
            dialog.set_html(html_content)
          rescue => e
            UI.messagebox("Error loading form template: #{e.message}\n\nPlease check that the template file exists.")
            return
          end

          # Add callbacks
          dialog.add_action_callback("create_stairs") do |action_context, params|
            values = JSON.parse(params)

            # Store the values for next time
            last_values[:num_treads] = values["num_treads"]
            last_values[:tread_run] = values["tread_run"]
            last_values[:total_tread_run] = values["total_tread_run"]
            last_values[:stair_rise] = values["stair_rise"]
            last_values[:total_rise] = values["total_rise"]
            last_values[:glass_railing] = values["glass_railing"]

            dialog.close

            # Create the stairs with the parameters
            params_with_width = values.merge({"tread_width" => 36.0})
            new_stair = Viewrail::StairGenerator.create_stair_segment(params_with_width)
            
            # Store ALL parameters for future modification
            Viewrail::StairGenerator.store_stair_parameters(new_stair, values, :straight)

            # Display parameters
            puts "Stair parameters:"
            puts "  Number of Treads: #{values["num_treads"]}"
            puts "  Tread Run: #{values["tread_run"].round(2)}\""
            puts "  Total Tread Run: #{values["total_tread_run"].round(2)}\""
            puts "  Stair Rise: #{values["stair_rise"].round(2)}\""
            puts "  Total Rise: #{values["total_rise"].round(2)}\""
            puts "  Glass Railing: #{values["glass_railing"]}"
          end

          dialog.add_action_callback("cancel") do |action_context|
            dialog.close
          end

          dialog.show
        end
      end # class StraightStairMenu
    end # module Tools
  end # module StairGenerator
end # module Viewrail
