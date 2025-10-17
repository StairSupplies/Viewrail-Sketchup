module Viewrail

  module RailingGenerator

    module Tools

      class GlassRailingTool

        Viewport = Viewrail::SharedUtilities::Viewport

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
            html_content = renderer.render(File.join(File.dirname(__FILE__), "..", "forms", "glass_railing_form.html.erb"))
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

        def initialize
          @selected_faces = []
          @face_edges = []
          @hover_face = nil
          @hover_edge = nil

          @total_height = 42.0
          @glass_thickness = Viewrail::ProductData.glass_thickness
          @max_panel_width = Viewrail::ProductData.max_panel_width
          @panel_gap = Viewrail::ProductData.default_panel_gap
          @offset_distance = 2.0

          @include_handrail = true
          @handrail_width = Viewrail::ProductData.handrail_width
          @handrail_height = Viewrail::ProductData.handrail_height
          @glass_recess = Viewrail::ProductData.glass_recess
          @corner_radius = Viewrail::ProductData.handrail_corner_radius
          @handrail_material = "Aluminum"

          @include_base_channel = true
          @base_channel_width = Viewrail::ProductData.base_channel_width
          @base_channel_height = Viewrail::ProductData.base_channel_height
          @glass_bottom_offset = Viewrail::ProductData.glass_bottom_offset
          @base_corner_radius = Viewrail::ProductData.base_corner_radius

          @include_floor_cover = false
          @floor_cover_width = Viewrail::ProductData.floor_cover_width
          @floor_cover_height = Viewrail::ProductData.floor_cover_height
          @glass_below_floor = 0

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
          @railing_type = params[:railing_type] || "Hidden"
          @total_height = params[:railing_height] || 42.0
          @include_handrail = params[:include_caprail] || false
          @handrail_material = params[:caprail_material] || "Aluminum"

          @include_base_channel = (@railing_type == "Baserail")
          @include_floor_cover = (@railing_type == "Hidden")

          @glass_height = Viewrail::ProductData.calculate_glass_height(
            @total_height,
            @include_handrail,
            @railing_type
          )

          @glass_below_floor = (@railing_type == "Hidden") ?
            Viewrail::ProductData.glass_below_floor : 0

          @offset_distance = Viewrail::ProductData.offset_for_railing_type(@railing_type)
        end # configure_from_dialog

        def draw_face_selection_interface(view)
          Viewport.draw_selected_faces(view, @selected_faces, @face_edges)
          if @hover_face && !@selected_faces.include?(@hover_face)
            Viewport.draw_hover_face(view, @hover_face, @hover_edge)
          end
          draw_face_preview_panels(view)
        end # draw_face_selection_interface

        def draw_face_preview_panels(view)
          return if @face_edges.nil?

          view.drawing_color = [100, 150, 200, 128]  # Semi-transparent blue
          view.line_width = 1
          view.line_stipple = "-"

          @face_edges.each_with_index do |edge_points, face_index|
            face = @selected_faces[face_index]
            next unless face && edge_points

            draw_panels_for_edge(view, edge_points, face)
          end

          view.line_stipple = ""
        end # draw_face_preview_panels

        def draw_panels_for_edge(view, edge_points, face)
          start_pt, end_pt = calculate_panel_positions(edge_points, face)

          layout = calculate_panel_layout(start_pt, end_pt)
          return unless layout

          layout[:panels].each do |panel|
            draw_panel_outline(view, panel)
          end
        end # draw_panels_for_edge

        def calculate_panel_positions(edge_points, face)
          face_normal = face.normal
          offset_vector = face_normal.reverse
          offset_vector.normalize!

          start_pt = edge_points[0].offset(offset_vector, @offset_distance)
          end_pt = edge_points[1].offset(offset_vector, @offset_distance)

          if @include_floor_cover
            start_pt.z -= @glass_below_floor
            end_pt.z -= @glass_below_floor
          end

          return [start_pt, end_pt]
        end # calculate_panel_positions

        def calculate_panel_layout(start_pt, end_pt, glass_height = @glass_height)
          segment_vector = end_pt - start_pt
          segment_length = segment_vector.length

          return nil if segment_length == 0

          segment_vector.normalize!

          available_length = segment_length - @panel_gap
          num_panels = calculate_panel_count(available_length)

          return nil unless num_panels > 0

          total_gaps = (num_panels - 1) * @panel_gap
          panel_width = (available_length - total_gaps) / num_panels

          panels = []

          (0...num_panels).each do |i|
            panel_start_distance = i * (panel_width + @panel_gap)
            panel_end_distance = panel_start_distance + panel_width

            panel_start = start_pt.offset(segment_vector, panel_start_distance)
            panel_end = start_pt.offset(segment_vector, panel_end_distance)

            panels << {
              start: panel_start,
              end: panel_end,
              bottom_start: panel_start,
              bottom_end: panel_end,
              top_start: Geom::Point3d.new(panel_start.x, panel_start.y, panel_start.z + glass_height),
              top_end: Geom::Point3d.new(panel_end.x, panel_end.y, panel_end.z + glass_height)
            }
          end

          return {
            num_panels: num_panels,
            panel_width: panel_width,
            panels: panels
          }
        end # calculate_panel_layout

        def draw_panel_outline(view, panel)
          view.draw_line(panel[:bottom_start], panel[:bottom_end])
          view.draw_line(panel[:bottom_end], panel[:top_end])
          view.draw_line(panel[:top_end], panel[:top_start])
          view.draw_line(panel[:top_start], panel[:bottom_start])
        end # draw_panel_outline

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
              create_glass_railings_from_face_segments
              return
            end
          end
        end # initiate_railing_creation

        def create_glass_railings_from_face_segments
          return if @face_segments.nil?

          model = Sketchup.active_model
          model.start_operation('Create Glass Railings from Faces', true)

          begin
            entities = model.active_entities
            main_group = entities.add_group
            main_group.name = "Glass Railing Assembly"

            glass_material = Viewrail::SharedUtilities.get_or_add_material(:glass)
            aluminum_material = Viewrail::SharedUtilities.get_or_add_material(:aluminum)
            wood_material = Viewrail::SharedUtilities.get_or_add_material(:wood)

            @face_segments.each_with_index do |segment_points, index|
              segment_group = main_group.entities.add_group
              segment_group.name = "Glass Railing Face #{index + 1}"

              extrude_direction = @selected_faces[index].normal
              create_glass_panel_group_for_segment(segment_group, glass_material, segment_points, extrude_direction)
            end

            if @include_base_channel
              baserail_group = create_continuous_base_channel(main_group)
              apply_material_with_softening(baserail_group, aluminum_material)
            end

            if @include_floor_cover
              cover_group = create_continuous_floor_cover(main_group)
              apply_material_with_softening(cover_group, wood_material)
            end

            if @include_handrail
              handrail_mat = (@handrail_material == "Wood") ? wood_material : aluminum_material

              z_adjust = Viewrail::ProductData.calculate_handrail_z_adjustment(
                @total_height,
                @include_floor_cover,
                @glass_height
              )

              handrail_group = create_continuous_handrail(main_group, [0, 0, z_adjust])
              apply_material_with_softening(handrail_group, handrail_mat)
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

        def create_glass_panel_group_for_segment(parent_group, glass_material, segment_points, extrude_direction)
          start_pt = segment_points[0]
          end_pt = segment_points[1]

          if @include_floor_cover
            start_pt = Geom::Point3d.new(start_pt.x, start_pt.y, start_pt.z - @glass_below_floor)
            end_pt = Geom::Point3d.new(end_pt.x, end_pt.y, end_pt.z - @glass_below_floor)
          end

          return create_glass_panels(parent_group, glass_material, start_pt, end_pt, true, extrude_direction)
        end # create_glass_panel_group_for_segment

        def create_glass_panels(group, glass_material, start_pt, end_pt, segmented=false, extrude_direction=nil)
          glass_group = segmented ? group : group.entities.add_group

          layout = calculate_panel_layout(start_pt, end_pt)
          return unless layout

          layout[:panels].each do |panel|
            glass_points = [
              panel[:bottom_start],
              panel[:bottom_end],
              panel[:top_end],
              panel[:top_start]
            ]

            face = glass_group.entities.add_face(glass_points)
            if face
              if extrude_direction == face.normal
                face.pushpull(@glass_thickness)
              else
                face.pushpull(-@glass_thickness)
              end

              glass_group.entities.grep(Sketchup::Face).each do |f|
                f.material = glass_material
                f.back_material = glass_material
              end
            end
          end
        end # create_glass_panels

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

        def create_continuous_feature(main_group, config)
          feature_group = main_group.entities.add_group
          feature_group.name = config[:name]
          center_offset = config[:offset]

          puts "---- sorting user selections for #{config[:name]}"

          sorted_edges, sorted_faces = Viewrail::SharedUtilities.sort_face_edges_and_faces(@face_edges, @selected_faces)
          path_edges = Viewrail::SharedUtilities.create_offset_path(sorted_edges, sorted_faces, feature_group, center_offset)

          puts "---- creating path for #{config[:name]}"

          first_edge = path_edges.first
          first_segment = [first_edge.start.position, first_edge.end.position]
          start_pt = first_segment[0]
          perp_vec = calculate_path_vectors(first_segment)

          if config[:adjust_position]
            start_pt.x += config[:adjust_position][0]
            start_pt.y += config[:adjust_position][1]
            start_pt.z += config[:adjust_position][2]
          end

          puts "---- transforming profile for #{config[:name]}"

          profile = config[:profile]
          profile_points = profile.map do |p|
            transformed_pt = start_pt.offset(perp_vec, p[0])
            transformed_pt.offset([0,0,1], p[1])
          end

          puts "---- extruding profile along path for #{config[:name]}"

          Viewrail::SharedUtilities.extrude_profile_along_path(feature_group, profile_points, path_edges)

          return feature_group
        end # create_continuous_feature

        def create_continuous_base_channel(main_group, adjust_position = [0,0,0])
          return create_continuous_feature(main_group, {
            name: "Base Channel",
            profile: Viewrail::ProductData.create_profile(:base_channel),
            offset: calculate_base_channel_offset,
            adjust_position: adjust_position
          })
        end # create_continuous_base_channel

        def create_continuous_floor_cover(main_group, adjust_position = [0,0,0])
          return create_continuous_feature(main_group, {
            name: "Floor Cover",
            profile: Viewrail::ProductData.create_profile(:floor_cover),
            offset: calculate_floor_cover_offset,
            adjust_position: adjust_position
          })
        end # create_continuous_floor_cover

        def create_continuous_handrail(main_group, adjust_position = [0,0,0])
          return create_continuous_feature(main_group, {
            name: "Handrail",
            profile: Viewrail::ProductData.create_profile(:handrail),
            offset: calculate_handrail_offset,
            adjust_position: adjust_position
          })
        end # create_continuous_handrail

        def calculate_base_channel_offset
          @offset_distance - (@glass_thickness / 2.0)
        end

        def calculate_handrail_offset
          @offset_distance - (@glass_thickness / 2.0)
        end

        def calculate_floor_cover_offset
          -@floor_cover_width / 2.0
        end

        def apply_material_with_softening(group, material)
          group.entities.grep(Sketchup::Face).each do |face|
            face.material = material
            face.back_material = material
          end

          group.entities.grep(Sketchup::Edge).each do |edge|
            edge_vec = edge.line[1]
            if edge_vec.parallel?([1,0,0]) || edge_vec.parallel?([0,1,0])
              edge.soft = true
              edge.smooth = true
            end
          end
        end # apply_material_with_softening

        def calculate_path_vectors(segment)
          start_pt = segment[0]
          end_pt = segment[1]

          path_vec = end_pt - start_pt
          path_vec.normalize!

          perp_vec = Geom::Vector3d.new(-path_vec.y, path_vec.x, 0)
          perp_vec.normalize!

          return perp_vec
        end # calculate_path_vectors

      end # class GlassRailingTool

    end # module Tools

  end # module RailingGenerator

end # module Viewrail
