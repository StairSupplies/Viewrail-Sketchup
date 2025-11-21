require 'erb'
require_relative '../../viewrail_shared/utilities'

module Viewrail
  module StairGenerator
    module Tools
      class StraightStairMenu
        def self.show
          last_values = Viewrail::StairGenerator.last_form_values(:straight)

          last_values[:tread_width] ||= 36.0

          dialog = UI::HtmlDialog.new(
            {
              :dialog_title => "Stair Form - Straight",
              :preferences_key => "com.viewrail.stair_generator",
              :scrollable => true,
              :resizable => true,
              :width => 500,
              :height => 750,
              :left => 100,
              :top => 100,
              :min_width => 500,
              :min_height => 800,
              :max_width => 500,
              :max_height => 1080,
              :style => UI::HtmlDialog::STYLE_DIALOG
            }
          )

          begin
            renderer = Viewrail::SharedUtilities::FormRenderer.new(last_values)
            html_content = renderer.render(File.join(File.dirname(__FILE__), "..", "forms", "stair_form.html.erb"))
            dialog.set_html(html_content)
          rescue => e
            UI.messagebox("Error loading form template: #{e.message}\n\nPlease check that the template file exists.")
            return
          end

          dialog.add_action_callback("create_stairs") do |action_context, params|
            values = JSON.parse(params)

            last_values[:num_treads] = values["num_treads"]
            last_values[:tread_run] = values["tread_run"]
            last_values[:tread_width] = values["tread_width"]
            last_values[:total_tread_run] = values["total_tread_run"]
            last_values[:stair_rise] = values["stair_rise"]
            last_values[:total_rise] = values["total_rise"]
            last_values[:glass_railing] = values["glass_railing"]
            last_values[:system_type] = values["system_type"]&.to_sym || :stack

            dialog.close

            new_stair = Viewrail::StairGenerator.create_stair_segment(values, [0,0,0], true)

            Viewrail::SharedUtilities.log_action("Added Straight system", values)

            Viewrail::StairGenerator.store_stair_parameters(new_stair, values, :straight)
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
