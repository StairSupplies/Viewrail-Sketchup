# viewrail_shared/utilities.rb
require_relative 'form_renderer'

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
        material = materials[material_def[:name]]
        
        # Create material if it doesn't exist
        if !material
          material = add_material_to_model(materials, material_def)
        end
        
        return material
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

      #================ IN DEVELOPMENT================

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

    end # class << self

  end # module SharedUtilities

end # module Viewrail