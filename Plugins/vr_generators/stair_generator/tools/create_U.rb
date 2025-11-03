require 'erb'
require_relative '../../viewrail_shared/utilities'

module Viewrail
  module StairGenerator
    module Tools
      class UStairMenu
        @@stair_counter = 0

        def self.show
          last_values = Viewrail::StairGenerator.last_form_values(:landing_u)

          dialog = UI::HtmlDialog.new(
            {
              :dialog_title => "Stair Form - U",
              :preferences_key => "com.viewrail.u_stair_generator",
              :scrollable => true,
              :resizable => true,
              :width => 650,
              :height => 800,
              :left => 100,
              :top => 50,
              :min_width => 625,
              :min_height => 700,
              :max_width => 750,
              :max_height => 1100,
              :style => UI::HtmlDialog::STYLE_DIALOG
            }
          )

          begin
            renderer = Viewrail::SharedUtilities::FormRenderer.new(last_values)
            html_content = renderer.render(File.join(File.dirname(__FILE__), "..", "forms", "u_stair_form.html.erb"))
            dialog.set_html(html_content)
          rescue => e
            UI.messagebox("Error loading U-shaped stair form template: #{e.message}\n\nPlease check that the template file exists.")
            return
          end

          dialog.add_action_callback("resize_dialog") do |action_context, params|
            dimensions = JSON.parse(params)
            dialog.set_size(dimensions["width"], dimensions["height"])
          end

          dialog.add_action_callback("create_u_stairs") do |action_context, params|
            values = JSON.parse(params)

            last_values[:num_treads_lower] = values["num_treads_lower"]
            last_values[:num_treads_middle] = values["num_treads_middle"]
            last_values[:num_treads_upper] = values["num_treads_upper"]
            last_values[:header_to_wall] = values["header_to_wall"]
            last_values[:wall_to_wall] = values["wall_to_wall"]
            last_values[:tread_width_lower] = values["tread_width_lower"]
            last_values[:tread_width_middle] = values["tread_width_middle"]
            last_values[:tread_width_upper] = values["tread_width_upper"]
            last_values[:lower_landing_width] = values["lower_landing_width"]
            last_values[:lower_landing_depth] = values["lower_landing_depth"]
            last_values[:upper_landing_width] = values["upper_landing_width"]
            last_values[:upper_landing_depth] = values["upper_landing_depth"]
            last_values[:tread_run] = values["tread_run"]
            last_values[:stair_rise] = values["stair_rise"]
            last_values[:total_rise] = values["total_rise"]
            last_values[:turn_direction] = values["turn_direction"]
            last_values[:glass_railing] = values["glass_railing"]

            dialog.close

            stair_group = self.create_u_geometry(values)

            Viewrail::StairGenerator.store_stair_parameters(stair_group, values, :landing_u)
          end

          dialog.add_action_callback("cancel") do |action_context|
            dialog.close
          end

          dialog.show
        end # show

        def self.create_u_geometry(params, start_point = [0, 0, 0])
          model = Sketchup.active_model

          model.start_operation('Create U-Shaped Stairs', true)

          begin
            lower_landing_height = (params["num_treads_lower"] + 1) * params["stair_rise"]
            upper_landing_height = (params["num_treads_lower"] + params["num_treads_middle"] + 2) * params["stair_rise"]
            railing_side = get_railing_side(params["turn_direction"], params["glass_railing"])

            lower_params = {
              "num_treads" => params["num_treads_lower"],
              "tread_run" => params["tread_run"],
              "tread_width" => params["tread_width_lower"],
              "stair_rise" => params["stair_rise"],
              "glass_railing" => params["glass_railing"],
              "segment_name" => "Lower Stairs"
            }

            if params["glass_railing"] != "None"
              lower_params["glass_railing"] = railing_side
            end

            lower_stairs = Viewrail::StairGenerator.create_stair_segment(lower_params, [0, 0, 0])

            lower_landing_x = params["num_treads_lower"] * params["tread_run"]
            lower_landing_y = 0
            if params["turn_direction"] == "Right"
              lower_landing_y -= (params["lower_landing_width"] - params["tread_width_lower"].to_f)
            end
            lower_landing_z = lower_landing_height

            lower_landing = Viewrail::StairGenerator.create_landing(
              {
                "width" => params["lower_landing_width"],
                "depth" => params["lower_landing_depth"],
                "thickness" => params["stair_rise"] - 1,
                "glass_railing" => params["glass_railing"],
                "turn_direction" => params["turn_direction"]
              },
              [lower_landing_x, lower_landing_y, lower_landing_z]
            )

            if params["turn_direction"] == "Left"
              middle_start = [
                lower_landing_x + params["lower_landing_depth"],
                lower_landing_y + params["lower_landing_width"],
                lower_landing_z
              ]
              middle_rotation = 90.degrees
            else # Right turn
              middle_start = [
                lower_landing_x,
                lower_landing_y,
                lower_landing_z
              ]
              middle_rotation = -90.degrees
            end

            middle_params = {
              "num_treads" => params["num_treads_middle"],
              "tread_run" => params["tread_run"],
              "tread_width" => params["tread_width_middle"],
              "stair_rise" => params["stair_rise"],
              "glass_railing" => params["glass_railing"],
              "segment_name" => "Middle Stairs"
            }

            if params["glass_railing"] != "None"
              middle_params["glass_railing"] = railing_side
            end

            middle_stairs = Viewrail::StairGenerator.create_stair_segment(middle_params, middle_start)

            if middle_stairs
              rotation_point = Geom::Point3d.new(middle_start)
              rotation_axis = Geom::Vector3d.new(0, 0, 1)
              rotation = Geom::Transformation.rotation(rotation_point, rotation_axis, middle_rotation)
              middle_stairs.transform!(rotation)
            end

            upper_landing_width = params["upper_landing_width"]
            upper_landing_depth = params["upper_landing_depth"]

            if params["turn_direction"] == "Left"
              upper_landing_x = lower_landing_x + params["lower_landing_depth"]
              upper_landing_y = lower_landing_y + params["lower_landing_width"] + (params["num_treads_middle"] * params["tread_run"])
              upper_landing_z = upper_landing_height
            else # Right turn
              upper_landing_x = lower_landing_x - (params["upper_landing_width"].to_f - params["tread_width_upper"].to_f)
              upper_landing_y = lower_landing_y - (params["num_treads_middle"] * params["tread_run"])
              upper_landing_z = upper_landing_height
            end

            upper_landing = Viewrail::StairGenerator.create_landing(
              {
                "width" => upper_landing_width,
                "depth" => upper_landing_depth,
                "thickness" => params["stair_rise"] - 1,
                "glass_railing" => params["glass_railing"],
                "turn_direction" => params["turn_direction"]
              },
              [upper_landing_x, upper_landing_y, upper_landing_z]
            )

            if upper_landing
              rotation_point = Geom::Point3d.new([upper_landing_x, upper_landing_y, upper_landing_z])
              rotation_axis = Geom::Vector3d.new(0, 0, 1)
              rotation = Geom::Transformation.rotation(rotation_point, rotation_axis, middle_rotation)
              upper_landing.transform!(rotation)
            end

            outside_offset = params["lower_landing_width"] + upper_landing_depth + (params["num_treads_middle"] * params["tread_run"])

            if params["turn_direction"] == "Left"
              upper_start = [
                upper_landing_x - upper_landing_width,
                upper_landing_y + upper_landing_depth,
                upper_landing_z
              ]
            else # Right turn
              upper_start = [
                upper_landing_x,
                upper_landing_y,
                upper_landing_z
              ]
            end
            upper_rotation = 180.degrees

            upper_params = {
              "num_treads" => params["num_treads_upper"],
              "tread_run" => params["tread_run"],
              "tread_width" => params["tread_width_upper"],
              "stair_rise" => params["stair_rise"],
              "glass_railing" => params["glass_railing"],
              "segment_name" => "Upper Stairs"
            }

            if params["glass_railing"] != "None"
              upper_params["glass_railing"] = railing_side
            end

            last_stair = true
            upper_stairs = Viewrail::StairGenerator.create_stair_segment(upper_params, upper_start, last_stair)

            if upper_stairs
              rotation_point = Geom::Point3d.new(upper_start)
              rotation_axis = Geom::Vector3d.new(0, 0, 1)
              rotation = Geom::Transformation.rotation(rotation_point, rotation_axis, upper_rotation)
              upper_stairs.transform!(rotation)
            end

            @@stair_counter += 1
            total_treads = params["num_treads_lower"] + params["num_treads_middle"] + params["num_treads_upper"] + 2

            stair_group = model.active_entities.add_group([lower_stairs, lower_landing, middle_stairs, upper_landing, upper_stairs])
            stair_group.name = "U Stairs - #{total_treads} treads - ##{@@stair_counter}"

            if start_point != [0, 0, 0]
              transform = Geom::Transformation.new(start_point)
              stair_group.transform!(transform)
            end

            model.commit_operation

            Viewrail::SharedUtilities.log_action("Added U system", params)

            Sketchup.active_model.active_view.zoom_extents
            return stair_group

          rescue => e
            model.abort_operation
            UI.messagebox("Error creating U-shaped stairs: #{e.message}")
          end
        end # create_u_geometry

        def self.get_railing_side(turn_direction, railing_type)
          case turn_direction
          when "Left"
            case railing_type
            when "Inner"
              "Left"
            when "Outer"
              "Right"
            when "Both"
              "Both"
            else
              "None"
            end
          when "Right"
            case railing_type
            when "Inner"
              "Right"
            when "Outer"
              "Left"
            when "Both"
              "Both"
            else
              "None"
            end
          else
            "None"
          end
        end
      end # class UStairMenu
    end # module Tools
  end # module StairGenerator
end # module Viewrail
