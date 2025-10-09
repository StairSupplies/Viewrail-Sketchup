module Viewrail

  module RailingGenerator

    module Tools

      class GlassRailingTool

        def self.show
          last_values = {}

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

          begin
            renderer = Viewrail::SharedUtilities::FormRenderer.new(last_values)
            html_content = renderer.render("C:/Viewrail-Sketchup/plugins/railing_generator/forms/glass_railing_form.html.erb")
            dialog.set_html(html_content)
          rescue => e
            UI.messagebox("Error loading form template: #{e.message}\n\nPlease check that the template file exists.")
            return
          end

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
        end # self.show

        def configure_from_dialog(params)
          @railing_type = params[:railing_type] || "Hidden"
          @total_height = params[:railing_height] || 42.0
          @include_handrail = params[:include_caprail] || false
          @handrail_material = params[:caprail_material] || "Aluminum"

          @include_base_channel = (@railing_type == "Baserail")

          @glass_height = @include_handrail ?
            @total_height - @handrail_height + @glass_recess :
            @total_height

          case @railing_type
          when "Hidden"
            @offset_distance = 1.0
          when "Baserail"
            @offset_distance = 2.0
          else
            @offset_distance = -1.0
          end

        end # configure_from_dialog

        def initialize

          @selected_faces = []
          @face_edges = []
          @hover_face = nil
          @hover_edge = nil

          @total_height = 42.0
          @glass_thickness = 0.5
          @max_panel_width = 48.0
          @panel_gap = 1.0
          @offset_distance = 2.0

          @include_handrail = true
          @handrail_width = 1.69
          @handrail_height = 1.35
          @glass_recess = 0.851
          @corner_radius = 0.160

          @include_base_channel = true
          @base_channel_width = 2.5
          @base_channel_height = 4.188
          @glass_bottom_offset = 1.188
          @base_corner_radius = 0.0625

          @glass_height = @include_handrail ?
            @total_height - @handrail_height + @glass_recess :
            @total_height
        end # initialize

        def onLButtonDown(flags, x, y, view)

          ph = view.pick_helper
          ph.do_pick(x, y)
          face = ph.best_picked

          if face.is_a?(Sketchup::Face)
            begin
              top_edge_points = Viewrail::SharedUtilities.extract_top_edge_from_face(face)

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
        end # onLButtonDown

        def draw(view)
            draw_face_selection_mode(view)
        end # draw

        def draw_face_selection_mode(view)
          @selected_faces.each_with_index do |face, index|
            view.drawing_color = [100, 200, 100, 128]  # Green semi-transparent

            mesh = face.mesh
            mesh.polygons.each do |polygon|
              points = []
              polygon.each do |vertex_index|
                points << mesh.point_at(vertex_index.abs)
              end

              # Draw filled polygon
              view.draw(GL_POLYGON, points)
            end

            view.drawing_color = [50, 150, 50, 200]  # Darker green for edges
            view.line_width = 2
            face.edges.each do |edge|
              view.draw_line(edge.vertices[0].position, edge.vertices[1].position)
            end

            if @face_edges[index]
              view.drawing_color = "blue"
              view.line_width = 4
              edge_points = @face_edges[index]
              view.draw_line(edge_points[0], edge_points[1])

              view.drawing_color = "red"
              view.draw_points(edge_points[0], 8)
              view.draw_points(edge_points[1], 8)
            end
          end

          if @hover_face && !@selected_faces.include?(@hover_face)
            view.drawing_color = [150, 150, 200, 64]  # Light blue semi-transparent

            mesh = @hover_face.mesh
            mesh.polygons.each do |polygon|
              points = []
              polygon.each do |vertex_index|
                points << mesh.point_at(vertex_index.abs)
              end

              view.draw(GL_POLYGON, points)
            end

            view.drawing_color = [100, 100, 200, 128]  # Light blue edges
            view.line_width = 1
            @hover_face.edges.each do |edge|
              view.draw_line(edge.vertices[0].position, edge.vertices[1].position)
            end

            if @hover_edge
              view.drawing_color = [100, 100, 255, 200]
              view.line_width = 3
              view.line_stipple = "-"
              view.draw_line(@hover_edge[0], @hover_edge[1])
              view.line_stipple = ""
            end
          end

          draw_face_preview_panels(view)
        end # draw_face_selection_mode

        def draw_face_preview_panels(view)
          return if @face_edges.nil?

          @face_edges.each_with_index do |edge_points, face_index|
            face = @selected_faces[face_index]
            next unless face && edge_points

            face_normal = face.normal
            offset_vector = face_normal.reverse
            offset_vector.normalize!

            start_pt = edge_points[0].offset(offset_vector, @offset_distance)
            end_pt = edge_points[1].offset(offset_vector, @offset_distance)

            segment_vector = end_pt - start_pt
            segment_length = segment_vector.length
            next if segment_length == 0
            segment_vector.normalize!

            view.drawing_color = [100, 150, 200, 128]  # Semi-transparent blue
            view.line_width = 1
            view.line_stipple = "-"

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

                bottom_start = panel_start
                bottom_end = panel_end
                top_start = Geom::Point3d.new(panel_start.x, panel_start.y, panel_start.z + @glass_height)
                top_end = Geom::Point3d.new(panel_end.x, panel_end.y, panel_end.z + @glass_height)

                view.draw_line(bottom_start, bottom_end)
                view.draw_line(bottom_end, top_end)
                view.draw_line(top_end, top_start)
                view.draw_line(top_start, bottom_start)
              end
            end

            view.line_stipple = ""
          end
        end # draw_face_preview_panels

        def onMouseMove(flags, x, y, view)
          ph = view.pick_helper
          ph.do_pick(x, y)
          face = ph.best_picked

          if face.is_a?(Sketchup::Face)
            if face != @hover_face
              @hover_face = face
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
        end # onMouseMove

        def activate
          @selected_faces = []
          @face_edges = []
          update_status_text
        end # activate

        def deactivate(view)
          view.invalidate
        end # deactivate

        def onCancel(reason, view)
          if @selected_faces.nil?
            Sketchup.active_model.select_tool(nil)
          else
            @selected_faces.clear
            @face_edges.clear
            update_status_text
            view.invalidate
          end
        end # onCancel

        def onReturn(view)
          if @face_edges.length >= 1
            # Group the current selection into adjacent face sets and process each set
            groups = group_adjacent_face_sets(@face_edges, @selected_faces)
            groups.each do |group|
              # Load this set into the existing workflow
              @face_edges = group[:edges]
              @selected_faces = group[:faces]

              convert_face_edges_to_points
              create_glass_railings

              # Reset between groups to preserve original behavior
              @selected_faces.clear
              @face_edges.clear
              update_status_text
              view.invalidate
            end
          end
        end # onReturn

        def update_status_text
          if @selected_faces.nil?
            Sketchup.status_text = "Click to select face(s) for railing | Esc: Cancel"
          else
            count = @selected_faces.length
            Sketchup.status_text = "#{count} face(s) selected | Enter: Create railing | Esc: Clear"
          end
        end # update_status_text

        private

        # Group selected faces into collections where each group consists of
        # faces whose extracted top-edge segments share endpoints (adjacent).
        # Returns: [{ edges: [[p0,p1], ...], faces: [faceA, ...] }, ...]
        def group_adjacent_face_sets(face_edges, selected_faces, tolerance = 0.001.inch)
          return [] if face_edges.nil? || face_edges.empty? || selected_faces.nil? || selected_faces.empty?

          n = face_edges.length
          return [{ edges: face_edges.dup, faces: selected_faces.dup }] if n == 1

          key_for = lambda do |pt|
            [
              (pt.x / tolerance).round,
              (pt.y / tolerance).round,
              (pt.z / tolerance).round
            ]
          end

          # Precompute endpoint keys
          endpoint_keys = face_edges.map { |a, b| [key_for.call(a), key_for.call(b)] }

          # Build adjacency lists: segments are adjacent if any endpoints match (within tolerance)
          adj = Array.new(n) { [] }
          (0...n).each do |i|
            ki0, ki1 = endpoint_keys[i]
            (i + 1...n).each do |j|
              kj0, kj1 = endpoint_keys[j]
              if ki0 == kj0 || ki0 == kj1 || ki1 == kj0 || ki1 == kj1
                adj[i] << j
                adj[j] << i
              end
            end
          end

          # Connected components via BFS
          visited = Array.new(n, false)
          groups = []
          (0...n).each do |i|
            next if visited[i]
            queue = [i]
            visited[i] = true
            comp = []
            until queue.empty?
              v = queue.shift
              comp << v
              adj[v].each do |w|
                next if visited[w]
                visited[w] = true
                queue << w
              end
            end

            groups << {
              edges: comp.map { |idx| face_edges[idx] },
              faces: comp.map { |idx| selected_faces[idx] }
            }
          end

          groups
        end

        def convert_face_edges_to_points
          # Sort the user selections into a continuous order before building
          sorted_edges, sorted_faces = Viewrail::SharedUtilities.sort_face_edges_and_faces(@face_edges, @selected_faces)
          # Use the existing utility method to get face segments from the sorted data
          @face_segments = Viewrail::SharedUtilities.create_offset_line_from_edges(
            sorted_edges,
            sorted_faces,
            @offset_distance
          )
        end # convert_face_edges_to_points

        def create_glass_railings
          if defined?(@face_segments) && !@face_segments.nil? 
            if !@face_segments.nil?
              create_glass_railings_from_face_segments
              return
            end
          end
        end # create_glass_railings

        def create_glass_railings_from_face_segments
          return if @face_segments.nil?

          model = Sketchup.active_model
          model.start_operation('Create Glass Railings from Faces', true)

          begin
            entities = model.active_entities
            main_group = entities.add_group
            main_group.name = "Glass Railing Assembly"

            # Get materials
            glass_material = Viewrail::SharedUtilities.get_or_add_material(:glass)
            aluminum_material = Viewrail::SharedUtilities.get_or_add_material(:aluminum)

            # Process each face segment separately
            @face_segments.each_with_index do |segment_points, index|
              segment_group = main_group.entities.add_group
              segment_group.name = "Glass Railing Face #{index + 1}"
              # Create glass panels for this segment
              create_glass_panel_group_for_segment(segment_group, glass_material, segment_points)
              puts "-- Created glass panels for segment #{index + 1}"
            end

            if @include_base_channel
              create_continuous_base_channel(main_group, aluminum_material)
              puts "-- Created continuous base channel"
            end

            if @include_handrail
              z_adjust = @glass_height - (@glass_recess - @handrail_height/2.0)
              create_continuous_handrail(main_group, aluminum_material, [0,0,z_adjust])
              puts "-- Created continuous handrail"
            end


            model.commit_operation
            Sketchup.active_model.select_tool(nil)

          rescue => e
            model.abort_operation
            UI.messagebox("Error creating glass railings: #{e.message}")
          ensure
            @face_segments = []
          end
        end # create_glass_railings_from_face_segments

        def create_glass_panel_group_for_segment(parent_group, glass_material, segment_points)
          start_pt = segment_points[0]
          end_pt = segment_points[1]
          create_glass_panels(parent_group, glass_material, start_pt, end_pt, true)
        end # create_glass_panel_group_for_segment

        def create_glass_panels(group, glass_material, start_pt, end_pt, segmented=false)
          glass_group = nil
          if segmented
            glass_group = group
          else
            glass_group = group.entities.add_group
          end

          segment_vector = end_pt - start_pt
          segment_length = segment_vector.length
          return if segment_length == 0
          segment_vector.normalize!

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

              face = glass_group.entities.add_face(glass_points)
              if face
                face.pushpull(@glass_thickness)

                glass_group.entities.grep(Sketchup::Face).each do |f|
                  f.material = glass_material
                  f.back_material = glass_material
                end
              end
            end
          end
        end # create_glass_panels

        def create_handrail_profile
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
        end # create_handrail_profile

        def create_base_channel_profile
          half_width = @base_channel_width / 2.0
          
          profile = []
          profile << [-half_width, 0]
          profile << [-half_width, @base_channel_height]
          profile << [half_width, @base_channel_height]
          profile << [half_width, 0]
          
          profile
        end

        def calculate_panel_count(length)
          return 0 if length <= 0

          panels = (length / @max_panel_width).ceil

          while panels > 0
            total_gaps = (panels - 1) * @panel_gap
            panel_width = (length - total_gaps) / panels

            if panel_width <= @max_panel_width && panel_width > 0
              return panels
            end

            panels += 1

            break if panels > 100
          end

          return panels
        end # calculate_panel_count

        def create_continuous_base_channel(main_group, aluminum_material, adjust_position = [0,0,0])
          base_group = main_group.entities.add_group
          base_group.name = "Base Channel"

          # Use offset distance to create segments, then convert them to a path
          baserail_center_offset = @offset_distance - (@glass_thickness / 2.0)
          # Sort selections to build a continuous path for Follow Me
          sorted_edges, sorted_faces = Viewrail::SharedUtilities.sort_face_edges_and_faces(@face_edges, @selected_faces)
          path_edges = Viewrail::SharedUtilities.create_offset_path(sorted_edges, sorted_faces, base_group, baserail_center_offset)
          
          # Get starting point and direction for profile orientation
          first_edge = path_edges.first
          first_segment = [first_edge.start.position, first_edge.end.position]
          start_pt = first_segment[0]
          perp_vec = calculate_path_vectors(first_segment)
          
          # Adjust position based on user input
          start_pt.x += adjust_position[0]
          start_pt.y += adjust_position[1]
          start_pt.z += adjust_position[2]

          # Create base channel profile at the start of the path
          profile = create_base_channel_profile
          profile_points = profile.map do |p|
            transformed_pt = start_pt.offset(perp_vec, p[0])
            transformed_pt.offset([0,0,1], p[1])
          end

          # Create extrusion along path & apply material
          Viewrail::SharedUtilities.extrude_profile_along_path(base_group, profile_points, path_edges)
          apply_aluminum_finish(base_group, aluminum_material)
          
          return base_group

        end #create_continuous_base_channel

        def create_continuous_handrail(main_group, aluminum_material, adjust_position = [0,0,0])
          handrail_group = main_group.entities.add_group
          handrail_group.name = "Handrail"
          
          # Use offset distance to create segments, then convert them to a path
          handrail_center_offset = @offset_distance - (@glass_thickness / 2.0)          
          # Sort selections to build a continuous path for Follow Me
          sorted_edges, sorted_faces = Viewrail::SharedUtilities.sort_face_edges_and_faces(@face_edges, @selected_faces)
          path_edges = Viewrail::SharedUtilities.create_offset_path(sorted_edges, sorted_faces, handrail_group, handrail_center_offset)
         
          # Get starting point and direction for profile orientation
          first_edge = path_edges.first
          first_segment = [first_edge.start.position, first_edge.end.position]
          start_pt = first_segment[0]
          perp_vec = calculate_path_vectors(first_segment)

          # Adjust position based on user input
          start_pt.x += adjust_position[0]
          start_pt.y += adjust_position[1]
          start_pt.z += adjust_position[2]
          
          # Create handrail profile
          profile = create_handrail_profile
          profile_points = profile.map do |p|
            transformed_pt = start_pt.offset(perp_vec, p[0])
            transformed_pt.offset([0,0,1], p[1])
          end

          # Create extrusion along path & apply material
          Viewrail::SharedUtilities.extrude_profile_along_path(handrail_group, profile_points, path_edges)
          apply_aluminum_finish(handrail_group, aluminum_material)

          return handrail_group

        end #create_continuous_handrail

        def apply_aluminum_finish(group, material)
          # Apply material to all faces
          group.entities.grep(Sketchup::Face).each do |face|
            face.material = material
            face.back_material = material
          end
          
          # Soften vertical edges for rounded appearance
          group.entities.grep(Sketchup::Edge).each do |edge|
            edge_vec = edge.line[1]
            #if line is horizontal, soften it
            if edge_vec.parallel?([1,0,0]) || edge_vec.parallel?([0,1,0])
              edge.soft = true
              edge.smooth = true
            end
          end
        end # apply_aluminum_finish

        def calculate_path_vectors(segment)
          start_pt = segment[0]
          end_pt = segment[1]
          
          # Calculate path direction
          path_vec = end_pt - start_pt
          path_vec.normalize!
          
          # Create perpendicular vector for profile orientation
          perp_vec = Geom::Vector3d.new(-path_vec.y, path_vec.x, 0)
          perp_vec.normalize!
          
          return perp_vec
        end # calculate_path_vectors

      end # class GlassRailingTool

    end # module Tools

  end # module RailingGenerator

end # module Viewrail
