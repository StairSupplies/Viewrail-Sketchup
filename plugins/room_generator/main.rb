# SketchUp Room Generator Script
# Creates a dollhouse-style room with 3 walls and a floor
# Run this script from the Ruby Console

module RoomGenerator
  
  def self.create_room
    # Get the active model and entities
    model = Sketchup.active_model
    entities = model.active_entities
    
    # Create input dialog
    prompts = ["Room Length (inches):", "Room Width (inches):", "Room Height (inches):"]
    defaults = ["120", "96", "96"]  # Default to 10' x 8' x 8'
    input = UI.inputbox(prompts, defaults, "Room Dimensions")
    
    # Exit if user cancels
    return unless input
    
    # Parse input values (already in inches)
    length = input[0].to_f
    width = input[1].to_f
    height = input[2].to_f
    
    # Wall thickness
    wall_thickness = 5.0
    
    # Validate inputs
    if length <= 0 || width <= 0 || height <= 0
      UI.messagebox("Please enter positive values for all dimensions.")
      return
    end
    
    if length <= wall_thickness * 2 || width <= wall_thickness
      UI.messagebox("Room dimensions are too small for the wall thickness.")
      return
    end
    
    # Start operation for undo functionality
    model.start_operation('Create Room', true)
    
    # Create a group for the entire room
    room_group = entities.add_group
    room_entities = room_group.entities
    
    begin
      # Define floor thickness
      floor_thickness = wall_thickness
      
      # Create the floor
      floor_points = [
        [0, 0, 0],
        [length, 0, 0],
        [length, width, 0],
        [0, width, 0]
      ]
      
      # Create floor as a box (with thickness)
      floor_face = room_entities.add_face(floor_points)
      floor_face.pushpull(floor_thickness)
      
      # Create the back wall (at width distance)
      back_wall_points = [
        [0, width - wall_thickness, 0],
        [length, width - wall_thickness, 0],
        [length, width - wall_thickness, height],
        [0, width - wall_thickness, height]
      ]
      back_wall_face = room_entities.add_face(back_wall_points)
      back_wall_face.pushpull(-wall_thickness)
      
      # Create the left wall
      left_wall_points = [
        [0, 0, 0],
        [wall_thickness, 0, 0],
        [wall_thickness, 0, height],
        [0, 0, height]
      ]
      left_wall_face = room_entities.add_face(left_wall_points)
      left_wall_face.pushpull(-(width - wall_thickness))
      
      # Create the right wall
      right_wall_points = [
        [length - wall_thickness, 0, 0],
        [length, 0, 0],
        [length, 0, height],
        [length - wall_thickness, 0, height]
      ]
      right_wall_face = room_entities.add_face(right_wall_points)
      right_wall_face.pushpull(-(width - wall_thickness))
      
      # Name the group
      room_group.name = "Room #{length}\" x #{width}\" x #{height}\""
      
      # Commit the operation
      model.commit_operation
      
      # Zoom to fit the new room
      Sketchup.active_model.active_view.zoom_extents
      
      # Display success message
      UI.messagebox("Room created successfully!\n\nDimensions:\n" +
                   "Length: #{length}\"\n" +
                   "Width: #{width}\"\n" +
                   "Height: #{height}\"\n" +
                   "Wall Thickness: #{wall_thickness}\"")
      
    rescue => e
      # If there's an error, abort the operation
      model.abort_operation
      UI.messagebox("Error creating room: #{e.message}")
    end
  end
  
end

# Run the room generator
RoomGenerator.create_room