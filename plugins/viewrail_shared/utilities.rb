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
          add_material_to_model(materials, material_def)
        end
        
        material
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
        
        if horizontal_edges.empty?
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

    end # class << self

  end # module SharedUtilities

end # module Viewrail