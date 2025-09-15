require 'erb'

module Viewrail
  module StairGenerator
    #Version 5 - Stair Generator with Glass Railings
    class << self

      # Initialize last values at class level
      def last_values
        @last_values ||= {
          :num_treads => 13,
          :tread_run => 11.0,
          :total_tread_run => 143.0,
          :stair_rise => 7.5,
          :total_rise => 105.0,
          :glass_railing => "None"
        }
      end

      # Form renderer class to handle ERB template
      class FormRenderer
        def initialize(last_values)
          @last_values = last_values
        end
        
        def render
          # Get the path to the ERB template
          # Adjust this path based on your file structure
          template_path = File.join(File.dirname(__FILE__), 'views', 'stair_form.html.erb')
          
          # Alternative path if you want to keep it in the same directory
          # template_path = File.join(File.dirname(__FILE__), 'stair_form.html.erb')
          
          # Read the template file
          template_string = File.read(template_path)
          
          # Create ERB object and render with current binding
          erb = ERB.new(template_string)
          erb.result(binding)
        end
      end

      def add_stair_menu
        # Create the HTML dialog
        dialog = UI::HtmlDialog.new(
          {
            :dialog_title => "Stair Form - Straight V2",
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
          renderer = FormRenderer.new(last_values)
          html_content = renderer.render
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
          create_stairs_geometry(values)

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

      def create_stairs_geometry(params)
        # Get the active model and entities
        model = Sketchup.active_model
        entities = model.active_entities

        # Extract parameters
        num_treads = params["num_treads"]
        tread_run = params["tread_run"]
        stair_rise = params["stair_rise"]
        total_rise = params["total_rise"]
        total_tread_run = params["total_tread_run"]
        glass_railing = params["glass_railing"]
        reveal = 1

        # Fixed dimensions
        tread_width = 36.0  # Standard stair width
        tread_thickness = stair_rise - reveal # Tread thickness
        riser_thickness = 1.0  # Riser thickness

        # Glass panel dimensions
        glass_thickness = 0.5  # Glass panel thickness (variable for future use)
        glass_inset = 1.0      # Inset from tread edges
        glass_height = 36.0    # Height above tread nose

        # Start operation for undo functionality
        model.start_operation('Create Stairs', true)

        # Create a group for the entire staircase
        stairs_group = entities.add_group
        stairs_entities = stairs_group.entities

        begin
          # Create each step
          (1..num_treads).each do |i|
            # Calculate position for this step
            x_position = (i - 1) * tread_run
            z_position = i * stair_rise

            puts "z position: #{z_position}"

            # Create tread (horizontal part) - skip last tread
            stack_overhang = 5
            if i <= num_treads
              tread_points = [
                [x_position,                                        0, z_position],
                [x_position + tread_run + stack_overhang,           0, z_position],
                [x_position + tread_run + stack_overhang, tread_width, z_position],
                [x_position,                              tread_width, z_position]
              ]
              tread_face = stairs_entities.add_face(tread_points)
              tread_face.pushpull(-tread_thickness) if tread_face

              nosing_value = 0.75
              riser_points = [
                [x_position + nosing_value,                             nosing_value, z_position - tread_thickness],
                [x_position + tread_run + stack_overhang,               nosing_value, z_position - tread_thickness],
                [x_position + tread_run + stack_overhang, tread_width - nosing_value, z_position - tread_thickness],
                [x_position + nosing_value,               tread_width - nosing_value, z_position - tread_thickness]
              ]
              riser_face = stairs_entities.add_face(riser_points)
              riser_face.pushpull(riser_thickness) if riser_face
            end
          end #treads loop

          # Create glass railings based on selection
          if glass_railing != "None"
            # Create or find glass material
            materials = model.materials
            glass_material = materials["Glass_Transparent"]
            if !glass_material
              glass_material = materials.add("Glass_Transparent")
              glass_material.color = [200, 220, 240, 128]  # Light blue with transparency
              glass_material.alpha = 0.3  # 30% opacity
            end

            # Glass panel extends 1" beyond last tread
            panel_extension = 1.0
            # Bottom edge starts 1" above floor, aligned with back of first tread
            bottom_x_back = tread_run + 5  # Back of first tread
            bottom_z = 1.0  # 1" above floor
            # Top edge extends 1" beyond last tread
            top_x_end = num_treads * tread_run + 5 + panel_extension
            top_z = total_rise + glass_height
            left_y = tread_width - glass_inset - glass_thickness
            right_y = glass_inset

            # Define panel sides and their properties
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
                  points << [top_x_end, left_y, top_z ]
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
              face = stairs_entities.add_face(glass_points)
              if face
                face.pushpull(-glass_thickness)
                face.material = glass_material
                face.back_material = glass_material
                # Apply material to all faces of the extruded glass
                stairs_entities.grep(Sketchup::Face).each do |f|
                  if f.bounds.min.y >= side[:y_min] && f.bounds.max.y <= side[:y_max]
                    f.material = glass_material
                    f.back_material = glass_material
                  end
                end
              end
            end
          end

          # Name the group
          stairs_group.name = "Stairs - #{num_treads} treads"

          # Store stair parameters as attributes on the group
          stairs_group.set_attribute("stair_generator", "num_treads", num_treads)
          stairs_group.set_attribute("stair_generator", "tread_run", tread_run)
          stairs_group.set_attribute("stair_generator", "total_tread_run", total_tread_run)
          stairs_group.set_attribute("stair_generator", "stair_rise", stair_rise)
          stairs_group.set_attribute("stair_generator", "total_rise", total_rise)
          stairs_group.set_attribute("stair_generator", "glass_railing", glass_railing)

          # Commit the operation
          model.commit_operation

          # Zoom to fit the new stairs
          Sketchup.active_model.active_view.zoom_extents

        rescue => e
          # If there's an error, abort the operation
          model.abort_operation
          UI.messagebox("Error creating stairs: #{e.message}")
        end
      end

      def show_about
        UI.messagebox(
          "Stair Generator Extension v2.0.0\n\n" +
          "Creates parametric stairs for architectural visualization.\n\n" +
          "Features:\n" +
          "• Customizable tread and rise dimensions\n" +
          "• Automatic calculation of stair rise\n" +
          "• Building code compliance checking\n" +
          "• 3D stair geometry with glass railings\n" +
          "• Transparent glass side panels\n\n" +
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

      # Create commands
      cmd_stairs = UI::Command.new("Create Stairs") {
        self.add_stair_menu
      }
      cmd_stairs.small_icon = "C:/Viewrail-Sketchup/plugins/stair_generator/icons/vr_stair_add.svg"
      cmd_stairs.large_icon = "C:/Viewrail-Sketchup/plugins/stair_generator/icons/vr_stair_add.svg"
      cmd_stairs.tooltip = "Create Stairs"
      cmd_stairs.status_bar_text = "Create parametric stairs with customizable dimensions"
      cmd_stairs.menu_text = "Create Stairs"

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
      toolbar = toolbar.add_separator
      toolbar = toolbar.add_item(cmd_about)

      # Show the toolbar
      toolbar.show

      # Create menu
      menu = UI.menu("Extensions")
      stairs_menu = menu.add_submenu("Stair Generator")
      stairs_menu.add_item(cmd_stairs)
      stairs_menu.add_separator
      stairs_menu.add_item(cmd_about)

      # Create context menu items (right-click menu)
      UI.add_context_menu_handler do |context_menu|
        context_menu.add_separator
        stairs_context = context_menu.add_submenu("Stair Generator")
        stairs_context.add_item(cmd_stairs)
      end

      file_loaded(__FILE__)
    end
  end
end