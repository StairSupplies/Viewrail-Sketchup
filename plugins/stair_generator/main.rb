require 'erb'
require_relative '../viewrail_shared/utilities'
require_relative 'tools/create_90'
module Viewrail
  module StairGenerator
    #Version 8 - Stair Generator
    class << self

      def last_form_values(stair_type = :straight)
        @last_form_values ||= {}
        @last_form_values[stair_type] ||= case stair_type
          when :straight
            {
              :num_treads => 13,
              :tread_run => 11.0,
              :total_tread_run => 143.0,
              :stair_rise => 7.5,
              :total_rise => 105.0,
              :glass_railing => "None"
            }
          when :landing_90
            {
              :num_treads_lower => 6,
              :num_treads_upper => 6,
              :header_to_wall => 144.0,
              :tread_width_lower => 36.0,
              :tread_width_upper => 36.0,
              :landing_width => 36.0,
              :landing_depth => 36.0,
              :tread_run => 11.0,
              :stair_rise => 7.5,
              :total_rise => 91.0,
              :turn_direction => "Left",
              :glass_railing => "None"
            }
          when :u_shape
            # Future U-shape defaults
            {}
          when :switchback
            # Future switchback defaults
            {}
          else
            {}
        end
      end

      def add_stair_menu
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

        # Initialize last values for straight stairs
        last_values = Viewrail::StairGenerator.last_form_values(:straight)

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
          # Use default tread width of 36" for straight stairs
          params_with_width = values.merge({"tread_width" => 36.0})
          Viewrail::StairGenerator.create_stair_segment(params_with_width)

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

      def add_landing_stair_menu
        Viewrail::StairGenerator::Tools::Add90StairMenu.show
      end

      # Create a single stair segment (modular method)
      def create_stair_segment(params, start_point = [0, 0, 0])
        model = Sketchup.active_model
        entities = model.active_entities

        # Extract parameters
        num_treads = params["num_treads"]
        tread_run = params["tread_run"]
        tread_width = params["tread_width"] || 36.0
        stair_rise = params["stair_rise"]
        glass_railing = params["glass_railing"] || "None"
        segment_name = params["segment_name"] || "Stairs"

        reveal = 1
        tread_thickness = stair_rise - reveal
        riser_thickness = 1.0

        # Glass panel dimensions
        glass_thickness = 0.5
        glass_inset = 1.0
        glass_height = 36.0

        # Create a group for this stair segment
        stairs_group = entities.add_group
        stairs_entities = stairs_group.entities

        # Apply starting transformation
        transform = Geom::Transformation.new(start_point)
        stairs_group.transform!(transform)

        # Create each step
        (1..num_treads).each do |i|
          x_position = (i - 1) * tread_run
          z_position = i * stair_rise

          # Create tread
          stack_overhang = 5
          tread_points = [
            [x_position, 0, z_position],
            [x_position + tread_run + stack_overhang, 0, z_position],
            [x_position + tread_run + stack_overhang, tread_width, z_position],
            [x_position, tread_width, z_position]
          ]
          tread_face = stairs_entities.add_face(tread_points)
          tread_face.pushpull(-tread_thickness) if tread_face

          # Create riser
          nosing_value = 0.75
          riser_points = [
            [x_position + nosing_value, nosing_value, z_position - tread_thickness],
            [x_position + tread_run + stack_overhang, nosing_value, z_position - tread_thickness],
            [x_position + tread_run + stack_overhang, tread_width - nosing_value, z_position - tread_thickness],
            [x_position + nosing_value, tread_width - nosing_value, z_position - tread_thickness]
          ]
          riser_face = stairs_entities.add_face(riser_points)
          riser_face.pushpull(riser_thickness) if riser_face
        end

        # Add glass railings if specified
        if glass_railing != "None"
          add_glass_railings_to_segment(stairs_entities, num_treads, tread_run, tread_width,
                                       stair_rise, glass_railing, glass_thickness, glass_inset, glass_height)
        end

        # Name the group
        stairs_group.name = "#{segment_name} - #{num_treads} treads"

        # Store parameters as attributes
        stairs_group.set_attribute("stair_generator", "num_treads", num_treads)
        stairs_group.set_attribute("stair_generator", "tread_run", tread_run)
        stairs_group.set_attribute("stair_generator", "tread_width", tread_width)
        stairs_group.set_attribute("stair_generator", "stair_rise", stair_rise)
        stairs_group.set_attribute("stair_generator", "glass_railing", glass_railing)
        stairs_group.set_attribute("stair_generator", "segment_type", "stairs")

        return stairs_group
      end

      # Create landing (modular method)
      def create_landing(params, position = [0, 0, 0])
        model = Sketchup.active_model
        entities = model.active_entities

        width = params["width"] + 5  # Add overhang
        depth = params["depth"]
        thickness = params["thickness"]
        glass_railing = params["glass_railing"] || "None"
        turn_direction = params["turn_direction"] || "Left"

        # Create a group for the landing
        landing_group = entities.add_group
        landing_entities = landing_group.entities

        # Create landing platform
        landing_points = [
          [0, 0, 0],
          [depth, 0, 0],
          [depth, width, 0],
          [0, width, 0]
        ]

        # Create riser
          nosing_value = 0.75
          reveal = 1
          riser_thickness = 1.0
          riser_points = [
            [nosing_value, nosing_value, -(thickness+reveal)],
            [5, nosing_value, -(thickness+reveal)],
            [5, width - nosing_value, -(thickness+reveal)],
            [nosing_value, width - nosing_value, -(thickness+reveal)]
          ]
          

        landing_face = landing_entities.add_face(landing_points)
        landing_face.pushpull(thickness) if landing_face

        riser_face = landing_entities.add_face(riser_points)
        riser_face.pushpull(riser_thickness) if riser_face

        # Add glass railings to landing if specified
        if glass_railing != "None"
          add_glass_railings_to_landing(landing_entities, width, depth, thickness,
                                       glass_railing, turn_direction)
        end

        # Apply position transformation
        transform = Geom::Transformation.new(position)
        # If right turn, shift the landing 5" to align properly
        transform = Geom::Transformation.new([position[0], position[1] - 5, position[2]]) unless turn_direction == "Left"
        landing_group.transform!(transform)

        # Name the group
        landing_group.name = "Landing - #{width.round}\" x #{depth.round}\""

        # Store parameters as attributes
        landing_group.set_attribute("stair_generator", "width", width)
        landing_group.set_attribute("stair_generator", "depth", depth)
        landing_group.set_attribute("stair_generator", "thickness", thickness)
        landing_group.set_attribute("stair_generator", "glass_railing", glass_railing)
        landing_group.set_attribute("stair_generator", "segment_type", "landing")

        return landing_group
      end

      # Helper method to add glass railings to a stair segment
      def add_glass_railings_to_segment(entities, num_treads, tread_run, tread_width,stair_rise, glass_railing, glass_thickness, glass_inset, glass_height)

        model = Sketchup.active_model
        glass_material = Viewrail::SharedUtilities.get_or_create_glass_material(model)
        total_rise = (num_treads + 1) * stair_rise
        panel_extension = 1.0
        bottom_x_back = tread_run + 5
        bottom_z = 1.0
        top_x_end = num_treads * tread_run + 5 + panel_extension
        top_z = total_rise + glass_height
        left_y = tread_width - glass_inset - glass_thickness
        right_y = glass_inset

        # Define panel sides
        panel_sides = [
          {
            name: "Left",
            enabled: glass_railing == "Left" || glass_railing == "Both",
            y: glass_inset,
            y_min: left_y - 0.01,
            y_max: left_y + glass_thickness + 0.01,
            build_points: lambda {
              points = []
              points << [0, left_y, bottom_z]
              points << [bottom_x_back, left_y, bottom_z]
              points << [top_x_end, left_y, top_z - glass_height - (2*stair_rise)]
              points << [top_x_end, left_y, top_z]
              points << [0, left_y, bottom_z + glass_height]
              points
            }
          },
          {
            name: "Right",
            enabled: glass_railing == "Right" || glass_railing == "Both",
            y: tread_width - glass_inset - glass_thickness,
            y_max: right_y + glass_thickness + 0.01,
            y_min: right_y - 0.01,
            build_points: lambda {
              points = []
              points << [0, right_y, bottom_z]
              points << [bottom_x_back, right_y, bottom_z]
              points << [top_x_end, right_y, top_z - glass_height - (2*stair_rise)]
              points << [top_x_end, right_y, top_z]
              points << [0, right_y, bottom_z + glass_height]
              points
            }
          }
        ]

        panel_sides.each do |side|
          next unless side[:enabled]
          glass_points = side[:build_points].call
          face = entities.add_face(glass_points)
          if face
            face.pushpull(-glass_thickness)
            face.material = glass_material
            face.back_material = glass_material
            # Apply material to all faces
            entities.grep(Sketchup::Face).each do |f|
              if f.bounds.min.y >= side[:y_min] && f.bounds.max.y <= side[:y_max]
                f.material = glass_material
                f.back_material = glass_material
              end
            end
          end
        end
      end
      
      def add_glass_railings_to_landing(entities, width, depth, thickness, glass_railing, turn_direction)
        model = Sketchup.active_model
        glass_material = Viewrail::SharedUtilities.get_or_create_glass_material(model)
        glass_thickness = 0.5
        glass_inset = 1.0
        glass_height = 36.0
        corner_gap = 1.0

        # Determine which edges get railings based on turn direction and railing option
        # For L-shaped stairs, inner/outer refers to the inside/outside of the L
        edges_to_rail = []

        if turn_direction == "Left"
          case glass_railing
          when "Inner"
            #do nothing, for now
          when "Outer", "Both"
            edges_to_rail = ["front", "right"]    # Outer edges
          end
        else # Right turn
          case glass_railing
          when "Inner"
            #do nothing, for now
          when "Outer", "Both"
            edges_to_rail = ["back", "right"]   # Outer edges
          end
        end

        # Create glass panels for specified edges with corner gaps
        edges_to_rail.each do |edge|
          case edge
          when "front"
            glass_points = [
              [corner_gap, glass_inset, glass_height],
              [depth - corner_gap, glass_inset, glass_height],
              [depth - corner_gap, glass_inset, 0],
              [corner_gap, glass_inset, 0]
            ]
          when "back"
            glass_points = [
              [corner_gap, width - glass_inset - glass_thickness, glass_height],
              [depth - corner_gap, width - glass_inset - glass_thickness, glass_height],
              [depth - corner_gap, width - glass_inset - glass_thickness, 0],
              [corner_gap, width - glass_inset - glass_thickness, 0]
            ]
          when "left"
            glass_points = [
              [glass_inset, corner_gap, glass_height],
              [glass_inset, width - corner_gap, glass_height],
              [glass_inset, width - corner_gap, 0],
              [glass_inset, corner_gap, 0]
            ]
          when "right"
            glass_points = [
              [depth - glass_inset - glass_thickness, corner_gap, glass_height],
              [depth - glass_inset - glass_thickness, width - corner_gap, glass_height],
              [depth - glass_inset - glass_thickness, width - corner_gap, 0],
              [depth - glass_inset - glass_thickness, corner_gap, 0]
            ]
          end

          face = entities.add_face(glass_points)
          if face
            face.pushpull(glass_thickness)
            face.material = glass_material
            face.back_material = glass_material
            # Apply material to all faces of the panel
            entities.grep(Sketchup::Face).each do |f|
              bbox = f.bounds
              if bbox.min.z >= -0.01 && bbox.max.z <= glass_height + 0.01
                # Check if this face is part of the current glass panel
                case edge
                when "front", "back"
                  if (bbox.min.x >= corner_gap - 0.01) && (bbox.max.x <= depth - corner_gap + 0.01)
                    f.material = glass_material
                    f.back_material = glass_material
                  end
                when "left", "right"
                  if (bbox.min.y >= corner_gap - 0.01) && (bbox.max.y <= width - corner_gap + 0.01)
                    f.material = glass_material
                    f.back_material = glass_material
                  end
                end
              end
            end
          end
        end
      end
      
      def show_about
        UI.messagebox(
          "Stair Generator Extension v3.0.0\n\n" +
          "Creates parametric stairs for architectural visualization.\n\n" +
          "Features:\n" +
          "• Straight stairs with customizable dimensions\n" +
          "• L-shaped stairs with landing\n" +
          "• Automatic calculation of stair rise\n" +
          "• Building code compliance checking\n" +
          "• 3D stair geometry with glass railings\n" +
          "• Modular stair segments and landings\n\n" +
          "© 2025 Viewrail",
          MB_OK,
          "About Stair Generator"
        )
      end

    end

    # Create toolbar
    unless file_loaded?(__FILE__)

      # Create the toolbar
      toolbar = UI::Toolbar.new("Stair Generator")

      # Create commands for straight stairs
      cmd_stairs = UI::Command.new("Create Straight Stairs") {
        self.add_stair_menu
      }
      cmd_stairs.small_icon = "C:/Viewrail-Sketchup/plugins/stair_generator/icons/vr_stair_add.svg"
      cmd_stairs.large_icon = "C:/Viewrail-Sketchup/plugins/stair_generator/icons/vr_stair_add.svg"
      cmd_stairs.tooltip = "Create Straight Stairs"
      cmd_stairs.status_bar_text = "Create parametric straight stairs with customizable dimensions"
      cmd_stairs.menu_text = "Create Straight Stairs"

      # Create command for landing stairs
      cmd_landing_stairs = UI::Command.new("Create 90") {
        self.add_landing_stair_menu
      }
      cmd_landing_stairs.small_icon = "C:/Viewrail-Sketchup/plugins/stair_generator/icons/vr_stair_landing.svg"
      cmd_landing_stairs.large_icon = "C:/Viewrail-Sketchup/plugins/stair_generator/icons/vr_stair_landing.svg"
      cmd_landing_stairs.tooltip = "Create L-Shaped Stairs with Landing"
      cmd_landing_stairs.status_bar_text = "Create L-shaped stairs with landing platform"
      cmd_landing_stairs.menu_text = "Create 90 System Stairs"
      
      # Create command for About  
      cmd_about = UI::Command.new("About") {
        self.show_about
      }
      cmd_about.small_icon = "C:/Viewrail-Sketchup/plugins/stair_generator/icons/logo-black.svg"
      cmd_about.large_icon = "C:/Viewrail-Sketchup/plugins/stair_generator/icons/logo-black.svg"
      cmd_about.tooltip = "About Stair Generator"
      cmd_about.status_bar_text = "About Stair Generator Extension"
      cmd_about.menu_text = "About"

      # Add commands to toolbar
      toolbar = toolbar.add_item(cmd_stairs)
      toolbar = toolbar.add_item(cmd_landing_stairs)
      toolbar = toolbar.add_separator
      toolbar = toolbar.add_item(cmd_about)

      # Show the toolbar
      toolbar.show

      # Create menu
      menu = UI.menu("Extensions")
      stairs_menu = menu.add_submenu("Stair Generator")
      stairs_menu.add_item(cmd_stairs)
      stairs_menu.add_item(cmd_landing_stairs)
      stairs_menu.add_separator
      stairs_menu.add_item(cmd_about)

      # Create context menu items (right-click menu)
      UI.add_context_menu_handler do |context_menu|
        context_menu.add_separator
        stairs_context = context_menu.add_submenu("Stair Generator")
        stairs_context.add_item(cmd_stairs)
        stairs_context.add_item(cmd_landing_stairs)
      end

      file_loaded(__FILE__)
    end
  end
end