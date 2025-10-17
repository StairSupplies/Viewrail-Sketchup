require 'erb'
require_relative '../../viewrail_shared/utilities'

module Viewrail
  module StairGenerator
    module Tools
      class SwitchbackStairMenu
        def self.show
          last_values = Viewrail::StairGenerator.last_form_values(:switchback)

          dialog = UI::HtmlDialog.new(
            {
              :dialog_title => "Stair Form - Switchback",
              :preferences_key => "com.viewrail.landing_stair_generator",
              :scrollable => true,
              :resizable => true,
              :width => 650,
              :height => 700,
              :left => 100,
              :top => 50,
              :min_width => 625,
              :min_height => 700,
              :max_width => 750,
              :max_height => 1000,
              :style => UI::HtmlDialog::STYLE_DIALOG
            }
          )

          begin
            renderer = Viewrail::SharedUtilities::FormRenderer.new(last_values)
            html_content = renderer.render(File.join(File.dirname(__FILE__), "..", "forms", "switchback_stair_form.html.erb"))
            dialog.set_html(html_content)
          rescue => e
            UI.messagebox("Error loading switchback form template: #{e.message}")
            return
          end

          dialog.add_action_callback("resize_dialog") do |action_context, params|
            dimensions = JSON.parse(params)
            dialog.set_size(dimensions["width"], dimensions["height"])
          end

          dialog.add_action_callback("create_switchback_stairs") do |action_context, params|
            values = JSON.parse(params)

            last_values[:num_treads_lower] = values["num_treads_lower"]
            last_values[:num_treads_upper] = values["num_treads_upper"]
            last_values[:header_to_wall] = values["header_to_wall"]
            last_values[:wall_to_wall] = values["wall_to_wall"]
            last_values[:maximize_tread_width] = values["maximize_tread_width"]
            last_values[:tread_width_lower] = values["tread_width_lower"]
            last_values[:tread_width_upper] = values["tread_width_upper"]
            last_values[:landing_width] = values["landing_width"]
            last_values[:landing_depth] = values["landing_depth"]
            last_values[:tread_run] = values["tread_run"]
            last_values[:stair_rise] = values["stair_rise"]
            last_values[:total_rise] = values["total_rise"]
            last_values[:turn_direction] = values["turn_direction"]
            last_values[:glass_railing] = values["glass_railing"]

            dialog.close

            stair_group = self.create_sb_geometry(values)

            Viewrail::StairGenerator.store_stair_parameters(stair_group, values, :switchback)
          end

          dialog.add_action_callback("cancel") do |action_context|
            dialog.close
          end

          dialog.show
        end # show

        def self.create_sb_geometry(params, start_point = [0, 0, 0])
          model = Sketchup.active_model

          model.start_operation('Create Switchback', true)

          begin
            landing_height = (params["num_treads_lower"] + 1) * params["stair_rise"]

            lower_params = {
              "num_treads" => params["num_treads_lower"],
              "tread_run" => params["tread_run"],
              "tread_width" => params["tread_width_lower"],
              "stair_rise" => params["stair_rise"],
              "glass_railing" => params["glass_railing"],
              "segment_name" => "Lower Stairs"
              }

            if params["glass_railing"] != "None"
              if params["turn_direction"] == "Left"
                case params["glass_railing"]
                when "Inner"
                  lower_params["glass_railing"] = "Left"
                when "Outer"
                  lower_params["glass_railing"] = "Right"
                when "Both"
                  lower_params["glass_railing"] = "Both"
                end
              else # Right turn
                case params["glass_railing"]
                when "Inner"
                  lower_params["glass_railing"] = "Right"
                when "Outer"
                  lower_params["glass_railing"] = "Left"
                when "Both"
                  lower_params["glass_railing"] = "Both"
                end
              end
            end

            lower_stairs = Viewrail::StairGenerator.create_stair_segment(lower_params, [0, 0, 0])

            landing_x = params["num_treads_lower"] * params["tread_run"]
            landing_y = 0
            if params["turn_direction"] == "Right"
              width_delta = params["landing_width"] - (params["tread_width_upper"] + params["tread_width_lower"])
              landing_y = -params["tread_width_lower"] - width_delta
            end
            landing_z = landing_height

            landing = Viewrail::StairGenerator.create_wide_landing(
              {
                "width" => params["landing_width"],
                "depth" => params["landing_depth"],
                "thickness" => params["stair_rise"] - 1,
                "glass_railing" => params["glass_railing"],
                "turn_direction" => params["turn_direction"]
              },
              [landing_x, landing_y, landing_z]
              )

            stack_overhang = 5
            if params["turn_direction"] == "Left"
              upper_start = [
                landing_x + stack_overhang,
                landing_y + params["landing_width"],
                landing_z
              ]
              upper_rotation = 180.degrees
            else
              upper_start = [
                landing_x + stack_overhang,
                landing_y + params["tread_width_upper"],
                landing_z
              ]
              upper_rotation = -180.degrees
            end

            upper_params = {
              "num_treads" => params["num_treads_upper"],
              "tread_run" => params["tread_run"],
              "tread_width" => params["tread_width_upper"],
              "stair_rise" => params["stair_rise"],
              "glass_railing" => params["glass_railing"],
              "segment_name" => "Upper Stairs"
            }

            if params["glass_railing"] != "None"
              if params["turn_direction"] == "Left"
                case params["glass_railing"]
                when "Inner"
                  upper_params["glass_railing"] = "Left"
                when "Outer"
                  upper_params["glass_railing"] = "Right"
                when "Both"
                  upper_params["glass_railing"] = "Both"
                end
              else # Right turn
                case params["glass_railing"]
                when "Inner"
                  upper_params["glass_railing"] = "Right"
                when "Outer"
                  upper_params["glass_railing"] = "Left"
                when "Both"
                  upper_params["glass_railing"] = "Both"
                end
              end
            end

            upper_stairs = Viewrail::StairGenerator.create_stair_segment(upper_params, upper_start)

            if upper_stairs
              rotation_point = Geom::Point3d.new(upper_start)
              rotation_axis = Geom::Vector3d.new(0, 0, 1)
              rotation = Geom::Transformation.rotation(rotation_point, rotation_axis, upper_rotation)
              upper_stairs.transform!(rotation)
            end

            stair_group = model.active_entities.add_group([lower_stairs, landing, upper_stairs])
            stair_group.name = "Switchback Stairs - #{params["num_treads_lower"] + params["num_treads_upper"] + 1} treads"

            if start_point != [0, 0, 0]
              transform = Geom::Transformation.new(start_point)
              stair_group.transform!(transform)
            end

            model.commit_operation

            Sketchup.active_model.active_view.zoom_extents
            return stair_group

          rescue => e
            model.abort_operation
            UI.messagebox("Error creating landing stairs: #{e.message}")
          end
        end # create_sb_geometry
      end # class SwitchbackStairMenu
    end # module Tools
  end # module StairGenerator
end # module Viewrail
