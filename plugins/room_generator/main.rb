module Viewrail
  module RoomGenerator
    #Version 4
    class << self
      
      # Initialize last values at class level
      def last_values
        @last_values ||= {
          :length => 120.0,
          :width => 96.0,
          :height => 96.0,
          :num_treads => 13,
          :stair_rise => 7.5,
          :total_rise => 105.0
        }
      end
      
      def create_room
        # Get the active model and entities
        model = Sketchup.active_model
        entities = model.active_entities
        
        # Create input dialog
        prompts = ["Room Length (inches):", "Room Width (inches):", "Room Height (inches):"]
        defaults = [last_values[:length].to_s, last_values[:width].to_s, last_values[:height].to_s]
        input = UI.inputbox(prompts, defaults, "Room Dimensions")
        
        # Exit if user cancels
        return unless input
        
        # Parse input values (already in inches)
        length = input[0].to_f
        width = input[1].to_f
        height = input[2].to_f
        
        # Update stored values
        last_values[:length] = length
        last_values[:width] = width
        last_values[:height] = height
        
        # Create the room
        create_room_geometry(length, width, height)
      end
      
      def create_room_with_HTML
        # Create the HTML dialog
        dialog = UI::HtmlDialog.new(
          {
            :dialog_title => "Room Generator",
            :preferences_key => "com.viewrail.room_generator",
            :scrollable => false,
            :resizable => false,
            :width => 500,
            :height => 450,
            :left => 100,
            :top => 100,
            :min_width => 500,
            :min_height => 450,
            :max_width => 500,
            :max_height => 450,
            :style => UI::HtmlDialog::STYLE_DIALOG
          }
        )
        
        # Build the HTML content with fixed encoding
        html_content = <<-HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <title>Room Generator</title>
          <style>
            body {
              font-family: Arial, sans-serif;
              margin: 0;
              padding: 20px;
              background-color: #f5f5f5;
            }
            .container {
              display: flex;
              gap: 30px;
            }
            .column {
              flex: 1;
            }
            h3 {
              margin-top: 0;
              color: #333;
              border-bottom: 2px solid #0078D7;
              padding-bottom: 5px;
            }
            .form-group {
              margin-bottom: 15px;
            }
            label {
              display: block;
              margin-bottom: 5px;
              color: #555;
              font-weight: bold;
              font-size: 12px;
            }
            input[type="number"] {
              width: 100%;
              padding: 8px;
              border: 1px solid #ccc;
              border-radius: 4px;
              box-sizing: border-box;
              font-size: 14px;
            }
            input[type="number"]:focus {
              outline: none;
              border-color: #0078D7;
              box-shadow: 0 0 5px rgba(0, 120, 215, 0.3);
            }
            input[readonly] {
              background-color: #e9e9e9;
            }
            .button-container {
              margin-top: 30px;
              text-align: center;
              padding-top: 20px;
              border-top: 1px solid #ddd;
            }
            button {
              padding: 10px 25px;
              margin: 0 10px;
              border: none;
              border-radius: 4px;
              font-size: 14px;
              cursor: pointer;
              transition: background-color 0.3s;
            }
            .btn-primary {
              background-color: #0078D7;
              color: white;
            }
            .btn-primary:hover {
              background-color: #005ca0;
            }
            .btn-secondary {
              background-color: #6c757d;
              color: white;
            }
            .btn-secondary:hover {
              background-color: #545b62;
            }
            .error {
              color: red;
              font-size: 12px;
              margin-top: 5px;
              display: none;
            }
            .info {
              background-color: #e3f2fd;
              border-left: 4px solid #0078D7;
              padding: 10px;
              margin-top: 20px;
              font-size: 12px;
              color: #555;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="column">
              <h3>Room Dimensions</h3>
              <div class="form-group">
                <label for="length">Room Length (inches):</label>
                <input type="number" id="length" value="#{last_values[:length]}" min="0" step="0.01">
                <div class="error" id="length-error"></div>
              </div>
              <div class="form-group">
                <label for="width">Room Width (inches):</label>
                <input type="number" id="width" value="#{last_values[:width]}" min="0" step="0.01">
                <div class="error" id="width-error"></div>
              </div>
              <div class="form-group">
                <label for="height">Room Height (inches):</label>
                <input type="number" id="height" value="#{last_values[:height]}" min="0" step="0.01">
                <div class="error" id="height-error"></div>
              </div>
              <div class="info">
                Wall Thickness: 5 inches<br>
                Front wall will be open (dollhouse style)
              </div>
            </div>
            
            <div class="column">
              <h3>Stair Parameters</h3>
              <div class="form-group">
                <label for="num_treads">Number of Treads:</label>
                <input type="number" id="num_treads" value="#{last_values[:num_treads]}" min="1" max="22" step="1">
                <div class="error" id="treads-error"></div>
              </div>
              <div class="form-group">
                <label for="stair_rise">Stair Rise (inches):</label>
                <input type="number" id="stair_rise" value="#{last_values[:stair_rise].round(2)}" min="6" max="9" step="0.01" readonly>
                <div class="error" id="rise-error"></div>
              </div>
              <div class="form-group">
                <label for="total_rise">Total Rise (inches):</label>
                <input type="number" id="total_rise" value="#{last_values[:total_rise].round(2)}" min="0" step="0.01">
                <div class="error" id="total-rise-error"></div>
              </div>
              <div class="info">
                Note: Stair Rise = Total Rise ÷ (Number of Treads + 1)<br>
                Stair Rise is calculated automatically<br>
                Stair features will be added in future updates
              </div>
            </div>
          </div>
          
          <div class="button-container">
            <button class="btn-primary" onclick="createRoom()">Create Room</button>
            <button class="btn-secondary" onclick="cancel()">Cancel</button>
          </div>
          
          <script>
            let isUpdating = false;
            
            // Get input elements
            const numTreadsInput = document.getElementById('num_treads');
            const stairRiseInput = document.getElementById('stair_rise');
            const totalRiseInput = document.getElementById('total_rise');
            
            // Calculate Total Rise from Number of Treads and Stair Rise
            function calculateTotalRise() {
              if (isUpdating) return;
              isUpdating = true;
              
              const numTreads = parseInt(numTreadsInput.value) || 0;
              const stairRise = parseFloat(stairRiseInput.value) || 0;
              
              if (numTreads > 0 && stairRise > 0) {
                const totalRise = (numTreads + 1) * stairRise;
                totalRiseInput.value = totalRise.toFixed(2);
              }
              
              isUpdating = false;
              validateInputs();
            }
            
            // Calculate Stair Rise from Total Rise and Number of Treads
            function calculateStairRise() {
              if (isUpdating) return;
              isUpdating = true;
              
              const numTreads = parseInt(numTreadsInput.value) || 0;
              const totalRise = parseFloat(totalRiseInput.value) || 0;
              
              if (numTreads > 0 && totalRise > 0) {
                const stairRise = totalRise / (numTreads + 1);
                stairRiseInput.value = stairRise.toFixed(2);
              }
              
              isUpdating = false;
              validateInputs();
            }
            
            // Add event listeners
            numTreadsInput.addEventListener('input', calculateStairRise);
            //stairRiseInput.addEventListener('input', calculateTotalRise);
            totalRiseInput.addEventListener('input', calculateStairRise);
            
            // Validation function
            function validateInputs() {
              let isValid = true;
              
              // Validate room dimensions
              const length = parseFloat(document.getElementById('length').value);
              const width = parseFloat(document.getElementById('width').value);
              const height = parseFloat(document.getElementById('height').value);
              
              // Clear previous errors
              document.querySelectorAll('.error').forEach(e => e.style.display = 'none');
              
              if (length <= 0 || isNaN(length)) {
                document.getElementById('length-error').textContent = 'Length must be positive';
                document.getElementById('length-error').style.display = 'block';
                isValid = false;
              } else if (length <= 10) {
                document.getElementById('length-error').textContent = 'Length too small for wall thickness';
                document.getElementById('length-error').style.display = 'block';
                isValid = false;
              }
              
              if (width <= 0 || isNaN(width)) {
                document.getElementById('width-error').textContent = 'Width must be positive';
                document.getElementById('width-error').style.display = 'block';
                isValid = false;
              } else if (width <= 5) {
                document.getElementById('width-error').textContent = 'Width too small for wall thickness';
                document.getElementById('width-error').style.display = 'block';
                isValid = false;
              }
              
              if (height <= 0 || isNaN(height)) {
                document.getElementById('height-error').textContent = 'Height must be positive';
                document.getElementById('height-error').style.display = 'block';
                isValid = false;
              }
              
              // Validate stair parameters
              const numTreads = parseInt(numTreadsInput.value);
              const stairRise = parseFloat(stairRiseInput.value);
              
              if (numTreads < 1 || numTreads > 22) {
                document.getElementById('treads-error').textContent = 'Must be between 1 and 22';
                document.getElementById('treads-error').style.display = 'block';
                isValid = false;
              }
              
              if (stairRise < 6 || stairRise > 9) {
                document.getElementById('rise-error').textContent = 'Must be between 6" and 9"';
                document.getElementById('rise-error').style.display = 'block';
                isValid = false;
              }
              
              return isValid;
            }
            
            function createRoom() {
              if (!validateInputs()) {
                return;
              }
              
              const values = {
                length: parseFloat(document.getElementById('length').value),
                width: parseFloat(document.getElementById('width').value),
                height: parseFloat(document.getElementById('height').value),
                num_treads: parseInt(document.getElementById('num_treads').value),
                stair_rise: parseFloat(document.getElementById('stair_rise').value),
                total_rise: parseFloat(document.getElementById('total_rise').value)
              };
              
              window.location = 'skp:create_room@' + JSON.stringify(values);
            }
            
            function cancel() {
              window.location = 'skp:cancel';
            }
            
            // Initial calculation
            calculateTotalRise();
          </script>
        </body>
        </html>
        HTML
        
        dialog.set_html(html_content)
        
        # Add callbacks
        dialog.add_action_callback("create_room") do |action_context, params|
          values = JSON.parse(params)
          
          # Store the values for next time
          last_values[:length] = values["length"]
          last_values[:width] = values["width"]
          last_values[:height] = values["height"]
          last_values[:num_treads] = values["num_treads"]
          last_values[:stair_rise] = values["stair_rise"]
          last_values[:total_rise] = values["total_rise"]
          
          dialog.close
          
          # Create the room with the original dimensions
          create_room_geometry(values["length"], values["width"], values["height"])
          
          # Store stair parameters for future use
          puts "Stair parameters stored:"
          puts "  Number of Treads: #{values["num_treads"]}"
          puts "  Stair Rise: #{values["stair_rise"].round(2)}\""
          puts "  Total Rise: #{values["total_rise"].round(2)}\""
        end
        
        dialog.add_action_callback("cancel") do |action_context|
          dialog.close
        end
        
        dialog.show
      end

      def create_room_geometry(length, width, height)
        # Get the active model and entities
        model = Sketchup.active_model
        entities = model.active_entities
        
        # Wall thickness
        wall_thickness = 5.0
        
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
          floor_face.pushpull(-floor_thickness)
          
          # Create the back wall (at width distance)
          back_wall_points = [
            [0, width - wall_thickness, 0],
            [length, width - wall_thickness, 0],
            [length, width - wall_thickness, height],
            [0, width - wall_thickness, height]
          ]
          back_wall_face = room_entities.add_face(back_wall_points)
          back_wall_face.pushpull(wall_thickness)
          
          # Create the left wall
          left_wall_points = [
            [0, 0, 0],
            [wall_thickness, 0, 0],
            [wall_thickness, 0, height],
            [0, 0, height]
          ]
          left_wall_face = room_entities.add_face(left_wall_points)
          left_wall_face.pushpull(width - wall_thickness)
          
          # Create the right wall
          right_wall_points = [
            [length - wall_thickness, 0, 0],
            [length, 0, 0],
            [length, 0, height],
            [length - wall_thickness, 0, height]
          ]
          right_wall_face = room_entities.add_face(right_wall_points)
          right_wall_face.pushpull(width - wall_thickness)
          
          # Name the group
          room_group.name = "Room #{length}\" x #{width}\" x #{height}\""
          
          # Store stair parameters as attributes on the group for future use
          room_group.set_attribute("room_generator", "num_treads", last_values[:num_treads])
          room_group.set_attribute("room_generator", "stair_rise", last_values[:stair_rise])
          room_group.set_attribute("room_generator", "total_rise", last_values[:total_rise])
          
          # Commit the operation
          model.commit_operation
          
          # Zoom to fit the new room
          Sketchup.active_model.active_view.zoom_extents
          
          # Display success message
          UI.messagebox("Room created successfully!\n\nRoom Dimensions:\n" +
                       "Length: #{length}\"\n" +
                       "Width: #{width}\"\n" +
                       "Height: #{height}\"\n" +
                       "Wall Thickness: #{wall_thickness}\"\n\n" +
                       "Stair Parameters (stored for future use):\n" +
                       "Number of Treads: #{last_values[:num_treads]}\n" +
                       "Stair Rise: #{last_values[:stair_rise].round(2)}\"\n" +
                       "Total Rise: #{last_values[:total_rise].round(2)}\"")
          
        rescue => e
          # If there's an error, abort the operation
          model.abort_operation
          UI.messagebox("Error creating room: #{e.message}")
        end
      end
      
      def create_room_with_window
        UI.messagebox("Room with window feature coming soon!")
      end
      
      def show_about
        UI.messagebox(
          "Room Generator Extension v1.0.0\n\n" +
          "Creates dollhouse-style rooms for architectural visualization.\n\n" +
          "Features:\n" +
          "• 3 walls with open front\n" +
          "• Customizable dimensions\n" +
          "• 5-inch wall thickness\n\n" +
          "© 2025 Viewrail",
          MB_OK,
          "About Room Generator"
        )
      end
      
    end
    
    # Create toolbar
    unless file_loaded?(__FILE__)
      
      # Create the toolbar
      toolbar = UI::Toolbar.new("Room Generator")
      
      # Create commands
      cmd_room = UI::Command.new("Create Room") {
        self.create_room
      }
      cmd_room.small_icon = "room_generator/icons/room_16.png"
      cmd_room.large_icon = "room_generator/icons/room_24.png"
      cmd_room.tooltip = "Create Room"
      cmd_room.status_bar_text = "Create a dollhouse-style room with 3 walls and a floor"
      cmd_room.menu_text = "Create Room"
      
      cmd_room_html = UI::Command.new("Use HTML") {
        self.create_room_with_HTML
      }
      cmd_room_html.small_icon = "room_generator/icons/room_door_16.png"
      cmd_room_html.large_icon = "room_generator/icons/room_door_24.png"
      cmd_room_html.tooltip = "Create Room with HTML Dialog"
      cmd_room_html.status_bar_text = "Create a room using HTML dialog with stair parameters"
      cmd_room_html.menu_text = "Create Room (HTML)"
      
      cmd_room_window = UI::Command.new("Room with Window") {
        self.create_room_with_window
      }
      cmd_room_window.small_icon = "room_generator/icons/room_window_16.png"
      cmd_room_window.large_icon = "room_generator/icons/room_window_24.png"
      cmd_room_window.tooltip = "Create Room with Window"
      cmd_room_window.status_bar_text = "Create a room with a window opening"
      cmd_room_window.menu_text = "Create Room with Window"
      
      cmd_about = UI::Command.new("About") {
        self.show_about
      }
      cmd_about.small_icon = "room_generator/icons/about_16.png"
      cmd_about.large_icon = "room_generator/icons/about_24.png"
      cmd_about.tooltip = "About Room Generator"
      cmd_about.status_bar_text = "About Room Generator Extension"
      cmd_about.menu_text = "About"
      
      # Add commands to toolbar
      toolbar = toolbar.add_item(cmd_room)
      toolbar = toolbar.add_item(cmd_room_html)
      toolbar = toolbar.add_item(cmd_room_window)
      toolbar = toolbar.add_separator
      toolbar = toolbar.add_item(cmd_about)
      
      # Show the toolbar
      toolbar.show
      
      # Create menu
      menu = UI.menu("Extensions")
      room_menu = menu.add_submenu("Room Generator")
      room_menu.add_item(cmd_room)
      room_menu.add_item(cmd_room_html)
      room_menu.add_item(cmd_room_window)
      room_menu.add_separator
      room_menu.add_item(cmd_about)
      
      # Create context menu items (right-click menu)
      UI.add_context_menu_handler do |context_menu|
        context_menu.add_separator
        room_context = context_menu.add_submenu("Room Generator")
        room_context.add_item(cmd_room)
        room_context.add_item(cmd_room_html)
        room_context.add_item(cmd_room_window)
      end
      
      file_loaded(__FILE__)
    end    
  end
end