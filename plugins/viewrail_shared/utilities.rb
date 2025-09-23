# viewrail_shared/utilities.rb
require_relative 'form_renderer'

module Viewrail

  module SharedUtilities

    class << self

      def get_or_create_glass_material(model)
        materials = model.materials
        glass_material = materials["Glass_Transparent"]
        if !glass_material
          glass_material = materials.add("Glass_Transparent")
          glass_material.color = [200, 220, 240, 128]
          glass_material.alpha = 0.3
        end
        glass_material
      end
      
      def get_or_create_cable_material(model)
        materials = model.materials
        cable_material = materials["Cable_Steel"]
        if !cable_material
          cable_material = materials.add("Cable_Steel")
          cable_material.color = [80, 80, 80]
        end
        cable_material
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