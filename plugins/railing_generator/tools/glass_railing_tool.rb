module Viewrail

  module RailingGenerator

    module Tools

      class GlassRailingTool

        def self.show
          last_values = {}

          # Create the HTML dialog
          dialog = UI::HtmlDialog.new(
            {
              :dialog_title => "Glass Railing Configuration",
              :preferences_key => "com.viewrail.railing_generator",
              :scrollable => false,
              :resizable => false,
              :width => 450,
              :height => 700,
              :left => 100,
              :top => 100,
              :style => UI::HtmlDialog::STYLE_DIALOG
            }
          )

          # Render the HTML content from ERB template
          begin
            renderer = Viewrail::SharedUtilities::FormRenderer.new(last_values)
            html_content = renderer.render("C:/Viewrail-Sketchup/plugins/railing_generator/forms/glass_railing_form.html.erb")
            dialog.set_html(html_content)
          rescue => e
            UI.messagebox("Error loading form template: #{e.message}\n\nPlease check that the template file exists.")
            return
          end

          # Add callbacks
          dialog.add_action_callback("create_glass_railing") do |action_context, params|
            begin
              values = JSON.parse(params, symbolize_names: true)
              tool = Viewrail::RailingGenerator::Tools::GlassRailingTool.new
              tool.configure_from_dialog(values)
              Sketchup.active_model.select_tool(tool)
            rescue => e
              puts "Error: #{e.message}"
              UI.messagebox("Error: #{e.message}")
            end
          end

          dialog.add_action_callback("cancel") do |action_context|
            dialog.close
          end

          dialog.show
        end

        def configure_from_dialog(params)
          # Apply configuration from dialog
          @railing_type = params[:railing_type] || "Hidden"
          @total_height = params[:railing_height] || 42.0
          @include_handrail = params[:include_caprail] || false
          @handrail_material = params[:caprail_material] || "Aluminum"

          # Adjust base channel visibility based on railing type
          @include_base_channel = (@railing_type == "Baserail")

          # Recalculate glass height based on configuration
          @glass_height = @include_handrail ?
            @total_height - @handrail_height + @glass_recess :
            @total_height

          # Use a case statement to set defaults based on railing type
          case @railing_type
          when "Hidden"
            @offset_distance = 1.0
          when "Baserail"
            @offset_distance = 2.0
          else
            @offset_distance = -1.0
          end

          puts "Glass Railing configured:"
          puts "  Type: #{@railing_type}"
          puts "  Height: #{@total_height}"
          puts "  Caprail: #{@include_handrail}"
          puts "  Caprail Material: #{@handrail_material}" if @include_handrail
        end

        def initialize
          puts "GlassRailingTool initialized"
          @points = []
          @current_point = nil
          @ip = Sketchup::InputPoint.new

          # Mode control - default to face selection
          @selection_mode = :face  # :face or :path
          @selected_faces = []
          @face_edges = []  # Store extracted edges from faces
          @hover_face = nil
          @hover_edge = nil

          # Default configurable variables
          @total_height = 42.0       # Total height including handrail
          @glass_thickness = 0.5     # Thickness of glass panels
          @max_panel_width = 48.0    # Maximum width of each panel
          @panel_gap = 1.0           # Gap between panels
          @offset_distance = 2.0     # Offset from drawn line

          # Handrail dimensions
          @include_handrail = true   # Default, will be overridden by dialog
          @handrail_width = 1.69
          @handrail_height = 1.35
          @glass_recess = 0.851      # How deep glass goes into handrail
          @corner_radius = 0.160

          # Base channel dimensions
          @include_base_channel = true  # Default, will be overridden by dialog
          @base_channel_width = 2.5
          @base_channel_height = 4.188
          @glass_bottom_offset = 1.188  # Height of glass bottom above floor
          @base_corner_radius = 0.0625

          # Calculate glass height based on handrail
          @glass_height = @include_handrail ?
            @total_height - @handrail_height + @glass_recess :
            @total_height
        end

        def onKeyDown(key, repeat, flags, view)
          if key == CONSTRAIN_MODIFIER_KEY  # Shift key
            # Toggle selection mode
            @selection_mode = @selection_mode == :face ? :path : :face

            # Clear current selections when switching modes
            if @selection_mode == :face
              @points.clear
              @current_point = nil
            else
              @selected_faces.clear
              @face_edges.clear
              @hover_face = nil
              @hover_edge = nil
            end

            update_status_text
            view.invalidate
          end
        end

        def onKeyUp(key, repeat, flags, view)
          # Handle key up if needed
        end

        def onLButtonDown(flags, x, y, view)
          if @selection_mode == :face
            # Face selection mode
            ph = view.pick_helper
            ph.do_pick(x, y)
            face = ph.best_picked

            if face.is_a?(Sketchup::Face)
              begin
                # Extract top horizontal edge
                top_edge_points = Viewrail::SharedUtilities.extract_top_edge_from_face(face)

                # Check if this face was already selected (toggle selection)
                existing_index = @selected_faces.index(face)
                if existing_index
                  @selected_faces.delete_at(existing_index)
                  @face_edges.delete_at(existing_index)
                else
                  @selected_faces << face
                  @face_edges << top_edge_points
                end

                update_status_text
                view.invalidate
              rescue => e
                UI.messagebox("Error: #{e.message}")
              end
            end
          else
            # Path drawing mode (original behavior)
            @ip.pick(view, x, y)
            if @ip.valid?
              pt = @ip.position
              @points << pt
              update_status_text
              view.invalidate
            end
          end
        end

        def draw(view)
          if @selection_mode == :face
            draw_face_selection_mode(view)
          else
            draw_path_mode(view)
          end
        end

        def draw_face_selection_mode(view)
          # Highlight selected faces
          @selected_faces.each_with_index do |face, index|
            # Draw the face in selection color using triangulated mesh
            view.drawing_color = [100, 200, 100, 128]  # Green semi-transparent

            # Get the face mesh for proper triangulation
            mesh = face.mesh
            mesh.polygons.each do |polygon|
              points = []
              polygon.each do |vertex_index|
                points << mesh.point_at(vertex_index.abs)
              end

              # Draw filled polygon
              view.draw(GL_POLYGON, points)
            end

            # Also draw the face edges for better visibility
            view.drawing_color = [50, 150, 50, 200]  # Darker green for edges
            view.line_width = 2
            face.edges.each do |edge|
              view.draw_line(edge.vertices[0].position, edge.vertices[1].position)
            end

            # Draw the top edge in blue
            if @face_edges[index]
              view.drawing_color = "blue"
              view.line_width = 4
              edge_points = @face_edges[index]
              view.draw_line(edge_points[0], edge_points[1])

              # Draw edge endpoints
              view.drawing_color = "red"
              view.draw_points(edge_points[0], 8)
              view.draw_points(edge_points[1], 8)
            end
          end

          # Highlight hover face
          if @hover_face && !@selected_faces.include?(@hover_face)
            view.drawing_color = [150, 150, 200, 64]  # Light blue semi-transparent

            # Get the face mesh for proper triangulation
            mesh = @hover_face.mesh
            mesh.polygons.each do |polygon|
              points = []
              polygon.each do |vertex_index|
                points << mesh.point_at(vertex_index.abs)
              end

              # Draw filled polygon
              view.draw(GL_POLYGON, points)
            end

            # Draw hover face edges for visibility
            view.drawing_color = [100, 100, 200, 128]  # Light blue edges
            view.line_width = 1
            @hover_face.edges.each do |edge|
              view.draw_line(edge.vertices[0].position, edge.vertices[1].position)
            end

            # Show the potential top edge
            if @hover_edge
              view.drawing_color = [100, 100, 255, 200]
              view.line_width = 3
              view.line_stipple = "-"
              view.draw_line(@hover_edge[0], @hover_edge[1])
              view.line_stipple = ""
            end
          end

          # Draw preview panels for selected faces
          draw_face_preview_panels(view)
        end

        def draw_path_mode(view)
          if @points.length > 0
            view.drawing_color = "blue"
            view.line_width = 4

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

        def draw_face_preview_panels(view)
          return if @face_edges.empty?

          # For each selected face edge, draw preview panels
          @face_edges.each_with_index do |edge_points, face_index|
            face = @selected_faces[face_index]
            next unless face && edge_points

            # Calculate offset direction (away from face normal)
            face_normal = face.normal
            offset_vector = face_normal.reverse
            offset_vector.normalize!

            # Create offset points for the edge
            start_pt = edge_points[0].offset(offset_vector, @offset_distance)
            end_pt = edge_points[1].offset(offset_vector, @offset_distance)

            # Draw preview panels along this edge
            segment_vector = end_pt - start_pt
            segment_length = segment_vector.length
            next if segment_length == 0
            segment_vector.normalize!

            # Set preview drawing style
            view.drawing_color = [100, 150, 200, 128]  # Semi-transparent blue
            view.line_width = 1
            view.line_stipple = "-"

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

                # Calculate panel corners
                panel_start = start_pt.offset(segment_vector, panel_start_distance)
                panel_end = start_pt.offset(segment_vector, panel_end_distance)

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
              end
            end

            view.line_stipple = ""
          end
        end

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
          if @selection_mode == :face
            # Face selection mode - track hover
            ph = view.pick_helper
            ph.do_pick(x, y)
            face = ph.best_picked

            if face.is_a?(Sketchup::Face)
              if face != @hover_face
                @hover_face = face
                # Try to extract the top edge for preview
                begin
                  @hover_edge = Viewrail::SharedUtilities.extract_top_edge_from_face(face)
                rescue
                  @hover_edge = nil
                end
                view.invalidate
              end
            else
              if @hover_face
                @hover_face = nil
                @hover_edge = nil
                view.invalidate
              end
            end

            view.tooltip = face.is_a?(Sketchup::Face) ? "Click to select face" : ""
          else
            # Path drawing mode (original behavior)
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
        end

        def activate
          @points = []
          @selected_faces = []
          @face_edges = []
          @selection_mode = :face  # Default to face selection
          update_status_text
        end

        def deactivate(view)
          view.invalidate
        end

        def onCancel(reason, view)
          if @selection_mode == :face
            if @selected_faces.empty?
              Sketchup.active_model.select_tool(nil)
            else
              @selected_faces.clear
              @face_edges.clear
              update_status_text
              view.invalidate
            end
          else
            if @points.empty?
              Sketchup.active_model.select_tool(nil)
            else
              @points.clear
              update_status_text
              view.invalidate
            end
          end
        end

        def onReturn(view)
          if @selection_mode == :face
            if @face_edges.length >= 1
              # Convert face edges to points for railing creation
              convert_face_edges_to_points
              create_glass_railings
              @selected_faces.clear
              @face_edges.clear
              @points.clear
              update_status_text
              view.invalidate
            end
          else
            if @points.length >= 2
              create_glass_railings
              @points.clear
              update_status_text
              view.invalidate
            end
          end
        end

        def update_status_text
          if @selection_mode == :face
            if @selected_faces.empty?
              Sketchup.status_text = "Click to select face(s) for railing | Shift: Switch to path drawing mode"
            else
              count = @selected_faces.length
              Sketchup.status_text = "#{count} face(s) selected | Enter: Create railing | Esc: Clear | Shift: Switch to path mode"
            end
          else
            if @points.empty?
              Sketchup.status_text = "Click to start drawing path | Shift: Switch to face selection mode"
            elsif @points.length == 1
              Sketchup.status_text = "Click next point | Enter: Finish | Esc: Cancel | Shift: Switch to face mode"
            else
              Sketchup.status_text = "Click to continue | Enter: Create railing | Esc: Clear | Shift: Switch to face mode"
            end
          end
        end

        # def extract_top_edge_from_face(face)
        #   # Find all edges of the face
        #   edges = face.edges

        #   # Filter for horizontal edges (perpendicular to Z axis)
        #   horizontal_edges = edges.select do |edge|
        #     edge_vector = edge.line[1]
        #     edge_vector.perpendicular?([0, 0, 1])
        #   end

        #   if horizontal_edges.empty?
        #     raise "Face has no horizontal edges"
        #   end

        #   # Find the edge with the highest Z coordinate
        #   top_edge = horizontal_edges.max_by do |edge|
        #     # Get average Z of the edge's vertices
        #     (edge.vertices[0].position.z + edge.vertices[1].position.z) / 2.0
        #   end

        #   # Verify the edge is truly horizontal (not angled)
        #   v1 = top_edge.vertices[0].position
        #   v2 = top_edge.vertices[1].position
        #   if (v1.z - v2.z).abs > 0.001  # Tolerance for floating point
        #     raise "Top edge is not horizontal (angled)"
        #   end

        #   # Return the two points of the edge
        #   [v1, v2]
        # end

        def convert_face_edges_to_points
          # Use the utility method to get face segments
          @face_segments = Viewrail::SharedUtilities.convert_face_edges_to_segments(
            @face_edges,
            @selected_faces,
            @offset_distance
          )

          # Clear points for compatibility with existing code
          @points.clear

          # Store the selection mode for later reference
          @selection_mode_backup = @selection_mode
        end

        def create_glass_railings
          # Handle face selection mode differently
          if @selection_mode == :face && defined?(@face_segments) && @face_segments && !@face_segments.empty?
            create_glass_railings_from_face_segments
            return
          end

          return if @points.length < 2

          model = Sketchup.active_model
          model.start_operation('Create Glass Railings', true)

          begin
            entities = model.active_entities
            main_group = entities.add_group
            main_group.name = "Glass Railing Assembly"

            # Get materials
            glass_material = Viewrail::SharedUtilities.get_or_create_glass_material(model)
            aluminum_material = Viewrail::SharedUtilities.get_or_create_aluminum_material(model)

            # Create glass panels first
            create_glass_panel_group(main_group, glass_material)

            # Create continuous handrail if enabled
            if @include_handrail
              create_continuous_handrail(main_group, aluminum_material)
            end

            # Create base channel first (bottom layer)
            if @include_base_channel
              create_continuous_base_channel(main_group, aluminum_material)
            end

            model.commit_operation
            Sketchup.active_model.select_tool(nil)

          rescue => e
            model.abort_operation
            UI.messagebox("Error creating glass railings: #{e.message}")
          end
        end

        def create_glass_railings_from_face_segments
          return if @face_segments.empty?

          model = Sketchup.active_model
          model.start_operation('Create Glass Railings from Faces', true)

          begin
            entities = model.active_entities
            main_group = entities.add_group
            main_group.name = "Glass Railing Assembly"

            # Get materials
            glass_material = Viewrail::SharedUtilities.get_or_create_glass_material(model)
            aluminum_material = Viewrail::SharedUtilities.get_or_create_aluminum_material(model)

            # Process each face segment separately
            @face_segments.each_with_index do |segment_points, index|
              @points = segment_points  # Temporarily set points for this segment

              segment_group = main_group.entities.add_group
              segment_group.name = "Glass Railing Face #{index + 1}"

              # Create glass panels for this segment
              create_glass_panel_group_for_segment(segment_group, glass_material, segment_points)

              # Create handrail for this segment if enabled
              if @include_handrail
                create_handrail_for_segment(segment_group, aluminum_material, segment_points)
              end

              # Create base channel for this segment if enabled
              if @include_base_channel
                create_base_channel_for_segment(segment_group, aluminum_material, segment_points)
              end
            end

            model.commit_operation
            Sketchup.active_model.select_tool(nil)

          rescue => e
            model.abort_operation
            UI.messagebox("Error creating glass railings: #{e.message}")
          ensure
            @face_segments = []
            @points.clear
          end
        end

        def create_glass_panel_group_for_segment(parent_group, glass_material, segment_points)
          start_pt = segment_points[0]
          end_pt = segment_points[1]

          create_glass_panels(parent_group, glass_material, start_pt, end_pt, true)
        end

        def create_handrail_for_segment(parent_group, aluminum_material, segment_points)
          handrail_group = parent_group.entities.add_group
          handrail_group.name = "Handrail"

          start_pt = segment_points[0]
          end_pt = segment_points[1]

          vec = end_pt - start_pt
          segment_length = vec.length
          return if segment_length == 0
          vec.normalize!

          # Position handrail at correct height
          handrail_start = Geom::Point3d.new(
            start_pt.x,
            start_pt.y,
            start_pt.z + @glass_height - (@glass_recess - @handrail_height/2.0)
          )

          # Create handrail profile
          profile = create_handrail_profile

          # Create transformation for profile
          z_axis = Geom::Vector3d.new(0, 0, 1)
          x_axis = vec
          y_axis = z_axis.cross(x_axis)

          # Create face at start point
          profile_points = profile.map do |p|
            transformed_pt = handrail_start.offset(y_axis, p[0])
            transformed_pt.offset(z_axis, p[1])
          end

          face = handrail_group.entities.add_face(profile_points)
          if face
            face.pushpull(-segment_length)

            # Apply aluminum material
            handrail_group.entities.grep(Sketchup::Face).each do |f|
              f.material = aluminum_material
              f.back_material = aluminum_material
            end

            # Soften edges for rounded appearance
            handrail_group.entities.grep(Sketchup::Edge).each do |edge|
              edge_vec = edge.line[1]
              if edge_vec.parallel?([0,0,1])
                edge.soft = true
                edge.smooth = true
              end
            end
          end
        end

        def create_base_channel_for_segment(parent_group, aluminum_material, segment_points)
          base_group = parent_group.entities.add_group
          base_group.name = "Base Channel"

          start_pt = segment_points[0]
          end_pt = segment_points[1]

          vec = end_pt - start_pt
          segment_length = vec.length
          return if segment_length == 0
          vec.normalize!

          # Create perpendicular vector
          perp_vec = Geom::Vector3d.new(-vec.y, vec.x, 0)

          # Create base channel cross-section
          half_width = @base_channel_width / 2.0

          # Simple rectangular profile
          profile_points = []
          profile_points << start_pt.offset(perp_vec, -half_width)
          profile_points << start_pt.offset(perp_vec, -half_width).offset([0,0,1], @base_channel_height)
          profile_points << start_pt.offset(perp_vec, half_width).offset([0,0,1], @base_channel_height)
          profile_points << start_pt.offset(perp_vec, half_width)

          face = base_group.entities.add_face(profile_points)
          if face
            face.pushpull(-segment_length, vec)

            # Apply aluminum material
            base_group.entities.grep(Sketchup::Face).each do |f|
              f.material = aluminum_material
              f.back_material = aluminum_material
            end

            # Soften vertical edges for rounded appearance
            base_group.entities.grep(Sketchup::Edge).each do |edge|
              edge_vec = edge.line[1]
              if edge_vec.parallel?([0,0,1])
                edge.soft = true
                edge.smooth = true
              end
            end
          end
        end

        private

        #new create glass panels function that takes a group, glass material, and start and end points

        def create_glass_panels(group, glass_material, start_pt, end_pt, segmented=false)
          work_group = nil
          if segmented
            work_group = group
          else
            work_group = group.entities.add_group
          end

          segment_vector = end_pt - start_pt
          segment_length = segment_vector.length
          return if segment_length == 0
          segment_vector.normalize!

          unless segmented
            if @selection_mode == :path
              perp_vector = Geom::Vector3d.new(-segment_vector.y, segment_vector.x, 0)
              perp_vector.normalize!
              start_pt = start_pt.offset(perp_vector, @offset_distance)
              end_pt = end_pt.offset(perp_vector, @offset_distance)
            end
          end

          available_length = segment_length - @panel_gap
          num_panels = calculate_panel_count(available_length)

          if num_panels > 0
            total_gaps = (num_panels - 1) * @panel_gap
            panel_width = (available_length - total_gaps) / num_panels

            (0...num_panels).each do |j|
              panel_start_distance = j * (panel_width + @panel_gap)
              panel_end_distance = panel_start_distance + panel_width

              panel_start = start_pt.offset(segment_vector, panel_start_distance)
              panel_end = start_pt.offset(segment_vector, panel_end_distance)

              glass_points = [
                panel_start,
                panel_end,
                [panel_end.x, panel_end.y, panel_end.z + @glass_height],
                [panel_start.x, panel_start.y, panel_start.z + @glass_height]
              ]

              face = work_group.entities.add_face(glass_points)
              if face
                face.pushpull(@glass_thickness)

                work_group.entities.grep(Sketchup::Face).each do |f|
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
        end # create_glass_panels

        def create_glass_panel_group(main_group, glass_material)
          (0...@points.length - 1).each do |i|
            start_pt = @points[i]
            end_pt = @points[i + 1]

            create_glass_panels(main_group, glass_material, start_pt, end_pt)
          end
        end

        def create_continuous_base_channel(main_group, aluminum_material)
          base_group = main_group.entities.add_group
          base_group.name = "Base Channel"

          # Calculate base channel path with offsets
          base_path = []
          @points.each_with_index do |pt, i|
            if i == 0
              # First point
              next_pt = @points[i + 1]
              vec = next_pt - pt
              vec.normalize!
              perp = Geom::Vector3d.new(-vec.y, vec.x, 0)

              # Check if we're in face mode (offset already applied)
              offset_pt = @selection_mode == :face ?
                pt.offset(perp, -@glass_thickness/2.0) :
                pt.offset(perp, @offset_distance - @glass_thickness/2.0)
              base_path << [offset_pt.x, offset_pt.y, offset_pt.z]
            elsif i == @points.length - 1
              # Last point
              prev_pt = @points[i - 1]
              vec = pt - prev_pt
              vec.normalize!
              perp = Geom::Vector3d.new(-vec.y, vec.x, 0)

              offset_pt = @selection_mode == :face ?
                pt.offset(perp, -@glass_thickness/2.0) :
                pt.offset(perp, @offset_distance - @glass_thickness/2.0)
              base_path << [offset_pt.x, offset_pt.y, offset_pt.z]
            else
              # Middle points - calculate miter
              prev_pt = @points[i - 1]
              next_pt = @points[i + 1]

              vec1 = pt - prev_pt
              vec1.normalize!
              vec2 = next_pt - pt
              vec2.normalize!

              # Calculate bisector for miter
              bisector = vec1 + vec2
              bisector.normalize!

              # Calculate perpendicular
              perp = Geom::Vector3d.new(-bisector.y, bisector.x, 0)

              # Calculate miter offset distance
              angle = vec1.angle_between(vec2)
              miter_factor = 1.0 / Math.cos(angle / 2.0)

              offset_distance = @selection_mode == :face ?
                (@glass_thickness/2.0) * miter_factor :
                (@offset_distance + @glass_thickness/2.0) * miter_factor

              offset_pt = pt.offset(perp, offset_distance)
              base_path << [offset_pt.x, offset_pt.y, offset_pt.z]
            end
          end

          # Extrude base channel along path
          (0...base_path.length - 1).each do |i|
            start_pt = Geom::Point3d.new(base_path[i])
            end_pt = Geom::Point3d.new(base_path[i + 1])

            vec = end_pt - start_pt
            segment_length = vec.length
            vec.normalize!

            # Create perpendicular vector
            perp_vec = Geom::Vector3d.new(-vec.y, vec.x, 0)

            # Create base channel cross-section
            half_width = @base_channel_width / 2.0

            # Simple rectangular profile (softened edges will handle rounding visually)
            profile_points = []
            profile_points << start_pt.offset(perp_vec, -half_width)
            profile_points << start_pt.offset(perp_vec, -half_width).offset([0,0,1], @base_channel_height)
            profile_points << start_pt.offset(perp_vec, half_width).offset([0,0,1], @base_channel_height)
            profile_points << start_pt.offset(perp_vec, half_width)

            face = base_group.entities.add_face(profile_points)
            if face
              face.pushpull(-segment_length, vec)

              # Apply aluminum material
              base_group.entities.grep(Sketchup::Face).each do |f|
                f.material = aluminum_material
                f.back_material = aluminum_material
              end

              # Soften vertical edges for rounded appearance
              base_group.entities.grep(Sketchup::Edge).each do |edge|
                # Soften vertical edges (those parallel to Z-axis)
                edge_vec = edge.line[1]
                if edge_vec.parallel?([0,0,1])
                  edge.soft = true
                  edge.smooth = true
                end
              end
            end
          end
        end

        def create_continuous_handrail(main_group, aluminum_material)
          handrail_group = main_group.entities.add_group
          handrail_group.name = "Continuous Handrail"

          # Calculate handrail path with offsets
          handrail_path = []
          @points.each_with_index do |pt, i|
            if i == 0
              # First point
              next_pt = @points[i + 1]
              vec = next_pt - pt
              vec.normalize!
              perp = Geom::Vector3d.new(-vec.y, vec.x, 0)

              offset_pt = @selection_mode == :face ?
                pt.offset(perp, -@glass_thickness/2.0) :
                pt.offset(perp, @offset_distance - @glass_thickness/2.0)
              handrail_path << [offset_pt.x, offset_pt.y, offset_pt.z + @glass_height - (@glass_recess - @handrail_height/2.0)]

            elsif i == @points.length - 1
              # Last point
              prev_pt = @points[i - 1]
              vec = pt - prev_pt
              vec.normalize!
              perp = Geom::Vector3d.new(-vec.y, vec.x, 0)

              offset_pt = @selection_mode == :face ?
                pt.offset(perp, -@glass_thickness/2.0) :
                pt.offset(perp, @offset_distance - @glass_thickness/2.0)
              handrail_path << [offset_pt.x, offset_pt.y, offset_pt.z + @glass_height - (@glass_recess - @handrail_height/2.0)]

            else
              # Middle points - calculate miter
              prev_pt = @points[i - 1]
              next_pt = @points[i + 1]

              vec1 = pt - prev_pt
              vec1.normalize!
              vec2 = next_pt - pt
              vec2.normalize!

              # Calculate bisector for miter
              bisector = vec1 + vec2
              bisector.normalize!

              # Calculate perpendicular
              perp = Geom::Vector3d.new(-bisector.y, bisector.x, 0)

              # Calculate miter offset distance
              angle = vec1.angle_between(vec2)
              miter_factor = 1.0 / Math.cos(angle / 2.0)

              offset_distance = @selection_mode == :face ?
                (@glass_thickness/2.0) * miter_factor :
                (@offset_distance + @glass_thickness/2.0) * miter_factor

              offset_pt = pt.offset(perp, offset_distance)
              handrail_path << [offset_pt.x, offset_pt.y, offset_pt.z + @glass_height - @glass_recess]
            end
          end

          # Create handrail profile with rounded edges
          profile = create_handrail_profile

          # Extrude along path
          (0...handrail_path.length - 1).each do |i|
            start_pt = Geom::Point3d.new(handrail_path[i])
            end_pt = Geom::Point3d.new(handrail_path[i + 1])

            vec = end_pt - start_pt
            vec.normalize!

            # Create transformation for profile at this segment
            z_axis = Geom::Vector3d.new(0, 0, 1)
            x_axis = vec
            y_axis = z_axis.cross(x_axis)

            # Create face at start point
            profile_points = profile.map do |p|
              transformed_pt = start_pt.offset(y_axis, p[0])
              transformed_pt.offset(z_axis, p[1])
            end

            face = handrail_group.entities.add_face(profile_points)
            if face
              face.pushpull(-start_pt.distance(end_pt))

              # Apply aluminum material
              handrail_group.entities.grep(Sketchup::Face).each do |f|
                f.material = aluminum_material
                f.back_material = aluminum_material
              end

              # Soften edges for rounded appearance
              handrail_group.entities.grep(Sketchup::Edge).each do |edge|
                # Soften edges that are part of the rounding
                if edge.vertices.any? { |v|
                  pt = v.position
                  # Check if this is a rounded corner vertex
                  dist_from_corners = [
                    pt.distance([start_pt.x - @handrail_width/2, start_pt.y, start_pt.z + @handrail_height/2]),
                    pt.distance([start_pt.x + @handrail_width/2, start_pt.y, start_pt.z + @handrail_height/2])
                  ].min
                  dist_from_corners < @corner_radius * 2
                }
                  edge.soft = true
                  edge.smooth = true
                end
              end
            end
          end
        end

        def create_handrail_profile
          # Create profile with rounded corners
          # Profile centered at origin, will be transformed to position

          profile = []
          half_width = @handrail_width / 2.0
          half_height = @handrail_height / 2.0

          # Bottom left (with rounding)
          profile << [-half_width + @corner_radius, -half_height]
          profile << [-half_width, -half_height + @corner_radius]

          # Top left (with rounding)
          profile << [-half_width, half_height - @corner_radius]
          profile << [-half_width + @corner_radius, half_height]

          # Top right (with rounding)
          profile << [half_width - @corner_radius, half_height]
          profile << [half_width, half_height - @corner_radius]

          # Bottom right (with rounding)
          profile << [half_width, -half_height + @corner_radius]
          profile << [half_width - @corner_radius, -half_height]

          profile
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

    end # class GlassRailingTool

  end # module RailingGenerator

end # module Viewrail
