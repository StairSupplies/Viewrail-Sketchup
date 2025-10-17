module Viewrail
  module SharedUtilities
    module Viewport

      def self.draw_selected_faces(view, selected_faces, face_edges)
        selected_faces.each_with_index do |face, index|
          draw_face_highlight(view, face,
            fill_color: [100, 200, 100, 128],  # Green semi-transparent
            edge_color: [50, 150, 50, 200],    # Darker green for edges
            edge_width: 2
          )
          draw_face_edge_markers(view, face_edges[index]) if face_edges[index]
        end
      end # draw_selected_faces

      def self.draw_face_highlight(view, face, fill_color:, edge_color:, edge_width:)
        view.drawing_color = fill_color
        draw_face_polygon(view, face)

        view.drawing_color = edge_color
        view.line_width = edge_width
        face.edges.each do |edge|
          view.draw_line(edge.vertices[0].position, edge.vertices[1].position)
        end
      end # draw_face_highlight

      def self.draw_face_edge_markers(view, edge_points)
        view.drawing_color = "blue"
        view.line_width = 4
        view.draw_line(edge_points[0], edge_points[1])

        view.drawing_color = "red"
        view.draw_points(edge_points[0], 8)
        view.draw_points(edge_points[1], 8)
      end # draw_face_edge_markers

      def self.draw_hover_face(view, hover_face, hover_edge)
        draw_face_highlight(view, hover_face,
          fill_color: [150, 150, 200, 64],   # Light blue semi-transparent
          edge_color: [100, 100, 200, 128],  # Light blue edges
          edge_width: 1
        )
        draw_hover_edge_preview(view, hover_edge) if hover_edge
      end # draw_hover_face

      def self.draw_hover_edge_preview(view, hover_edge)
        view.drawing_color = [100, 100, 255, 200]
        view.line_width = 3
        view.line_stipple = "-"
        view.draw_line(hover_edge[0], hover_edge[1])
        view.line_stipple = ""
      end # draw_hover_edge_preview

      def self.draw_face_polygon(view, face)
        mesh = face.mesh
        mesh.polygons.each do |polygon|
          points = polygon.map { |vertex_index| mesh.point_at(vertex_index.abs) }
          view.draw(GL_POLYGON, points)
        end
      end # draw_face_polygon

    end # module Viewport
  end # module SharedUtilities
end # module Viewrail
