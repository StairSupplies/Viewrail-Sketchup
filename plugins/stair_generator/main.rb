require 'erb'

module Viewrail
  module StairGenerator
    #Version 7 - Stair Generator with Glass Railing Tool
   
      # Glass Railing Tool
      class GlassRailingTool
        def initialize
          @points = []
          @current_point = nil
          @ip = Sketchup::InputPoint.new
          
          # Configurable variables
          @glass_height = 42.0      # Height of glass panels
          @glass_thickness = 0.5    # Thickness of glass panels
          @max_panel_width = 48.0   # Maximum width of each panel
          @panel_gap = 1.0          # Gap between panels
          @offset_distance = 2.0    # Offset from drawn line
          # Remove or comment out: @base_height = 0.0
        end
        
        def onLButtonDown(flags, x, y, view)
          @ip.pick(view, x, y)
          if @ip.valid?
            pt = @ip.position
            # Remove this line that forces Z to base_height:
            # pt.z = @base_height
            @points << pt
            update_status_text
            view.invalidate
          end
        end
        
        def draw(view)
          if @points.length > 0
            view.drawing_color = "blue"
            view.line_width = 2
            
            # Draw existing segments
            (0...@points.length - 1).each do |i|
              view.draw_line(@points[i], @points[i + 1])
            end
            
            # Draw preview line to current mouse position
            if @current_point && @points.length > 0
              view.drawing_color = [0, 128, 255]  # Light blue for preview
              view.line_stipple = "_"
              view.draw_line(@points.last, @current_point)
              view.line_stipple = ""
            end
            
            # Draw points
            view.drawing_color = "red"
            @points.each { |pt| view.draw_points(pt, 6) }
            
            # Draw preview glass panels
            draw_preview_panels(view)
          end
        end

        # Add this new method to draw preview panels
        def draw_preview_panels(view)
          # Create temporary points array including current mouse position
          preview_points = @points.dup
          preview_points << @current_point if @current_point && @points.length > 0
          
          return if preview_points.length < 2
          
          # Set preview drawing style
          view.drawing_color = [100, 150, 200, 128]  # Semi-transparent blue
          view.line_width = 1
          view.line_stipple = "-"
          
          # Draw preview panels for each segment
          (0...preview_points.length - 1).each do |i|
            start_pt = preview_points[i]
            end_pt = preview_points[i + 1]
            
            # Calculate segment properties
            segment_vector = end_pt - start_pt
            segment_length = segment_vector.length
            next if segment_length == 0
            segment_vector.normalize!
            
            # Calculate perpendicular vector for offset
            perp_vector = Geom::Vector3d.new(-segment_vector.y, segment_vector.x, 0)
            perp_vector.normalize!
            
            # Calculate number of panels
            available_length = segment_length - @panel_gap
            num_panels = calculate_panel_count(available_length)
            
            if num_panels > 0
              total_gaps = (num_panels - 1) * @panel_gap
              panel_width = (available_length - total_gaps) / num_panels
              
              # Draw each panel outline
              (0...num_panels).each do |j|
                panel_start_distance = j * (panel_width + @panel_gap)
                panel_end_distance = panel_start_distance + panel_width
                
                # Calculate panel corners with offset
                panel_start = start_pt.offset(segment_vector, panel_start_distance)
                panel_start = panel_start.offset(perp_vector, @offset_distance)
                
                panel_end = start_pt.offset(segment_vector, panel_end_distance)
                panel_end = panel_end.offset(perp_vector, @offset_distance)
                
                # Draw panel outline
                bottom_start = panel_start
                bottom_end = panel_end
                top_start = Geom::Point3d.new(panel_start.x, panel_start.y, panel_start.z + @glass_height)
                top_end = Geom::Point3d.new(panel_end.x, panel_end.y, panel_end.z + @glass_height)
                
                # Draw the four edges of each panel
                view.draw_line(bottom_start, bottom_end)
                view.draw_line(bottom_end, top_end)
                view.draw_line(top_end, top_start)
                view.draw_line(top_start, bottom_start)
                
                # Optionally draw diagonals for better visibility
                if i == preview_points.length - 2  # Only for the preview segment
                  view.drawing_color = [100, 150, 200, 64]  # Even more transparent
                  view.draw_line(bottom_start, top_end)
                  view.draw_line(bottom_end, top_start)
                  view.drawing_color = [100, 150, 200, 128]  # Reset color
                end
              end
            end
          end
          
          # Reset line stipple
          view.line_stipple = ""
        end
        
        def onMouseMove(flags, x, y, view)
          if flags & CONSTRAIN_MODIFIER_MASK > 0  # Shift key pressed
            # Lock to axis if we have a previous point
            if @points.length > 0
              @ip.pick(view, x, y, @ip)  # Pass previous InputPoint for inference
            else
              @ip.pick(view, x, y)
            end
          else
            @ip.pick(view, x, y)
          end
          
          if @ip.valid?
            @current_point = @ip.position
            view.tooltip = @ip.tooltip if @ip.tooltip
          end
          view.invalidate
        end
        
        def activate
          @points = []
          update_status_text
        end
        
        def deactivate(view)
          view.invalidate
        end
        
        def onCancel(reason, view)
          if @points.empty?
            Sketchup.active_model.select_tool(nil)
          else
            @points.clear
            update_status_text
            view.invalidate
          end
        end
        
        def onReturn(view)
          if @points.length >= 2
            create_glass_railings
            @points.clear
            update_status_text
            view.invalidate
          end
        end
        
        def update_status_text
          if @points.empty?
            Sketchup.status_text = "Click to start drawing glass railing path"
          elsif @points.length == 1
            Sketchup.status_text = "Click to add next point, Enter to finish, Esc to cancel"
          else
            Sketchup.status_text = "Click to continue, Enter to create railing, Esc to clear"
          end
        end
        
        def create_glass_railings
          return if @points.length < 2
          
          model = Sketchup.active_model
          model.start_operation('Create Glass Railings', true)
          
          begin
            entities = model.active_entities
            main_group = entities.add_group
            main_group.name = "Glass Railing Assembly"
            
            # Get or create glass material
            glass_material = StairGenerator.get_or_create_glass_material(model)
            
            # Process each segment
            (0...@points.length - 1).each do |i|
              start_pt = @points[i]
              end_pt = @points[i + 1]
              
              # Create a group for this segment
              segment_group = main_group.entities.add_group
              segment_group.name = "Glass Railing Segment #{i + 1}"
              
              # Calculate segment vector and perpendicular offset
              segment_vector = end_pt - start_pt
              segment_length = segment_vector.length
              segment_vector.normalize!
              
              # Calculate perpendicular vector for offset (in XY plane)
              perp_vector = Geom::Vector3d.new(-segment_vector.y, segment_vector.x, 0)
              perp_vector.normalize!
              
              # Calculate number of panels needed
              available_length = segment_length - @panel_gap  # Account for gap at corner
              num_panels = calculate_panel_count(available_length)
              
              if num_panels > 0
                # Calculate actual panel width
                total_gaps = (num_panels - 1) * @panel_gap
                panel_width = (available_length - total_gaps) / num_panels
                
                # Create panels for this segment
                (0...num_panels).each do |j|
                  # Calculate panel position along segment
                  panel_start_distance = j * (panel_width + @panel_gap)
                  panel_end_distance = panel_start_distance + panel_width
                  
                  # Calculate actual 3D positions with offset
                  panel_start = start_pt.offset(segment_vector, panel_start_distance)
                  panel_start = panel_start.offset(perp_vector, @offset_distance)
                  
                  panel_end = start_pt.offset(segment_vector, panel_end_distance)
                  panel_end = panel_end.offset(perp_vector, @offset_distance)
                  
                  # Create glass panel points
                  glass_points = [
                    panel_start,
                    panel_end,
                    [panel_end.x, panel_end.y, panel_end.z + @glass_height],
                    [panel_start.x, panel_start.y, panel_start.z + @glass_height]
                  ]
                  
                  # Create and extrude the glass face
                  face = segment_group.entities.add_face(glass_points)
                  if face
                    face.pushpull(@glass_thickness)
                    
                    # Apply glass material to all faces
                    segment_group.entities.grep(Sketchup::Face).each do |f|
                      # Check if this face is part of the panel we just created
                      bounds = f.bounds
                      if bounds.min.x >= [panel_start.x, panel_end.x].min - 0.1 &&
                         bounds.max.x <= [panel_start.x, panel_end.x].max + @glass_thickness + 0.1
                        f.material = glass_material
                        f.back_material = glass_material
                      end
                    end
                  end
                end
              end
            end
            
            model.commit_operation
            
            # Clear the tool
            Sketchup.active_model.select_tool(nil)
            
          rescue => e
            model.abort_operation
            UI.messagebox("Error creating glass railings: #{e.message}")
          end
        end
        
        def calculate_panel_count(length)
          return 0 if length <= 0
          
          # Start with minimum number of panels
          panels = (length / @max_panel_width).ceil
          
          # Check if panels would be too small
          while panels > 0
            total_gaps = (panels - 1) * @panel_gap
            panel_width = (length - total_gaps) / panels
            
            # If panel width is valid, return this count
            if panel_width <= @max_panel_width && panel_width > 0
              return panels
            end
            
            # Otherwise, try more panels
            panels += 1
            
            # Safety check to prevent infinite loop
            break if panels > 100
          end
          
          return panels
        end
      end # End of GlassRailingTool class
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

      # Initialize last values for landing stairs
      def last_landing_values
        @last_landing_values ||= {
          :num_treads_lower => 6,
          :num_treads_upper => 6,
          :header_to_wall => 144.0,  # Default 12 feet
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
      end

      # Form renderer class to handle ERB template
      class FormRenderer
        def initialize(last_values)
          @last_values = last_values
        end

        def render(template_name)
          # Get the path to the ERB template
          template_path = File.join(File.dirname(__FILE__), 'views', "#{template_name}.html.erb")

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
          renderer = FormRenderer.new(last_values)
          html_content = renderer.render('stair_form')
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
          create_stair_segment(params_with_width)

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
        # Create the HTML dialog for landing stairs
        dialog = UI::HtmlDialog.new(
          {
            :dialog_title => "Stair Form - 90",
            :preferences_key => "com.viewrail.landing_stair_generator",
            :scrollable => true,
            :resizable => true,
            :width => 650,
            :height => 700,
            :left => 100,
            :top => 50,
            :min_width => 625,
            :min_height => 650,
            :max_width => 750,
            :max_height => 1000,
            :style => UI::HtmlDialog::STYLE_DIALOG
          }
        )

        # Render the HTML content from ERB template
        begin
          renderer = FormRenderer.new(last_landing_values)
          html_content = renderer.render('90_stair_form')
          dialog.set_html(html_content)
        rescue => e
          UI.messagebox("Error loading landing form template: #{e.message}\n\nPlease check that the template file exists.")
          return
        end

        # Add callbacks
        dialog.add_action_callback("resize_dialog") do |action_context, params|
          dimensions = JSON.parse(params)
          dialog.set_size(dimensions["width"], dimensions["height"])
        end

        dialog.add_action_callback("create_landing_stairs") do |action_context, params|
          values = JSON.parse(params)

          # Store the values for next time
          last_landing_values[:num_treads_lower] = values["num_treads_lower"]
          last_landing_values[:num_treads_upper] = values["num_treads_upper"]
          last_landing_values[:header_to_wall] = values["header_to_wall"]
          last_landing_values[:tread_width_lower] = values["tread_width_lower"]
          last_landing_values[:tread_width_upper] = values["tread_width_upper"]
          last_landing_values[:landing_width] = values["landing_width"]
          last_landing_values[:landing_depth] = values["landing_depth"]
          last_landing_values[:tread_run] = values["tread_run"]
          last_landing_values[:stair_rise] = values["stair_rise"]
          last_landing_values[:total_rise] = values["total_rise"]
          last_landing_values[:turn_direction] = values["turn_direction"]
          last_landing_values[:glass_railing] = values["glass_railing"]

          dialog.close

          # Create the landing stairs
          create_stairs_with_landing(values)

          # Display parameters
          puts "Landing Stair parameters:"
          puts "  Lower Treads: #{values["num_treads_lower"]}"
          puts "  Upper Treads: #{values["num_treads_upper"]}"
          puts "  Header to Wall: #{values["header_to_wall"].round(2)}\""
          puts "  Tread Width Lower: #{values["tread_width_lower"].round(2)}\""
          puts "  Tread Width Upper: #{values["tread_width_upper"].round(2)}\""
          puts "  Landing: #{values["landing_width"].round(2)}\" x #{values["landing_depth"].round(2)}\""
          puts "  Turn Direction: #{values["turn_direction"]}"
          puts "  Stair Rise: #{values["stair_rise"].round(2)}\""
          puts "  Total Rise: #{values["total_rise"].round(2)}\""
          puts "  Glass Railing: #{values["glass_railing"]}"
        end

        dialog.add_action_callback("cancel") do |action_context|
          dialog.close
        end

        dialog.show
      end

      # Create stairs with landing (orchestrator method)
      def create_stairs_with_landing(params)
        model = Sketchup.active_model

        # Start operation for undo functionality
        model.start_operation('Create 90', true)

        begin
          # Calculate landing height
          landing_height = (params["num_treads_lower"] + 1) * params["stair_rise"]

          # Create lower stairs segment
          lower_params = {
            "num_treads" => params["num_treads_lower"],
            "tread_run" => params["tread_run"],
            "tread_width" => params["tread_width_lower"],
            "stair_rise" => params["stair_rise"],
            "glass_railing" => params["glass_railing"],
            "segment_name" => "Lower Stairs"
          }

          # Determine glass railing for lower segment based on turn direction
          if params["glass_railing"] != "None"
            if params["turn_direction"] == "Left"
              # For left turn, adjust railings
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

          lower_stairs = create_stair_segment(lower_params, [0, 0, 0])

          # Calculate landing position (at the end of lower stairs)
          landing_x = params["num_treads_lower"] * params["tread_run"]
          landing_y = 0
          landing_z = landing_height

          # Create landing
          landing = create_landing(
            {
              "width" => params["landing_width"],
              "depth" => params["landing_depth"],
              "thickness" => params["stair_rise"] - 1, # Same as tread thickness
              "glass_railing" => params["glass_railing"],
              "turn_direction" => params["turn_direction"]
            },
            [landing_x, landing_y, landing_z]
          )

          # Calculate upper stairs position based on turn direction
          if params["turn_direction"] == "Left"
            # Left turn: upper stairs go in positive Y direction
            upper_start = [
              landing_x + params["landing_depth"],
              landing_y + params["landing_depth"],
              landing_z
            ]
            upper_rotation = 90.degrees
          else
            # Right turn: upper stairs go in positive (switch to negative) Y direction
            upper_start = [
              landing_x,
              landing_y,
              landing_z
            ]
            upper_rotation = -90.degrees
          end

          # Create upper stairs segment
          upper_params = {
            "num_treads" => params["num_treads_upper"],
            "tread_run" => params["tread_run"],
            "tread_width" => params["tread_width_upper"],
            "stair_rise" => params["stair_rise"],
            "glass_railing" => params["glass_railing"],
            "segment_name" => "Upper Stairs"
          }

          # Determine glass railing for upper segment
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

          upper_stairs = create_stair_segment(upper_params, upper_start)

          # Rotate upper stairs for L-shape
          if upper_stairs
            rotation_point = Geom::Point3d.new(upper_start)
            rotation_axis = Geom::Vector3d.new(0, 0, 1)
            rotation = Geom::Transformation.rotation(rotation_point, rotation_axis, upper_rotation)
            upper_stairs.transform!(rotation)
          end

          # Add all groups to master group
          stair_group = model.active_entities.add_group([lower_stairs, landing, upper_stairs])
          # stair_component = stair_group.to_component

          # Commit the operation
          model.commit_operation

          # Zoom to fit
          Sketchup.active_model.active_view.zoom_extents

        rescue => e
          model.abort_operation
          UI.messagebox("Error creating landing stairs: #{e.message}")
        end
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
      def add_glass_railings_to_segment(entities, num_treads, tread_run, tread_width,
                                       stair_rise, glass_railing, glass_thickness, glass_inset, glass_height)

        # Create or find glass material
        model = Sketchup.active_model
        materials = model.materials
        glass_material = materials["Glass_Transparent"]
        if !glass_material
          glass_material = materials.add("Glass_Transparent")
          glass_material.color = [200, 220, 240, 128]
          glass_material.alpha = 0.3
        end

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

      # Helper method to add glass railings to landing
      def get_or_create_glass_material(model)
        materials = model.materials
        glass_material = materials["Glass_Transparent"]
        if !glass_material
          glass_material = materials.add("Glass_Transparent")
          glass_material.color = [200, 220, 240, 128]  # Light blue with transparency
          glass_material.alpha = 0.3  # 30% opacity
        end
        glass_material
      end
      
      def add_glass_railings_to_landing(entities, width, depth, thickness, glass_railing, turn_direction)
        # Create glass material
        model = Sketchup.active_model
        materials = model.materials
        glass_material = materials["Glass_Transparent"]
        if !glass_material
          glass_material = materials.add("Glass_Transparent")
          glass_material.color = [200, 220, 240, 128]
          glass_material.alpha = 0.3
        end

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
      
      # Create command for glass railing tool
      cmd_glass_railing = UI::Command.new("Glass Railing") {
        Sketchup.active_model.select_tool(StairGenerator::GlassRailingTool.new)
      }
      cmd_glass_railing.small_icon = "C:/Viewrail-Sketchup/plugins/stair_generator/icons/vr_glass_24.png"
      cmd_glass_railing.large_icon = "C:/Viewrail-Sketchup/plugins/stair_generator/icons/vr_glass_32.png"
      cmd_glass_railing.tooltip = "Create Glass Railing"
      cmd_glass_railing.status_bar_text = "Draw a path to create glass railings"
      cmd_glass_railing.menu_text = "Glass Railing"
      
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
      toolbar = toolbar.add_item(cmd_glass_railing)
      toolbar = toolbar.add_separator
      toolbar = toolbar.add_item(cmd_about)

      # Show the toolbar
      toolbar.show

      # Create menu
      menu = UI.menu("Extensions")
      stairs_menu = menu.add_submenu("Stair Generator")
      stairs_menu.add_item(cmd_stairs)
      stairs_menu.add_item(cmd_landing_stairs)
      stairs_menu.add_item(cmd_glass_railing)
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