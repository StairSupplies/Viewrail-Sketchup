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
          @total_height = 42.0       # Total height including handrail
          @glass_thickness = 0.5     # Thickness of glass panels
          @max_panel_width = 48.0    # Maximum width of each panel
          @panel_gap = 1.0           # Gap between panels
          @offset_distance = 2.0     # Offset from drawn line
          
          # Handrail dimensions
          @include_handrail = true   # Make this configurable via dialog
          @handrail_width = 1.69
          @handrail_height = 1.35
          @glass_recess = 0.851      # How deep glass goes into handrail
          @corner_radius = 0.160
          
          # Base channel dimensions
          @include_base_channel = true  # Make this configurable via dialog
          @base_channel_width = 2.5
          @base_channel_height = 4.188
          @glass_bottom_offset = 1.188  # Height of glass bottom above floor
          @base_corner_radius = 0.0625

          # Calculate glass height based on handrail
          @glass_height = @include_handrail ? 
            @total_height - @handrail_height + @glass_recess : 
            @total_height
        end
        
        def create_glass_railings
          return if @points.length < 2
          
          model = Sketchup.active_model
          model.start_operation('Create Glass Railings', true)
          
          begin
            entities = model.active_entities
            main_group = entities.add_group
            main_group.name = "Glass Railing Assembly"
            
            # Get materials
            glass_material = Viewrail::SharedUtilities.get_or_create_glass_material(model)
            aluminum_material = get_or_create_aluminum_material(model)
            
            # Create glass panels first
            create_glass_panels(main_group, glass_material)
            
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
        
        private
        
        def create_glass_panels(main_group, glass_material)
          (0...@points.length - 1).each do |i|
            start_pt = @points[i]
            end_pt = @points[i + 1]
            
            segment_group = main_group.entities.add_group
            segment_group.name = "Glass Railing Segment #{i + 1}"
            
            segment_vector = end_pt - start_pt
            segment_length = segment_vector.length
            segment_vector.normalize!
            
            perp_vector = Geom::Vector3d.new(-segment_vector.y, segment_vector.x, 0)
            perp_vector.normalize!
            
            available_length = segment_length - @panel_gap
            num_panels = calculate_panel_count(available_length)
            
            if num_panels > 0
              total_gaps = (num_panels - 1) * @panel_gap
              panel_width = (available_length - total_gaps) / num_panels
              
              (0...num_panels).each do |j|
                panel_start_distance = j * (panel_width + @panel_gap)
                panel_end_distance = panel_start_distance + panel_width
                
                panel_start = start_pt.offset(segment_vector, panel_start_distance)
                panel_start = panel_start.offset(perp_vector, @offset_distance)
                
                panel_end = start_pt.offset(segment_vector, panel_end_distance)
                panel_end = panel_end.offset(perp_vector, @offset_distance)
                
                glass_points = [
                  panel_start,
                  panel_end,
                  [panel_end.x, panel_end.y, panel_end.z + @glass_height],
                  [panel_start.x, panel_start.y, panel_start.z + @glass_height]
                ]
                
                face = segment_group.entities.add_face(glass_points)
                if face
                  face.pushpull(@glass_thickness)
                  
                  segment_group.entities.grep(Sketchup::Face).each do |f|
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
              offset_pt = pt.offset(perp, @offset_distance - @glass_thickness/2.0)
              base_path << [offset_pt.x, offset_pt.y, offset_pt.z]
            elsif i == @points.length - 1
              # Last point
              prev_pt = @points[i - 1]
              vec = pt - prev_pt
              vec.normalize!
              perp = Geom::Vector3d.new(-vec.y, vec.x, 0)
              offset_pt = pt.offset(perp, @offset_distance - @glass_thickness/2.0)
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
              offset_distance = (@offset_distance + @glass_thickness/2.0) * miter_factor
              
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
              offset_pt = pt.offset(perp, @offset_distance - @glass_thickness/2.0)
              handrail_path << [offset_pt.x, offset_pt.y, offset_pt.z + @glass_height - (@glass_recess - @handrail_height/2.0)]
    
            elsif i == @points.length - 1
              # Last point
              prev_pt = @points[i - 1]
              vec = pt - prev_pt
              vec.normalize!
              perp = Geom::Vector3d.new(-vec.y, vec.x, 0)
              offset_pt = pt.offset(perp, @offset_distance - @glass_thickness/2.0)
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
              offset_distance = (@offset_distance + @glass_thickness/2.0) * miter_factor
              
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
        
        def get_or_create_aluminum_material(model)
          materials = model.materials
          aluminum_material = materials["Aluminum_Brushed"]
          if !aluminum_material
            aluminum_material = materials.add("Aluminum_Brushed")
            aluminum_material.color = [180, 184, 189]  # Brushed aluminum color
          end
          aluminum_material
        end
        
        # ... rest of the existing methods (draw, onMouseMove, etc.) remain the same ...
      end
    end
  end
end