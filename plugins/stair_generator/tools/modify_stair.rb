# tools/modify_stair.rb

require 'erb'
require_relative '../../viewrail_shared/utilities'
require_relative 'create_straight'
require_relative 'create_90'

module Viewrail
  module StairGenerator
    module Tools
      class ModifyStairTool
        
        def self.activate
          # Get parameters from selected stair
          params = Viewrail::StairGenerator.get_selected_stair_parameters
          
          if params.nil?
            UI.messagebox("Please select a stair group to modify.", MB_OK, "No Stair Selected")
            return
          end
          
          # Store reference to the selected entity before opening dialog
          model = Sketchup.active_model
          @selected_stair = model.selection.first
          
          # Open the appropriate form based on stair type
          case params[:type]
          when :straight
            show_straight_modify_form(params)
          when :landing_90
            show_landing_modify_form(params)
          else
            UI.messagebox("Unknown stair type", MB_OK, "Error")
          end
        end
        
        def self.show_straight_modify_form(existing_params)
          # Create the HTML dialog
          dialog = UI::HtmlDialog.new(
            {
              :dialog_title => "Modify Straight Stairs",
              :preferences_key => "com.viewrail.stair_generator.modify",
              :scrollable => false,
              :resizable => false,
              :width => 500,
              :height => 720,
              :left => 100,
              :top => 100,
              :min_width => 500,
              :min_height => 720,
              :max_width => 500,
              :max_height => 820,
              :style => UI::HtmlDialog::STYLE_DIALOG
            }
          )
          
          # Render the HTML content with existing values
          begin
            renderer = Viewrail::SharedUtilities::FormRenderer.new(existing_params)
            html_content = renderer.render("C:/Viewrail-Sketchup/plugins/stair_generator/forms/stair_form.html.erb")
            dialog.set_html(html_content)
          rescue => e
            UI.messagebox("Error loading form template: #{e.message}")
            return
          end
          
          # Add callback for updating the stairs
          dialog.add_action_callback("create_stairs") do |action_context, params|
            values = JSON.parse(params)
            
            # Store the values for next time
            Viewrail::StairGenerator.last_form_values(:straight).merge!(values.transform_keys(&:to_sym))
            
            dialog.close
            
            # Replace the existing stair
            if @selected_stair && @selected_stair.valid?
              model = Sketchup.active_model
              
              model.start_operation("Modify Stairs", true)
              
              begin
                # Get the transformation of the existing stair
                transformation = @selected_stair.transformation
                position = transformation.origin.to_a
                
                # Delete the old stair
                @selected_stair.erase!
                
                # Create new stair with updated parameters
                params_with_width = values.merge({"tread_width" => 36.0})
                new_stair = Viewrail::StairGenerator.create_stair_segment(params_with_width, position)
                
                # Store all parameters for future modification
                Viewrail::StairGenerator.store_stair_parameters(new_stair, values, :straight)
                
                # Select the new stair
                model.selection.clear
                model.selection.add(new_stair)
                
                model.commit_operation
                
              rescue => e
                model.abort_operation
                UI.messagebox("Error modifying stairs: #{e.message}")
              end
            end
            
            @selected_stair = nil
          end
          
          dialog.add_action_callback("cancel") do |action_context|
            dialog.close
            @selected_stair = nil
          end
          
          dialog.show
        end
        
        def self.show_landing_modify_form(existing_params)
          # Create the HTML dialog for modifying 90-degree stairs
          dialog = UI::HtmlDialog.new(
            {
              :dialog_title => "Modify 90° Stairs",
              :preferences_key => "com.viewrail.landing_stair_generator.modify",
              :scrollable => true,
              :resizable => true,
              :width => 650,
              :height => 700,
              :left => 100,
              :top => 50,
              :min_width => 625,
              :min_height => 650,
              :max_width => 750,
              :max_height => 1000,
              :style => UI::HtmlDialog::STYLE_DIALOG
            }
          )
          
          # Render the HTML content with existing values
          begin
            renderer = Viewrail::SharedUtilities::FormRenderer.new(existing_params)
            html_content = renderer.render("C:/Viewrail-Sketchup/plugins/stair_generator/forms/90_stair_form.html.erb")
            dialog.set_html(html_content)
          rescue => e
            UI.messagebox("Error loading landing form template: #{e.message}")
            return
          end
          
          # Add resize callback
          dialog.add_action_callback("resize_dialog") do |action_context, params|
            dimensions = JSON.parse(params)
            dialog.set_size(dimensions["width"], dimensions["height"])
          end
          
          # Add callback for updating the 90-degree stairs
          dialog.add_action_callback("create_landing_stairs") do |action_context, params|
            values = JSON.parse(params)
            
            # Store the values for next time
            Viewrail::StairGenerator.last_form_values(:landing_90).merge!(values.transform_keys(&:to_sym))
            
            dialog.close
            
            # Replace the existing stair
            if @selected_stair && @selected_stair.valid?
              model = Sketchup.active_model
              
              model.start_operation("Modify 90° Stairs", true)
              
              begin
                # Get the transformation of the existing stair
                transformation = @selected_stair.transformation
                position = transformation.origin.to_a
                
                # Delete the old stair
                @selected_stair.erase!
                
                # Create new 90-degree stairs with updated parameters
                new_stair = Viewrail::StairGenerator::Tools::NinetyStairMenu.create_90_geometry(values, position)
                
                # Store all parameters for future modification
                if new_stair
                  Viewrail::StairGenerator.store_stair_parameters(new_stair, values, :landing_90)
                  
                  # Select the new stair
                  model.selection.clear
                  model.selection.add(new_stair)
                end
                
                model.commit_operation
                
              rescue => e
                model.abort_operation
                UI.messagebox("Error modifying 90° stairs: #{e.message}")
              end
            end
            
            @selected_stair = nil
          end
          
          dialog.add_action_callback("cancel") do |action_context|
            dialog.close
            @selected_stair = nil
          end
          
          dialog.show
        end
        
      end # class ModifyStairTool
    end # module Tools
  end # module StairGenerator
end # module Viewrail