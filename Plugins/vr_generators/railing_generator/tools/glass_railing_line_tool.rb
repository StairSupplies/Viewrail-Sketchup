module Viewrail

  module RailingGenerator

    module Tools

      class GlassRailingLineTool

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
              tool = Viewrail::RailingGenerator::Tools::GlassRailingLineTool.new
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
          @points = []
          @current_point = nil
          @ip = Sketchup::InputPoint.new

          @total_height = 42.0
          @glass_thickness = Viewrail::ProductData.glass_thickness
          @max_panel_width = Viewrail::ProductData.max_panel_width
          @panel_gap = Viewrail::ProductData.default_panel_gap
          @offset_distance = 2.0

          @include_handrail = true
          @handrail_width = Viewrail::ProductData.handrail_width
          @handrail_thickness = Viewrail::ProductData.handrail_thickness
          @glass_recess = Viewrail::ProductData.glass_recess
          @corner_radius = Viewrail::ProductData.handrail_corner_radius
          @handrail_material = "Aluminum"

          @include_base_channel = true
          @base_channel_width = Viewrail::ProductData.base_channel_width
          @base_channel_height = Viewrail::ProductData.base_channel_height
          @glass_bottom_offset = Viewrail::ProductData.glass_bottom_offset
          @base_corner_radius = Viewrail::ProductData.base_corner_radius

          @glass_height = @include_handrail ?
            @total_height - @handrail_thickness + @glass_recess :
            @total_height
        end # initialize

        def configure_from_dialog(params)
          @railing_type = params[:railing_type] || "Hidden"
          @total_height = params[:railing_height] || 42.0
          @include_handrail = params[:include_caprail] || false
          @handrail_material = params[:caprail_material] || "Aluminum"

          @include_base_channel = (@railing_type == "Baserail")

          @glass_height = Viewrail::ProductData.calculate_glass_height(
            @total_height,
            @include_handrail,
            @railing_type
          )

          @offset_distance = Viewrail::ProductData.offset_for_railing_type(@railing_type)

        end # configure_from_dialog

        def onLButtonDown(flags, x, y, view)
          @ip.pick(view, x, y)
          if @ip.valid?
            pt = @ip.position
            @points << pt
            update_status_text
            view.invalidate
          end
        end # onLButtonDown

        def draw(view)
          draw_path_mode(view)
        end # draw

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
        end # onMouseMove

        def activate
          @points = []
          update_status_text
        end # activate

        def deactivate(view)
          view.invalidate
        end # deactivate

        def onCancel(reason, view)
          if @points.empty?
            Sketchup.active_model.select_tool(nil)
          else
            @points.clear
            update_status_text
            view.invalidate
          end
        end # onCancel

        def onReturn(view)
          if @points.length >= 2
            create_glass_railings
            @points.clear
            update_status_text
            view.invalidate
          end
        end # onReturn

        def update_status_text
          if @points.empty?
            Sketchup.status_text = "Click to start drawing path | Shift: Lock to axis"
          elsif @points.length == 1
            Sketchup.status_text = "Click next point | Enter: Finish | Esc: Cancel | Shift: Lock to axis"
          else
            Sketchup.status_text = "Click to continue | Enter: Create railing | Esc: Clear | Shift: Lock to axis"
          end
        end # update_status_text

        def draw_path_mode(view)
          if @points.length > 0
            view.drawing_color = "blue"
            view.line_width = 4

            (0...@points.length - 1).each do |i|
              view.draw_line(@points[i], @points[i + 1])
            end

            if @current_point && @points.length > 0
              view.drawing_color = [0, 128, 255]  # Light blue for preview
              view.line_stipple = "_"
              view.draw_line(@points.last, @current_point)
              view.line_stipple = ""
            end

            view.drawing_color = "red"
            @points.each { |pt| view.draw_points(pt, 6) }

            draw_preview_panels(view)
          end
        end # draw_path_mode

        def draw_preview_panels(view)
          preview_points = @points.dup
          preview_points << @current_point if @current_point && @points.length > 0

          return if preview_points.length < 2

          view.drawing_color = [100, 150, 200, 128]  # Semi-transparent blue
          view.line_width = 1
          view.line_stipple = "-"

          (0...preview_points.length - 1).each do |i|
            start_pt = preview_points[i]
            end_pt = preview_points[i + 1]

            segment_vector = end_pt - start_pt
            segment_length = segment_vector.length
            next if segment_length == 0
            segment_vector.normalize!

            perp_vector = Geom::Vector3d.new(-segment_vector.y, segment_vector.x, 0)
            perp_vector.normalize!

            offset_start = start_pt.offset(perp_vector, @offset_distance)
            offset_end = end_pt.offset(perp_vector, @offset_distance)

            layout = calculate_panel_layout(offset_start, offset_end)
            next unless layout

            layout[:panels].each do |panel|
              draw_panel_outline(view, panel)
            end
          end

          view.line_stipple = ""
        end # draw_preview_panels

        def draw_panel_outline(view, panel)
          view.draw_line(panel[:bottom_start], panel[:bottom_end])
          view.draw_line(panel[:bottom_end], panel[:top_end])
          view.draw_line(panel[:top_end], panel[:top_start])
          view.draw_line(panel[:top_start], panel[:bottom_start])
        end # draw_panel_outline

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

        private

        def create_glass_railings
          return if @points.length < 2

          model = Sketchup.active_model
          model.start_operation('Create Glass Railings', true)

          begin
            entities = model.active_entities
            main_group = entities.add_group
            main_group.name = "Glass Railing Assembly"

            glass_material = Viewrail::SharedUtilities.get_or_add_material(:glass)
            aluminum_material = Viewrail::SharedUtilities.get_or_add_material(:aluminum)
            wood_material = Viewrail::SharedUtilities.get_or_add_material(:wood)

            create_glass_panel_group(main_group, glass_material)

            if @include_base_channel
              baserail_group = create_continuous_base_channel(main_group)
              apply_material_with_softening(baserail_group, aluminum_material)
            end

            if @include_handrail
              handrail_mat = (@handrail_material == "Wood") ? wood_material : aluminum_material

              z_adjust = Viewrail::ProductData.calculate_handrail_z_adjustment(@total_height)
              handrail_group = create_continuous_handrail(main_group, [0, 0, z_adjust])
              apply_material_with_softening(handrail_group, handrail_mat)
            end

            model.commit_operation
            Sketchup.active_model.select_tool(nil)

          rescue => e
            model.abort_operation
            UI.messagebox("Error creating glass railings: #{e.message}")
          end
        end # create_glass_railings

        def create_glass_panel_group(main_group, glass_material)
          (0...@points.length - 1).each do |i|
            start_pt = @points[i]
            end_pt = @points[i + 1]

            create_glass_panels(main_group, glass_material, start_pt, end_pt)
          end
        end # create_glass_panel_group

        def create_glass_panels(group, glass_material, start_pt, end_pt, segmented=false)
          glass_group = segmented ? group : group.entities.add_group

          segment_vector = end_pt - start_pt
          segment_length = segment_vector.length
          return if segment_length == 0
          segment_vector.normalize!

          perp_vector = Geom::Vector3d.new(-segment_vector.y, segment_vector.x, 0)
          perp_vector.normalize!

          offset_start = start_pt.offset(perp_vector, @offset_distance)
          offset_end = end_pt.offset(perp_vector, @offset_distance)

          layout = calculate_panel_layout(offset_start, offset_end)
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
              face.pushpull(@glass_thickness)

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

          feature_path = calculate_feature_path(config[:offset])

          (0...feature_path.length - 1).each do |i|
            start_pt = Geom::Point3d.new(feature_path[i])
            end_pt = Geom::Point3d.new(feature_path[i + 1])

            vec = end_pt - start_pt
            segment_length = vec.length
            next if segment_length == 0
            vec.normalize!

            perp_vec = Geom::Vector3d.new(-vec.y, vec.x, 0)
            perp_vec.normalize!

            adjusted_start = start_pt.clone
            if config[:adjust_position]
              adjusted_start.x += config[:adjust_position][0]
              adjusted_start.y += config[:adjust_position][1]
              adjusted_start.z += config[:adjust_position][2]
            end

            profile = config[:profile]
            profile_points = profile.map do |p|
              transformed_pt = adjusted_start.offset(perp_vec, p[0])
              transformed_pt.offset([0,0,1], p[1])
            end

            face = feature_group.entities.add_face(profile_points)
            if face
              face.pushpull(-segment_length)
            end
          end

          return feature_group
        end # create_continuous_feature

        def calculate_feature_path(center_offset)
          feature_path = []

          @points.each_with_index do |pt, i|
            if i == 0
              next_pt = @points[i + 1]
              vec = next_pt - pt
              vec.normalize!
              perp = Geom::Vector3d.new(-vec.y, vec.x, 0)

              offset_pt = pt.offset(perp, center_offset)
              feature_path << [offset_pt.x, offset_pt.y, offset_pt.z]

            elsif i == @points.length - 1
              prev_pt = @points[i - 1]
              vec = pt - prev_pt
              vec.normalize!
              perp = Geom::Vector3d.new(-vec.y, vec.x, 0)

              offset_pt = pt.offset(perp, center_offset)
              feature_path << [offset_pt.x, offset_pt.y, offset_pt.z]

            else
              prev_pt = @points[i - 1]
              next_pt = @points[i + 1]

              vec1 = pt - prev_pt
              vec1.normalize!
              vec2 = next_pt - pt
              vec2.normalize!

              bisector = vec1 + vec2
              bisector.normalize!

              perp = Geom::Vector3d.new(-bisector.y, bisector.x, 0)

              angle = vec1.angle_between(vec2)
              miter_factor = 1.0 / Math.cos(angle / 2.0)
              offset_distance = center_offset * miter_factor

              offset_pt = pt.offset(perp, offset_distance)
              feature_path << [offset_pt.x, offset_pt.y, offset_pt.z]
            end
          end

          return feature_path
        end # calculate_feature_path

        def create_continuous_base_channel(main_group, adjust_position = [0,0,0])
          return create_continuous_feature(main_group, {
            name: "Base Channel",
            profile: Viewrail::ProductData.create_profile(:base_channel),
            offset: calculate_base_channel_offset,
            adjust_position: adjust_position
          })
        end # create_continuous_base_channel

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

      end # class GlassRailingLineTool

    end # module Tools

  end # module RailingGenerator

end # module Viewrail
