# viewrail_shared/utilities.rb
require_relative 'form_renderer'
require_relative 'viewport'
require_relative 'product_data'

module Viewrail

  module SharedUtilities

    class << self

      # Material definitions hash
      MATERIAL_DEFINITIONS = {
        glass: {
          name: "Glass_Transparent",
          color: [200, 220, 240, 128],
          alpha: 0.3
        },
        cable: {
          name: "Cable_Steel",
          color: [80, 80, 80],
          alpha: 1.0
        },
        aluminum: {
          name: "Aluminum_Brushed",
          color: [180, 184, 189],
          alpha: 1.0
        },
        steel: {
          name: "Steel_Powder_Coated",
          color: [50, 50, 50],
          alpha: 1.0
        },
        pc_white: {
          name: "Powder_Coat_White",
          color: [245, 245, 245],
          alpha: 1.0
        },
        pc_black: {
          name: "Powder_Coat_Black",
          color: [25, 25, 25],
          alpha: 1.0
        },
        wood: {
          name: "Wood_Veneer_15_1K",  # Use SketchUp's built-in wood material
          builtin: true                # Flag to indicate this is a built-in material
        },
        wood_custom: {
          name: "Wood_Natural",
          color: [139, 90, 43],  # Medium brown wood color
          alpha: 1.0
        },
        wood_light: {
          name: "Wood_Light",
          color: [205, 170, 125],  # Light oak color
          alpha: 1.0
        },
        wood_dark: {
          name: "Wood_Dark", 
          color: [83, 53, 10],  # Dark walnut color
          alpha: 1.0
        }
      }

      # Unified material getter/creator
      def get_or_add_material(type, model = nil)
        model ||= Sketchup.active_model
        material_def = MATERIAL_DEFINITIONS[type]

        # Return nil if material type not found
        if material_def.nil?
          puts "Warning: Material type '#{type}' not found in definitions"
          return nil
        end
        
        materials = model.materials
        
        # Handle built-in materials differently
        if material_def[:builtin]
          material = load_builtin_material(material_def[:name], model)
        else
          material = materials[material_def[:name]]
          # Create material if it doesn't exist
          if !material
            material = add_material_to_model(materials, material_def)
          end
        end
        
        return material
      end
      
      # Load a built-in SketchUp material by name
      def load_builtin_material(material_name, model = nil)
        model ||= Sketchup.active_model
        materials = model.materials
        
        # First check if it's already loaded in the model
        material = materials[material_name]
        return material if material
        
        # Try to load from SketchUp's built-in materials
        begin
          # SketchUp stores materials in different locations based on OS
          if Sketchup.platform == :platform_win
            # Windows path
            materials_path = Sketchup.find_support_file("Materials")
            wood_materials_path = File.join(materials_path, "Wood")
            
            # Search for the material file
            Dir.glob(File.join(wood_materials_path, "*.skm")).each do |file|
              temp_materials = model.materials.load(file)
              if temp_materials && model.materials[material_name]
                return model.materials[material_name]
              end
            end
          else
            # Mac path - materials are typically in .skm files
            materials_path = Sketchup.find_support_file("Materials")
            
            # Try to load the specific material
            material_file = File.join(materials_path, "Wood", "#{material_name}.skm")
            if File.exist?(material_file)
              model.materials.load(material_file)
              return model.materials[material_name]
            end
          end
          
          # If not found in files, try creating with a default wood color as fallback
          puts "Built-in material '#{material_name}' not found, creating fallback wood material"
          material = materials.add(material_name)
          material.color = [139, 90, 43]  # Default wood color
          return material
          
        rescue => e
          puts "Error loading built-in material: #{e.message}"
          # Create a fallback material
          material = materials.add(material_name)
          material.color = [139, 90, 43]  # Default wood color
          return material
        end
      end

      def add_material_to_model(materials, material_def)
          material = materials.add(material_def[:name])
          material.color = material_def[:color]
          material.alpha = material_def[:alpha] if material_def[:alpha] && material_def[:alpha] < 1.0
          
          # Add texture if specified
          if material_def[:texture_path] && File.exist?(material_def[:texture_path])
            material.texture = material_def[:texture_path]
            material.texture.size = material_def[:texture_size] || [48, 48]
          end
          
          return material
      end    

      # Add custom material definition at runtime
      def create_material_definition(key, name, color, alpha = 1.0, texture_path = nil, texture_size = nil)
        MATERIAL_DEFINITIONS[key] = {
          name: name,
          color: color,
          alpha: alpha
        }
        
        if texture_path
          MATERIAL_DEFINITIONS[key][:texture_path] = texture_path
          MATERIAL_DEFINITIONS[key][:texture_size] = texture_size if texture_size
        end
      end
      
      # Get all available material types
      def available_material_types
        MATERIAL_DEFINITIONS.keys
      end
      
      # Check if material type exists
      def material_type_exists?(type)
        MATERIAL_DEFINITIONS.key?(type)
      end

      def extract_top_edge_from_face(face)
        # Find all edges of the face
        edges = face.edges
        
        # Filter for horizontal edges (perpendicular to Z axis)
        horizontal_edges = edges.select do |edge|
          edge_vector = edge.line[1]
          edge_vector.perpendicular?([0, 0, 1])
        end
        
        if horizontal_edges.nil?
          raise "Face has no horizontal edges"
        end
        
        # Find the edge with the highest Z coordinate
        top_edge = horizontal_edges.max_by do |edge|
          # Get average Z of the edge's vertices
          (edge.vertices[0].position.z + edge.vertices[1].position.z) / 2.0
        end
        
        # Verify the edge is truly horizontal (not angled)
        v1 = top_edge.vertices[0].position
        v2 = top_edge.vertices[1].position
        if (v1.z - v2.z).abs > 0.001  # Tolerance for floating point
          raise "Top edge is not horizontal (angled)"
        end
        
        # Return the two points of the edge
        [v1, v2]
      end

      def convert_face_edges_to_points
        # Convert face edges to points - each face edge becomes a separate segment
        # We'll store them as separate segment pairs rather than trying to connect them
        @points.clear
        @face_segments = []  # Store face segments separately
        
        @face_edges.each_with_index do |edge_points, index|
          face = @selected_faces[index]
          
          # Calculate offset direction (away from face normal)
          face_normal = face.normal
          offset_vector = face_normal.reverse
          offset_vector.normalize!
          
          # Create offset points
          start_pt = edge_points[0].offset(offset_vector, @offset_distance)
          end_pt = edge_points[1].offset(offset_vector, @offset_distance)
          
          # Store as separate segment
          @face_segments << [start_pt, end_pt]
        end
        
        # For compatibility with existing create_glass_railings,
        # we'll process each segment separately
        @selection_mode_backup = @selection_mode
      end

      def convert_face_edges_to_segments(face_edges, selected_faces, offset_distance)
        face_segments = []
        
        face_edges.each_with_index do |edge_points, index|
          face = selected_faces[index]
          next unless face && edge_points
          
          # Calculate offset direction (away from face normal)
          face_normal = face.normal
          offset_vector = face_normal.reverse
          offset_vector.normalize!
          
          # Create offset points
          start_pt = edge_points[0].offset(offset_vector, offset_distance)
          end_pt = edge_points[1].offset(offset_vector, offset_distance)
          
          # Store as separate segment
          face_segments << [start_pt, end_pt]
        end
        
        face_segments
      end

      def build_path_from_edges(edges)
        unless !edges.nil? && !edges.nil?
          UI.messagebox("No valid edges found for building path.")
          return []
        end

        points = []
        
        # Handle both Edge objects and point pair arrays
        if edges.first.is_a?(Array)
          # edges is an array of point pairs [[pt1, pt2], [pt3, pt4], ...]
          return [] if edges.nil?
          
          # Start with first edge points
          first_edge = edges.first
          points << first_edge[0]
          points << first_edge[1]
          
          # Add remaining edges (assuming they're connected)
          edges[1..-1].each do |edge_points|
            start_pt = edge_points[0]
            end_pt = edge_points[1]
            
            # Check which end connects to our path
            if start_pt == points.last
              points << end_pt
            elsif end_pt == points.last
              points << start_pt
            elsif end_pt == points.first
              # Edge connects to beginning
              points.unshift(start_pt)
            elsif start_pt == points.first
              points.unshift(end_pt)
            else
              # Edge doesn't connect - try to find closest connection
              # This handles cases where points might be very close but not exactly equal
              tolerance = 0.001.inch
              
              if start_pt.distance(points.last) < tolerance
                points << end_pt
              elsif end_pt.distance(points.last) < tolerance
                points << start_pt
              elsif end_pt.distance(points.first) < tolerance
                points.unshift(start_pt)
              elsif start_pt.distance(points.first) < tolerance
                points.unshift(end_pt)
              end
            end
          end
          
        else
          # Original code for Edge objects
          first_edge = edges.first
          points << first_edge.start.position
          points << first_edge.end.position
          
          edges[1..-1].each do |edge|
            if edge.start.position == points.last
              points << edge.end.position
            elsif edge.end.position == points.last
              points << edge.start.position
            elsif edge.end.position == points.first
              points.unshift(edge.start.position)
            elsif edge.start.position == points.first
              points.unshift(edge.end.position)
            end
          end
        end
        
        # Remove duplicate points if path is closed
        if points.first == points.last && points.length > 2
          points.pop
        end
        
        return points
      end

      # Alternative: If your face_edges are already just point pairs and don't need connecting
      def build_path_from_point_pairs(edge_point_pairs)
        # If the edges are separate segments that don't connect into a continuous path,
        # just extract all unique points in order
        points = []

        edge_point_pairs.each do |edge_points|
          if points.nil?
            points << edge_points[0]
            points << edge_points[1]
          elsif edge_points[0] == points.last
            points << edge_points[1]
          elsif edge_points[1] == points.last
            points << edge_points[0]
          else
            # If not connected, you might want to handle this differently
            # For now, just add as a new segment
            points << edge_points[0] unless points.include?(edge_points[0])
            points << edge_points[1] unless points.include?(edge_points[1])
          end
        end

        points
      end

      # Or if you want to modify create_offset_line_from_edges to handle point pairs directly:
      def create_offset_line_from_edges(edges_or_points, faces, offset_distance)
        return [] if edges_or_points.nil? || faces.nil?
        # Build continuous path from edges or point pairs
        if edges_or_points.first.is_a?(Array)
          # It's already point pairs
          points = build_path_from_point_pairs(edges_or_points)
        else
          # It's Edge objects
          points = build_path_from_edges(edges_or_points)
        end

        return [] if points.length < 2

        # Create offset points on XY plane
        offset_points = []

        points.each_with_index do |point, index|
          if index == 0
            edge_vector = get_vector_from_face(faces[index]) # Use first face normal for start
            offset_point = point.offset(edge_vector, -offset_distance)
          elsif index == points.length - 1
            edge_vector = get_vector_from_face(faces[index - 1]) # Use last face normal for end
            offset_point = point.offset(edge_vector, -offset_distance)
          else
            prev_vector = get_vector_from_face(faces[index - 1]) # Use previous face normal            
            next_vector = get_vector_from_face(faces[index])     # Use current face normal
            offset_point = point.offset(prev_vector, -offset_distance).offset(next_vector, -offset_distance)
          end

          offset_points << offset_point
        end

        offset_segments = convert_points_to_segments(offset_points)

        return offset_segments
      end

      def convert_points_to_segments(points)

        return if points.length < 2
        segments = []        
        (points.length - 1).times do |i|
          segments << [points[i], points[i + 1]]
        end
        return segments

      end #convert_points_to_segments

      # ===== Sorting helpers (pre-process only, do not alter existing core methods) =====
      # Sort face edge point pairs and corresponding faces into a continuous chain.
      # Returns [sorted_pairs, sorted_faces]
      def sort_face_edges_and_faces(face_edges, selected_faces, tolerance = 0.001.inch)
        return [face_edges, selected_faces] if face_edges.nil? || face_edges.empty? || selected_faces.nil? || selected_faces.empty?

        key_for = lambda do |pt|
          [
            (pt.x / tolerance).round,
            (pt.y / tolerance).round,
            (pt.z / tolerance).round
          ]
        end

        # Build adjacency from endpoints to edge indices
        endpoints = face_edges.map { |a,b| [a,b] }
        adjacency = Hash.new { |h,k| h[k] = [] }
        endpoints.each_with_index do |(a,b), idx|
          adjacency[key_for.call(a)] << [idx, 0]
          adjacency[key_for.call(b)] << [idx, 1]
        end

        # Find a start at a degree-1 endpoint if possible
        start_idx = nil
        start_ep = 0
        endpoints.each_with_index do |(a,b), idx|
          ka = key_for.call(a)
          kb = key_for.call(b)
          if adjacency[ka].length == 1 || adjacency[kb].length == 1
            start_idx = idx
            start_ep = adjacency[ka].length == 1 ? 0 : 1
            break
          end
        end
        start_idx ||= 0

        used = Array.new(face_edges.length, false)
        order = []

        # Walk through connected edges while collecting ordered points
        a, b = endpoints[start_idx]
        start_point = (start_ep == 0 ? a : b)
        other_point = (start_ep == 0 ? b : a)
        points_chain = [start_point, other_point]
        used[start_idx] = true
        order << [start_idx, start_ep]

        curr_key = key_for.call(other_point)
        loop do
          candidates = adjacency[curr_key].select { |edge_idx, _| !used[edge_idx] }
          break if candidates.empty?
          edge_idx, hit_ep = candidates.first
          a2, b2 = endpoints[edge_idx]
          # If we arrived at endpoint 0, the next point is b2; otherwise a2
          next_point = (hit_ep == 0 ? b2 : a2)
          points_chain << next_point
          used[edge_idx] = true
          order << [edge_idx, hit_ep]
          curr_key = key_for.call(next_point)
        end

        # Build sorted arrays using the order and oriented by the points chain
        sorted_pairs = []
        sorted_faces = []
        (0..points_chain.length - 2).each_with_index do |i, seg_idx|
          sorted_pairs << [points_chain[i], points_chain[i + 1]]
          # faces mapped by traversal order
          if seg_idx < order.length
            sorted_faces << selected_faces[order[seg_idx][0]]
          end
        end

        [sorted_pairs, sorted_faces]
      end

      def get_vector_from_face(face)
        offset_vector = face.normal
        offset_vector.normalize!
        return offset_vector
      end

      def create_offset_path(face_edges, selected_faces, group, offset_distance)
        segments = create_offset_line_from_edges(face_edges, selected_faces, offset_distance)
        if segments.nil? || segments.empty?
          UI.messagebox("No segments created for offset path!")
          return []
        end
        path_edges = []
        segments.each do |segment|
          edge = group.entities.add_line(segment[0], segment[1])
          path_edges << edge if edge
        end
        return path_edges
      end

      def extrude_profile_along_path(group, profile_points, path_edges)
        profile_face = group.entities.add_face(profile_points)
        return unless profile_face
        profile_face.followme(path_edges)
        profile_face
      end

      # Modify an existing material's color while preserving texture
      def modify_material_color(material, color_array, alpha = nil)
        return nil unless material
        
        # Store texture info if present
        texture = material.texture
        texture_size = texture ? texture.size : nil
        
        # Set new color
        material.color = Sketchup::Color.new(color_array)
        
        # Set alpha if provided
        material.alpha = alpha if alpha
        
        # Reapply texture if it existed (changing color removes texture)
        if texture
          material.texture = texture.filename
          material.texture.size = texture_size if texture_size
        end
        
        material
      end
      
      # Create a tinted version of a material
      def create_tinted_material(base_material, tint_color, tint_strength = 0.5, new_name = nil)
        model = Sketchup.active_model
        materials = model.materials
        
        # Generate new name if not provided
        new_name ||= "#{base_material.name}_tinted"
        
        # Check if tinted version already exists
        return materials[new_name] if materials[new_name]
        
        # Create new material
        new_material = materials.add(new_name)
        
        # Blend colors
        base_color = base_material.color.to_a[0..2]  # RGB values
        tint_color = tint_color[0..2] if tint_color.length > 3
        
        blended_color = base_color.zip(tint_color).map do |base, tint|
          (base * (1 - tint_strength) + tint * tint_strength).to_i
        end
        
        new_material.color = Sketchup::Color.new(blended_color)
        new_material.alpha = base_material.alpha
        
        # Copy texture if present
        if base_material.texture
          new_material.texture = base_material.texture.filename
          new_material.texture.size = base_material.texture.size
        end
        
        new_material
      end
      
      # Adjust brightness of a material
      def adjust_material_brightness(material, factor = 1.2)
        return nil unless material
        
        color = material.color.to_a[0..2]
        
        # Adjust brightness
        adjusted = color.map do |value|
          new_val = (value * factor).to_i
          [[new_val, 255].min, 0].max  # Clamp between 0-255
        end
        
        modify_material_color(material, adjusted, material.alpha)
      end
      
      # Get or create a modified wood material
      def get_modified_wood_material(base_tint = nil, brightness = 1.0)
        model = Sketchup.active_model
        materials = model.materials
        
        # Try to get the base wood material
        wood_material = get_or_add_material(:wood)
        
        # If no modifications requested, return base
        return wood_material unless base_tint || brightness != 1.0
        
        # Create modified version
        suffix = []
        suffix << "tinted" if base_tint
        suffix << "bright#{(brightness * 100).to_i}" if brightness != 1.0
        
        modified_name = "Wood_#{suffix.join('_')}"
        
        # Check if already exists
        return materials[modified_name] if materials[modified_name]
        
        # Create modified version
        modified = materials.add(modified_name)
        
        # Copy base properties
        if wood_material
          base_color = wood_material.color.to_a[0..2]
          
          # Apply tint if requested
          if base_tint
            tinted = base_color.zip(base_tint[0..2]).map do |base, tint|
              (base * 0.7 + tint * 0.3).to_i  # 30% tint
            end
            base_color = tinted
          end
          
          # Apply brightness
          if brightness != 1.0
            base_color = base_color.map do |val|
              new_val = (val * brightness).to_i
              [[new_val, 255].min, 0].max
            end
          end
          
          modified.color = Sketchup::Color.new(base_color)
          
          # Copy texture if exists
          if wood_material.texture
            modified.texture = wood_material.texture.filename
            modified.texture.size = wood_material.texture.size
          end
        else
          # Fallback color
          modified.color = [139, 90, 43]
        end
        
        modified
      end
      
      # Example: Create wood variations
      def create_wood_variations
        base_wood = get_or_add_material(:wood)
        return unless base_wood
        
        # Create darker version
        dark_wood = create_tinted_material(
          base_wood, 
          [50, 30, 10],  # Dark brown tint
          0.4,           # 40% tint strength
          "Wood_Dark_Tinted"
        )
        
        # Create lighter version  
        light_wood = adjust_material_brightness(base_wood, 1.3)
        
        # Create reddish wood
        red_wood = create_tinted_material(
          base_wood,
          [150, 50, 30],  # Reddish tint
          0.3,
          "Wood_Cherry_Tinted"
        )
        
        {
          base: base_wood,
          dark: dark_wood,
          light: light_wood,
          red: red_wood
        }
      end

    end # class << self

  end # module SharedUtilities

end # module Viewrail