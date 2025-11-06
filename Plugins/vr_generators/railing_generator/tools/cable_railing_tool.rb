module Viewrail

  module RailingGenerator

    module Tools

      class CableRailingTool

        Viewport = Viewrail::SharedUtilities::Viewport

        def self.show
          last_values = {}

          dialog = UI::HtmlDialog.new(
            {
              :dialog_title => "Cable Railing Configuration",
              :preferences_key => "com.viewrail.cable_railing_generator",
              :scrollable => false,
              :resizable => false,
              :width => 450,
              :height => 500,
              :left => 100,
              :top => 100,
              :style => UI::HtmlDialog::STYLE_DIALOG
            }
          )

          begin
            renderer = Viewrail::SharedUtilities::FormRenderer.new(last_values)
            html_content = renderer.render(File.join(File.dirname(__FILE__), "..", "forms", "cable_railing_form.html.erb"))
            dialog.set_html(html_content)
          rescue => e
            UI.messagebox("Error loading form template: #{e.message}\n\nPlease check that the template file exists.")
            return
          end

          dialog.add_action_callback("create_cable_railing") do |action_context, params|
            begin
              values = JSON.parse(params, symbolize_names: true)
              tool = Viewrail::RailingGenerator::Tools::CableRailingTool.new
              tool.configure_from_dialog(values)
              tool.set_dialog(dialog)
              Sketchup.active_model.select_tool(tool)
            rescue => e
              puts "Error: #{e.message}"
              UI.messagebox("Error: #{e.message}")
            end
          end

          dialog.add_action_callback("finish_selection") do |action_context|
            tool = Sketchup.active_model.tools.active_tool
            if tool.is_a?(Viewrail::RailingGenerator::Tools::CableRailingTool)
              view = Sketchup.active_model.active_view
              tool.onReturn(view)
            end
          end

          dialog.add_action_callback("cancel") do |action_context|
            if @selected_faces.nil?
              Sketchup.active_model.select_tool(nil)
            else
              @selected_faces.clear
              @face_edges.clear
              update_status_text
              view.invalidate
            end
            dialog.close
          end

          dialog.show
        end # self.show

        def initialize
          @selected_faces = []
          @face_edges = []
          @hover_face = nil
          @hover_edge = nil
          @dialog = nil

          # Cable railing parameters
          @total_height = 42.0
          @offset_distance = 4.0
          @cable_diameter = 0.25
          @cable_spacing = 3.0
          @cable_start_height = 3.0
          @cable_sides = 6
          
          # Post parameters
          @post_width = 2.0
          @post_depth = 2.0
          @post_height_reduction = 2.0
          @max_post_spacing = 48.0
          @post_base_width = 3.5
          @post_base_height = 1.0
          
          # Handrail parameters (always included)
          @handrail_width = Viewrail::ProductData.handrail_width
          @handrail_thickness = Viewrail::ProductData.handrail_thickness
          @glass_recess = Viewrail::ProductData.glass_recess
          @corner_radius = Viewrail::ProductData.handrail_corner_radius
          @handrail_material = "Aluminum"
        end # initialize

        def set_dialog(dialog)
          @dialog = dialog
        end

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
          draw_face_selection_interface(view)
        end # draw

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
            groups = group_adjacent_face_sets(@face_edges, @selected_faces)
            groups.each do |group|
              @face_edges = group[:edges]
              @selected_faces = group[:faces]

              prepare_face_segments_for_extrusion
              initiate_railing_creation

              @selected_faces.clear
              @face_edges.clear
              update_status_text
              view.invalidate
            end

            if @dialog
              @dialog.execute_script("resetButton();")
              Viewrail::SharedUtilities.log_action("Added cable face railing")
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

        def configure_from_dialog(params)
          @total_height = params[:railing_height] || 42.0
          @handrail_material = params[:caprail_material] || "Aluminum"
        end # configure_from_dialog

        def draw_face_selection_interface(view)
          Viewport.draw_selected_faces(view, @selected_faces, @face_edges)
          if @hover_face && !@selected_faces.include?(@hover_face)
            Viewport.draw_hover_face(view, @hover_face, @hover_edge)
          end
          draw_face_preview_posts(view)
        end # draw_face_selection_interface

        def draw_face_preview_posts(view)
          return if @face_edges.nil?

          view.drawing_color = [100, 150, 200, 128]
          view.line_width = 2
          view.line_stipple = "-"

          @face_edges.each_with_index do |edge_points, face_index|
            face = @selected_faces[face_index]
            next unless face && edge_points

            draw_posts_for_edge(view, edge_points, face)
          end

          view.line_stipple = ""
        end # draw_face_preview_posts

        def draw_posts_for_edge(view, edge_points, face)
          start_pt, end_pt = calculate_post_positions(edge_points, face)
          
          post_locations = calculate_post_locations(start_pt, end_pt)
          post_height = @total_height - @post_height_reduction

          post_locations.each do |loc|
            top_pt = Geom::Point3d.new(loc.x, loc.y, loc.z + post_height)
            view.draw_line(loc, top_pt)
          end
        end # draw_posts_for_edge

        def calculate_post_positions(edge_points, face)
          face_normal = face.normal
          offset_vector = face_normal.reverse
          offset_vector.normalize!

          start_pt = edge_points[0].offset(offset_vector, @offset_distance)
          end_pt = edge_points[1].offset(offset_vector, @offset_distance)

          return [start_pt, end_pt]
        end # calculate_post_positions

        def calculate_post_locations(start_pt, end_pt)
          segment_vector = end_pt - start_pt
          segment_length = segment_vector.length
          
          return [start_pt] if segment_length == 0
          
          segment_vector.normalize!
          
          # Calculate number of posts needed
          num_spans = (segment_length / @max_post_spacing).ceil
          num_posts = num_spans + 1
          
          # Calculate actual spacing
          actual_spacing = segment_length / num_spans
          
          locations = []
          (0...num_posts).each do |i|
            distance = i * actual_spacing
            locations << start_pt.offset(segment_vector, distance)
          end
          
          return locations
        end # calculate_post_locations

        private

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

          endpoint_keys = face_edges.map { |a, b| [key_for.call(a), key_for.call(b)] }

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

          return groups
        end # group_adjacent_face_sets

        def prepare_face_segments_for_extrusion
          sorted_edges, sorted_faces = Viewrail::SharedUtilities.sort_face_edges_and_faces(@face_edges, @selected_faces)
          @face_segments = Viewrail::SharedUtilities.create_offset_line_from_edges(
            sorted_edges,
            sorted_faces,
            @offset_distance
          )
          return @face_segments
        end # prepare_face_segments_for_extrusion

        def initiate_railing_creation
          if defined?(@face_segments) && !@face_segments.nil?
            if !@face_segments.nil?
              create_cable_railings_from_face_segments
              return
            end
          end
        end # initiate_railing_creation

        def create_cable_railings_from_face_segments
          return if @face_segments.nil?

          model = Sketchup.active_model
          model.start_operation('Create Cable Railings from Faces', true)

          begin
            entities = model.active_entities
            main_group = entities.add_group
            main_group.name = "Cable Railing Assembly"

            # Create posts for each segment
            @face_segments.each_with_index do |segment_points, index|
              create_posts_for_segment(main_group, segment_points)
            end

            # Create continuous cables
            create_continuous_cables(main_group)

            # Create continuous handrail
            handrail_mat = (@handrail_material == "Wood") ? :wood : :aluminum
            z_adjust = Viewrail::ProductData.calculate_handrail_z_adjustment(@total_height)
            handrail_group = create_continuous_handrail(main_group, [0, 0, z_adjust])
            Viewrail::SharedUtilities.apply_material_to_group(handrail_group, handrail_mat)
            Viewrail::SharedUtilities.soften_edges_in_group(handrail_group)

            model.commit_operation
            Sketchup.active_model.select_tool(nil)

          rescue => e
            model.abort_operation
            UI.messagebox("Error creating cable railings: #{e.message}")
          ensure
            @face_segments = []
          end
        end # create_cable_railings_from_face_segments

        def create_posts_for_segment(main_group, segment_points)
          start_pt = segment_points[0]
          end_pt = segment_points[1]
          
          post_locations = calculate_post_locations(start_pt, end_pt)
          post_height = @total_height - @post_height_reduction
          
          post_locations.each_with_index do |location, i|
            post_group = main_group.entities.add_group
            post_group.name = "Post #{i + 1}"
            
            # Create post base (3.5" x 3.5" x 1")
            base_pts = [
              Geom::Point3d.new(location.x - @post_base_width/2, location.y - @post_base_width/2, location.z),
              Geom::Point3d.new(location.x + @post_base_width/2, location.y - @post_base_width/2, location.z),
              Geom::Point3d.new(location.x + @post_base_width/2, location.y + @post_base_width/2, location.z),
              Geom::Point3d.new(location.x - @post_base_width/2, location.y + @post_base_width/2, location.z)
            ]
            base_face = post_group.entities.add_face(base_pts)
            base_face.pushpull(@post_base_height) if base_face
            
            # Create post (2" x 2" x height)
            post_pts = [
              Geom::Point3d.new(location.x - @post_width/2, location.y - @post_depth/2, location.z + @post_base_height),
              Geom::Point3d.new(location.x + @post_width/2, location.y - @post_depth/2, location.z + @post_base_height),
              Geom::Point3d.new(location.x + @post_width/2, location.y + @post_depth/2, location.z + @post_base_height),
              Geom::Point3d.new(location.x - @post_width/2, location.y + @post_depth/2, location.z + @post_base_height)
            ]
            post_face = post_group.entities.add_face(post_pts)
            post_face.pushpull(post_height - @post_base_height) if post_face
            
            # Apply black material to posts
            apply_black_material(post_group)
            
            # Soften only vertical edges
            soften_vertical_edges(post_group)
          end
        end # create_posts_for_segment

        def create_continuous_cables(main_group)
          # Calculate cable heights
          cable_heights = []
          current_height = @cable_start_height
          while current_height <= @total_height
            cable_heights << current_height
            current_height += @cable_spacing
          end
          
          # Create each cable level
          cable_heights.each_with_index do |height, i|
            cable_group = create_continuous_cable_at_height(main_group, height, i + 1)
            apply_black_material(cable_group)
            Viewrail::SharedUtilities.soften_edges_in_group(cable_group)
          end
        end # create_continuous_cables

        def create_continuous_cable_at_height(main_group, height, cable_num)
          cable_group = main_group.entities.add_group
          cable_group.name = "Cable #{cable_num}"
          
          sorted_edges, sorted_faces = Viewrail::SharedUtilities.sort_face_edges_and_faces(@face_edges, @selected_faces)
          path_edges = Viewrail::SharedUtilities.create_offset_path(sorted_edges, sorted_faces, cable_group, @offset_distance)
          
          first_edge = path_edges.first
          first_segment = [first_edge.start.position, first_edge.end.position]
          start_pt = first_segment[0]
          
          # Adjust start point to cable height
          start_pt = Geom::Point3d.new(start_pt.x, start_pt.y, start_pt.z + height)
          
          # Create hexagonal cable profile
          profile_points = create_cable_profile(start_pt, first_segment)
          
          Viewrail::SharedUtilities.extrude_profile_along_path(cable_group, profile_points, path_edges)
          
          return cable_group
        end # create_continuous_cable_at_height

        def create_cable_profile(center_pt, segment)
          # Calculate perpendicular vector for profile orientation
          path_vec = segment[1] - segment[0]
          path_vec.normalize!
          perp_vec = Geom::Vector3d.new(-path_vec.y, path_vec.x, 0)
          perp_vec.normalize!
          
          # Create hexagonal profile
          profile = []
          radius = @cable_diameter / 2.0
          
          @cable_sides.times do |i|
            angle = (2.0 * Math::PI * i) / @cable_sides
            x_offset = radius * Math.cos(angle)
            z_offset = radius * Math.sin(angle)
            
            pt = center_pt.clone
            pt = pt.offset(perp_vec, x_offset)
            pt.z += z_offset
            profile << pt
          end
          
          return profile
        end # create_cable_profile

        def create_continuous_handrail(main_group, adjust_position = [0,0,0])
          return create_continuous_feature(main_group, {
            name: "Handrail",
            profile: Viewrail::ProductData.create_profile(:handrail),
            offset: @offset_distance,
            adjust_position: adjust_position
          })
        end # create_continuous_handrail

        def create_continuous_feature(main_group, config)
          feature_group = main_group.entities.add_group
          feature_group.name = config[:name]
          center_offset = config[:offset]

          sorted_edges, sorted_faces = Viewrail::SharedUtilities.sort_face_edges_and_faces(@face_edges, @selected_faces)
          path_edges = Viewrail::SharedUtilities.create_offset_path(sorted_edges, sorted_faces, feature_group, center_offset)

          first_edge = path_edges.first
          first_segment = [first_edge.start.position, first_edge.end.position]
          start_pt = first_segment[0]
          perp_vec = calculate_path_vectors(first_segment)

          if config[:adjust_position]
            start_pt.x += config[:adjust_position][0]
            start_pt.y += config[:adjust_position][1]
            start_pt.z += config[:adjust_position][2]
          end

          profile = config[:profile]
          profile_points = profile.map do |p|
            transformed_pt = start_pt.offset(perp_vec, p[0])
            transformed_pt.offset([0,0,1], p[1])
          end

          Viewrail::SharedUtilities.extrude_profile_along_path(feature_group, profile_points, path_edges)

          return feature_group
        end # create_continuous_feature

        def calculate_path_vectors(segment)
          start_pt = segment[0]
          end_pt = segment[1]

          path_vec = end_pt - start_pt
          path_vec.normalize!

          perp_vec = Geom::Vector3d.new(-path_vec.y, path_vec.x, 0)
          perp_vec.normalize!

          return perp_vec
        end # calculate_path_vectors

        def apply_black_material(group)
          black_material = Sketchup.active_model.materials.add("Black Post Material")
          black_material.color = Sketchup::Color.new(30, 30, 30)
          
          group.entities.grep(Sketchup::Face).each do |face|
            face.material = black_material
            face.back_material = black_material
          end
        end # apply_black_material

        def soften_vertical_edges(group)
          group.entities.grep(Sketchup::Edge).each do |edge|
            edge_vec = edge.line[1]
            # Only soften edges that are vertical (parallel to Z axis)
            if edge_vec.parallel?([0,0,1])
              edge.soft = true
              edge.smooth = true
            end
          end
        end # soften_vertical_edges

      end # class CableRailingTool

    end # module Tools

  end # module RailingGenerator

end # module Viewrail