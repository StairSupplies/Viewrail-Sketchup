# railing_generator/tools/glass_railing_tool.rb
module Viewrail
  module RailingGenerator
    module Tools
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
            glass_material = Viewrail::SharedUtilities.get_or_create_glass_material(model)
            
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
      end
    end
  end
end