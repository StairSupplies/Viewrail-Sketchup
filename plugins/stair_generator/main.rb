require 'erb'
require_relative '../viewrail_shared/utilities'
require_relative 'tools/create_u'
require_relative 'tools/create_sb'
require_relative 'tools/create_90'
require_relative 'tools/create_straight'
require_relative 'tools/modify_stair'
module Viewrail

  module StairGenerator

    class << self
      # Cache for selection validation - MODIFY TOOL
      attr_accessor :selection_cache, :cached_validation_result

       # Initialize cache
      def init_selection_cache
        @selection_cache_id = nil
        @cached_validation_result = false
      end

      def last_form_values(stair_type = :straight)
        @last_form_values ||= {}
        @last_form_values[stair_type] ||= case stair_type
          when :straight
            {
              :num_treads => 13,
              :tread_run => 11.0,
              :tread_width => 36.0,
              :total_tread_run => 143.0,
              :stair_rise => 7.5,
              :total_rise => 105.0,
              :glass_railing => "None"
            }
          when :landing_90
            {
              :num_treads_lower => 6,
              :num_treads_upper => 6,
              :header_to_wall => 144.0,
              :tread_width_lower => 36.0,
              :tread_width_upper => 36.0,
              :landing_width => 36.0,
              :landing_depth => 36.0,
              :tread_run => 11.0,
              :stair_rise => 7.5,
              :total_rise => 91.0,
              :turn_direction => "Left",
              :glass_railing => "None"
            }
          when :landing_u
            {
              :num_treads_lower => 4,
              :num_treads_middle => 4,
              :num_treads_upper => 4,
              :header_to_wall => 180.0,
              :wall_to_wall => 120.0,
              :tread_width_lower => 36.0,
              :tread_width_middle => 36.0,
              :tread_width_upper => 36.0,
              :lower_landing_width => 36.0,
              :lower_landing_depth => 36.0,
              :upper_landing_width => 36.0,
              :upper_landing_depth => 36.0,
              :tread_run => 11.0,
              :stair_rise => 7.5,
              :total_rise => 105.0,
              :turn_direction => "Left",
              :glass_railing => "None"
            }
          when :switchback
            {
              :num_treads_lower => 7,
              :num_treads_upper => 6,
              :header_to_wall => 102.0,
              :wall_to_wall => 72.0,
              :maximize_tread_width => true,
              :tread_width_lower => 36.0,
              :tread_width_upper => 36.0,
              :landing_width => 72.0,
              :landing_depth => 36.0,
              :tread_run => 11.0,
              :stair_rise => 7.0,
              :total_rise => 105.0,
              :turn_direction => "Left",
              :glass_railing => "None"
            }
          else
            {}
        end
      end

      def add_stair_menu
        Viewrail::StairGenerator::Tools::StraightStairMenu.show
      end

      def add_landing_stair_menu
        Viewrail::StairGenerator::Tools::NinetyStairMenu.show
      end

      def add_switchback_stair_menu
        Viewrail::StairGenerator::Tools::SwitchbackStairMenu.show
      end

      def add_u_stair_menu
        Viewrail::StairGenerator::Tools::UStairMenu.show
      end

      # Create a single stair segment (modular method)
      def create_stair_segment(params, start_point = [0, 0, 0], lastStair = false)
        model = Sketchup.active_model
        entities = model.active_entities

        # Extract parameters
        num_treads = params["num_treads"]
        tread_run = params["tread_run"]
        tread_width = params["tread_width"] || 36.0
        stair_rise = params["stair_rise"]
        glass_railing = params["glass_railing"] || "None"
        segment_name = params["segment_name"] || "Stairs"

        reveal = 1
        tread_thickness = stair_rise - reveal
        riser_thickness = 1.0

        # Glass panel dimensions
        glass_thickness = 0.5
        glass_inset = 1.0
        glass_height = 36.0

        # Create a group for this stair segment
        stairs_group = entities.add_group
        stairs_entities = stairs_group.entities

        # Apply starting transformation
        transform = Geom::Transformation.new(start_point)
        stairs_group.transform!(transform)

        # Create each step
        (1..num_treads).each do |i|
          x_position = (i - 1) * tread_run
          z_position = i * stair_rise

          # Create tread
          stack_overhang = 5

          # set the overhand to 0 for the last tread
          if lastStair and i == num_treads
            stack_overhang = 0
          end

          tread_points = [
            [x_position, 0, z_position],
            [x_position + tread_run + stack_overhang, 0, z_position],
            [x_position + tread_run + stack_overhang, tread_width, z_position],
            [x_position, tread_width, z_position]
          ]
          tread_face = stairs_entities.add_face(tread_points)
          tread_face.pushpull(-tread_thickness) if tread_face

          # Create riser
          nosing_value = 0.75
          riser_points = [
            [x_position + nosing_value, nosing_value, z_position - tread_thickness],
            [x_position + tread_run + stack_overhang, nosing_value, z_position - tread_thickness],
            [x_position + tread_run + stack_overhang, tread_width - nosing_value, z_position - tread_thickness],
            [x_position + nosing_value, tread_width - nosing_value, z_position - tread_thickness]
          ]
          riser_face = stairs_entities.add_face(riser_points)
          riser_face.pushpull(riser_thickness) if riser_face
        end

        # Add glass railings if specified
        if glass_railing != "None"
          add_glass_railings_to_segment(stairs_entities, num_treads, tread_run, tread_width,
                                       stair_rise, glass_railing, glass_thickness, glass_inset, glass_height)
        end

        # Name the group
        stairs_group.name = "#{segment_name} - #{num_treads} treads"

        # Store parameters as attributes
        stairs_group.set_attribute("stair_generator", "num_treads", num_treads)
        stairs_group.set_attribute("stair_generator", "tread_run", tread_run)
        stairs_group.set_attribute("stair_generator", "tread_width", tread_width)
        stairs_group.set_attribute("stair_generator", "stair_rise", stair_rise)
        stairs_group.set_attribute("stair_generator", "glass_railing", glass_railing)
        stairs_group.set_attribute("stair_generator", "segment_type", "stairs")

        return stairs_group
      end

      # Create landing (modular method)
      def create_landing(params, position = [0, 0, 0])

        model = Sketchup.active_model
        entities = model.active_entities

        stack_overhang = 5
        width = params["width"] + stack_overhang # Add overhang
        depth = params["depth"]
        thickness = params["thickness"]
        glass_railing = params["glass_railing"] || "None"
        turn_direction = params["turn_direction"] || "Left"

        # Create a group for the landing
        landing_group = entities.add_group
        landing_entities = landing_group.entities

        # Create landing platform
        landing_points = [
          [0, 0, 0],
          [depth, 0, 0],
          [depth, width, 0],
          [0, width, 0]
        ]

        # Create riser
        nosing_value = 0.75
        reveal = 1
        riser_thickness = 1.0
        riser_points = [
          [nosing_value, nosing_value, -(thickness+reveal)],
          [depth-nosing_value, nosing_value, -(thickness+reveal)],
          [depth-nosing_value, width - nosing_value, -(thickness+reveal)],
          [nosing_value, width - nosing_value, -(thickness+reveal)]
        ]

        landing_face = landing_entities.add_face(landing_points)
        landing_face.pushpull(thickness) if landing_face

        riser_face = landing_entities.add_face(riser_points)
        riser_face.pushpull(riser_thickness) if riser_face

        # Add glass railings to landing if specified
        if glass_railing != "None"
          edges_to_rail = []
          if turn_direction == "Left"
            case glass_railing
            when "Inner"
              # do nothing for now
            when "Outer", "Both"
              edges_to_rail = ["back", "right"]
            end
          else # Right turn
            case glass_railing
            when "Inner"
              # do nothing for now
            when "Outer", "Both"
              edges_to_rail = ["back", "left"]
            end
          end

          add_glass_railings_to_landing(
            landing_entities,
            {
              width: width,
              depth: depth,
              thickness: thickness,
              glass_railing: glass_railing,
              turn_direction: turn_direction
            },
            edges_to_rail
            )
        end

        # Apply position transformation
        transform = Geom::Transformation.new(position)
        # If right turn, shift the landing 5" to align properly
        transform = Geom::Transformation.new([position[0], position[1] - 5, position[2]]) unless turn_direction == "Left"
        landing_group.transform!(transform)

        # Name the group
        landing_group.name = "Landing - #{width.round}\" x #{depth.round}\""

        # Store parameters as attributes
        landing_group.set_attribute("stair_generator", "width", width)
        landing_group.set_attribute("stair_generator", "depth", depth)
        landing_group.set_attribute("stair_generator", "thickness", thickness)
        landing_group.set_attribute("stair_generator", "glass_railing", glass_railing)
        landing_group.set_attribute("stair_generator", "segment_type", "landing")

        return landing_group
      end # create_landing

      # Create stack landing (modular method)
      def create_wide_landing(params, position = [0, 0, 0])

        model = Sketchup.active_model
        entities = model.active_entities

        width = params["width"]
        depth = params["depth"]
        thickness = params["thickness"]
        glass_railing = params["glass_railing"] || "None"
        turn_direction = params["turn_direction"] || "Left"

        # Create a group for the landing
        landing_group = entities.add_group
        landing_entities = landing_group.entities

        # Create landing platform
        landing_points = [
          [0, 0, 0],
          [depth, 0, 0],
          [depth, width, 0],
          [0, width, 0]
        ]

        # Create riser
          nosing_value = 0.75
          reveal = 1
          riser_thickness = 1.0
          riser_points = [
            [nosing_value, nosing_value, -(thickness+reveal)],
            [depth-nosing_value, nosing_value, -(thickness+reveal)],
            [depth-nosing_value, width - nosing_value, -(thickness+reveal)],
            [nosing_value, width - nosing_value, -(thickness+reveal)]
          ]


        landing_face = landing_entities.add_face(landing_points)
        landing_face.pushpull(thickness) if landing_face

        riser_face = landing_entities.add_face(riser_points)
        riser_face.pushpull(riser_thickness) if riser_face

        # Add glass railings to landing if specified
        if glass_railing != "None"
          edges_to_rail = []

          case glass_railing
          when "Inner", "None"
            # do nothing
          when "Outer", "Both"
            edges_to_rail = ["left", "back", "right"]
          end # case

          add_glass_railings_to_landing(
            landing_entities,
            {
              width: width,
              depth: depth,
              thickness: thickness,
              glass_railing: glass_railing,
              turn_direction: turn_direction
            },
            edges_to_rail
          )
        end

        # Apply position transformation
        transform = Geom::Transformation.new(position)
        landing_group.transform!(transform)

        # Name the group
        landing_group.name = "Landing - #{width.round}\" x #{depth.round}\""

        # Store parameters as attributes
        landing_group.set_attribute("stair_generator", "width", width)
        landing_group.set_attribute("stair_generator", "depth", depth)
        landing_group.set_attribute("stair_generator", "thickness", thickness)
        landing_group.set_attribute("stair_generator", "glass_railing", glass_railing)
        landing_group.set_attribute("stair_generator", "segment_type", "landing")

        return landing_group
      end # create_wide_landing

      # Helper method to add glass railings to a stair segment
      def add_glass_railings_to_segment(entities, num_treads, tread_run, tread_width, stair_rise, glass_railing, glass_thickness, glass_inset, glass_height)
        glass_material = Viewrail::SharedUtilities.get_or_add_material(:glass)

        # Calculate panel divisions based on 48" max width
        max_panel_width = 48.0
        panel_gap = 1.0

        # Calculate how many treads per panel to stay under 48"
        treads_per_panel = (max_panel_width / tread_run).floor

        # Distribute treads as evenly as possible
        panels_needed = (num_treads.to_f / treads_per_panel).ceil
        base_treads = num_treads / panels_needed
        extra_treads = num_treads % panels_needed

        # Create array of tread counts per panel
        panel_tread_counts = []
        panels_needed.times do |i|
          if i < panels_needed - extra_treads
            # First panels get base amount
            panel_tread_counts << base_treads
          else
            # Last panels get the extra treads
            panel_tread_counts << base_treads + 1
          end
        end

        # Original positioning variables
        stair_angle = stair_rise.to_f / tread_run.to_f
        panel_extension = 1.0
        bottom_x_back = tread_run + 5
        bottom_z = 1.0
        left_y = tread_width - glass_inset - glass_thickness
        right_y = glass_inset

        # Define panel sides configuration
        panel_sides = [
          {
            name: "Left",
            enabled: glass_railing == "Left" || glass_railing == "Both",
            y: left_y,
            y_min: left_y - 0.01,
            y_max: left_y + glass_thickness + 0.01
          },
          {
            name: "Right",
            enabled: glass_railing == "Right" || glass_railing == "Both",
            y: right_y,
            y_min: right_y - 0.01,
            y_max: right_y + glass_thickness + 0.01
          }
        ]

        panel_sides.each do |side|
          next unless side[:enabled]

          tread_start = 0

          # Create each glass panel section
          panel_tread_counts.each_with_index do |treads_in_panel, panel_index|
            tread_end = tread_start + treads_in_panel
            is_first_panel = (panel_index == 0)
            is_last_panel = (panel_index == panel_tread_counts.length - 1)

            glass_points = []

            if is_first_panel
              # First panel - includes horizontal bottom portion
              start_x = 0
              end_x = tread_end * tread_run + 5

              # Bottom edge points
              bottom_start_z = bottom_z
              bottom_end_z = (tread_end - 1) * stair_rise + bottom_z

              # Top edge points
              top_start_z = glass_height + stair_rise
              top_end_z = end_x * stair_angle + top_start_z

              # Build 5-point polygon like original
              glass_points << [start_x, side[:y], bottom_start_z]
              glass_points << [bottom_x_back, side[:y], bottom_start_z]
              if treads_in_panel > 1
                glass_points << [end_x, side[:y], bottom_end_z]
              end
              glass_points << [end_x, side[:y], top_end_z]
              glass_points << [start_x, side[:y], top_start_z]

            elsif is_last_panel
              # Last panel - includes top extension
              start_x = (tread_start * tread_run) + 5 + panel_gap
              end_x = (tread_end * tread_run) + 5 + panel_extension

              # Calculate slope-aligned positions
              # Bottom edge continues the slope from the original line
              bottom_start_z = (tread_start - 1) * stair_rise + bottom_z
              bottom_end_z = (tread_end - 1) * stair_rise + bottom_z
              angle_start_z = glass_height + stair_rise
              top_start_z = angle_start_z + start_x * stair_angle
              top_end_z = angle_start_z + end_x * stair_angle

              # Build 4-point parallelogram
              glass_points << [start_x, side[:y], bottom_start_z]
              glass_points << [end_x, side[:y], bottom_end_z]
              glass_points << [end_x, side[:y], top_end_z]
              glass_points << [start_x, side[:y], top_start_z]

            else
              # Middle panels - pure parallelograms following slope
              start_x = tread_start * tread_run + 5 + panel_gap
              end_x = tread_end * tread_run + 5

              # Calculate slope-aligned positions
              # Bottom edge continues the slope from the original line
              bottom_start_z = (tread_start - 1) * stair_rise + bottom_z
              bottom_end_z = (tread_end - 1) * stair_rise + bottom_z
              angle_start_z = glass_height + stair_rise
              top_start_z = angle_start_z + start_x * stair_angle
              top_end_z = angle_start_z + end_x * stair_angle

              # Build 4-point parallelogram
              glass_points << [start_x, side[:y], bottom_start_z]
              glass_points << [end_x, side[:y], bottom_end_z]
              glass_points << [end_x, side[:y], top_end_z]
              glass_points << [start_x, side[:y], top_start_z]
            end

            # Create the face and extrude
            face = entities.add_face(glass_points)
            if face
              face.pushpull(-glass_thickness)
              face.material = glass_material
              face.back_material = glass_material

              # Apply material to all faces in this panel
              entities.grep(Sketchup::Face).each do |f|
                if f.bounds.min.y >= side[:y_min] && f.bounds.max.y <= side[:y_max]
                  f.material = glass_material
                  f.back_material = glass_material
                end
              end
            end

            tread_start = tread_end
          end
        end
      end

      def add_glass_railings_to_landing(entities, landing_hash, edges_to_rail)
        glass_material = Viewrail::SharedUtilities.get_or_add_material(:glass)
        glass_thickness = 0.5
        glass_inset = 1.0
        glass_height = 42.0
        corner_gap = 1.0
        max_panel_width = 48.0
        panel_gap = 1.0
        stair_overlap = 5.0

        width = landing_hash[:width]
        depth = landing_hash[:depth]
        thickness = landing_hash[:thickness]
        glass_railing = landing_hash[:glass_railing]
        turn_direction = landing_hash[:turn_direction]

       # Create glass panels for specified edges with splits if needed
        edges_to_rail.each do |edge|
          case edge
          when "left", "right"
            # Calculate panel length (accounting for corner gaps)
            panel_length = depth - corner_gap - stair_overlap
            y_pos = edge == "right" ? glass_inset : width - glass_inset - glass_thickness

            if panel_length <= max_panel_width
              # Single panel
              glass_points = [
                [stair_overlap + panel_gap, y_pos, glass_height],
                [stair_overlap + panel_length, y_pos, glass_height],
                [stair_overlap + panel_length, y_pos, 0],
                [stair_overlap + panel_gap, y_pos, 0]
              ]
              create_glass_panel(entities, glass_points, glass_thickness, glass_material)
            else
              # Multiple panels - split symmetrically
              num_panels = (panel_length / max_panel_width).ceil
              actual_panel_width = (panel_length - (num_panels - 1) * panel_gap) / num_panels

              num_panels.times do |i|
                start_x = corner_gap + i * (actual_panel_width + panel_gap)
                end_x = start_x + actual_panel_width

                glass_points = [
                  [start_x, y_pos, glass_height],
                  [end_x, y_pos, glass_height],
                  [end_x, y_pos, 0],
                  [start_x, y_pos, 0]
                ]
                create_glass_panel(entities, glass_points, glass_thickness, glass_material)
              end
            end

          when "front", "back"
            # Calculate panel length (accounting for corner gaps)
            panel_length = width - corner_gap - stair_overlap
            x_pos = edge == "left" ? glass_inset : depth - glass_inset - glass_thickness
            y_pos = turn_direction == "Left" ? corner_gap : stair_overlap

            if panel_length <= max_panel_width
              # Single panel
              glass_points = [
                [x_pos, y_pos, glass_height],
                [x_pos, y_pos + panel_length, glass_height],
                [x_pos, y_pos + panel_length, 0],
                [x_pos, y_pos, 0]
              ]
              create_glass_panel(entities, glass_points, glass_thickness, glass_material)
            else
              # Multiple panels - split symmetrically
              num_panels = (panel_length / max_panel_width).ceil
              actual_panel_width = (panel_length - (num_panels - 1) * panel_gap) / num_panels

              num_panels.times do |i|
                start_y = corner_gap + i * (actual_panel_width + panel_gap)
                end_y = start_y + actual_panel_width

                glass_points = [
                  [x_pos, start_y, glass_height],
                  [x_pos, end_y, glass_height],
                  [x_pos, end_y, 0],
                  [x_pos, start_y, 0]
                ]
                create_glass_panel(entities, glass_points, glass_thickness, glass_material)
              end
            end
          end
        end
      end #add_glass_railings_to_landing

      def create_glass_panel(entities, points, thickness, material)
        group = entities.add_group
        face = group.entities.add_face(points)
        if face
          face.pushpull(thickness)
          group.entities.grep(Sketchup::Face).each do |f|
            f.material = material
            f.back_material = material
          end
        end
      end

       # Retrieve parameters from a selected stair group/component
      def get_selected_stair_parameters
        model = Sketchup.active_model
        selection = model.selection

        return nil if selection.nil?

        # Get the first selected entity
        entity = selection.first

        # Check if it's a group or component instance
        if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
          # Check if it has stair_generator attributes
          if entity.attribute_dictionary("stair_generator")
            params = {}
            dict = entity.attribute_dictionary("stair_generator")

            # Get the segment type to determine which parameters to retrieve
            segment_type = dict["segment_type"]

            case segment_type
            when "stairs"
              # Retrieve straight stair parameters
              params[:num_treads] = dict["num_treads"]
              params[:tread_run] = dict["tread_run"]
              params[:tread_width] = dict["tread_width"] || 36.0
              params[:stair_rise] = dict["stair_rise"]
              params[:glass_railing] = dict["glass_railing"]

              # Calculate derived values
              params[:total_tread_run] = params[:num_treads] * params[:tread_run] if params[:num_treads] && params[:tread_run]
              params[:total_rise] = (params[:num_treads] + 1) * params[:stair_rise] if params[:num_treads] && params[:stair_rise]

              params[:type] = :straight

            when "landing_stairs"
              # Retrieve 90-degree stair parameters
              params[:num_treads_lower] = dict["num_treads_lower"]
              params[:num_treads_upper] = dict["num_treads_upper"]
              params[:header_to_wall] = dict["header_to_wall"].to_f
              params[:tread_width_lower] = dict["tread_width_lower"]
              params[:tread_width_upper] = dict["tread_width_upper"]
              params[:landing_width] = dict["landing_width"]
              params[:landing_depth] = dict["landing_depth"]
              params[:tread_run] = dict["tread_run"]
              params[:stair_rise] = dict["stair_rise"]
              params[:total_rise] = dict["total_rise"]
              params[:turn_direction] = dict["turn_direction"]
              params[:glass_railing] = dict["glass_railing"]

              params[:type] = :landing_90

            when "landing_u"
              # Retrieve U-shaped stair parameters
              params[:num_treads_lower] = dict["num_treads_lower"]
              params[:num_treads_middle] = dict["num_treads_middle"]
              params[:num_treads_upper] = dict["num_treads_upper"]
              params[:header_to_wall] = dict["header_to_wall"].to_f
              params[:wall_to_wall] = dict["wall_to_wall"].to_f
              params[:tread_width_lower] = dict["tread_width_lower"]
              params[:tread_width_middle] = dict["tread_width_middle"]
              params[:tread_width_upper] = dict["tread_width_upper"]
              params[:lower_landing_width] = dict["lower_landing_width"]
              params[:lower_landing_depth] = dict["lower_landing_depth"]
              params[:upper_landing_width] = dict["upper_landing_width"]
              params[:upper_landing_depth] = dict["upper_landing_depth"]
              params[:tread_run] = dict["tread_run"]
              params[:stair_rise] = dict["stair_rise"]
              params[:total_rise] = dict["total_rise"]
              params[:turn_direction] = dict["turn_direction"]
              params[:glass_railing] = dict["glass_railing"]

              params[:type] = :landing_u

            when "landing"
              # This is just a landing component, not a full stair system
              return nil
            end

            return params
          end
        end

        return nil
      end

      # Check if a valid stair entity is selected
      def has_valid_stair_selection?
        params = get_selected_stair_parameters
        return !params.nil?
      end

      # Optimized validation check with caching
      def has_valid_stair_selection_cached?
        model = Sketchup.active_model
        selection = model.selection

        # Create a unique identifier for the current selection
        # Using entity IDs of selected entities to detect changes
        current_selection_id = if selection.nil?
          "empty"
        else
          selection.map(&:entityID).sort.join("-")
        end

        # If selection hasn't changed, return cached result
        if @selection_cache_id == current_selection_id
          # Return cached result without re-checking
          return @cached_validation_result
        end

        # Selection has changed, update cache
        @selection_cache_id = current_selection_id

        # Perform the actual validation only when selection changes
        @cached_validation_result = has_valid_stair_selection?

        return @cached_validation_result
      end

      # Store all parameters needed for regeneration
      def store_stair_parameters(group, params, stair_type)
        case stair_type
          when :straight
            group.set_attribute("stair_generator", "segment_type", "stairs")
            group.set_attribute("stair_generator", "num_treads", params["num_treads"])
            group.set_attribute("stair_generator", "tread_run", params["tread_run"])
            group.set_attribute("stair_generator", "tread_width", params["tread_width"] || 36.0)
            group.set_attribute("stair_generator", "stair_rise", params["stair_rise"])
            group.set_attribute("stair_generator", "glass_railing", params["glass_railing"])
            # Store calculated values for reference
            group.set_attribute("stair_generator", "total_tread_run", params["total_tread_run"])
            group.set_attribute("stair_generator", "total_rise", params["total_rise"])

          when :landing_90
            group.set_attribute("stair_generator", "segment_type", "landing_stairs")
            group.set_attribute("stair_generator", "num_treads_lower", params["num_treads_lower"])
            group.set_attribute("stair_generator", "num_treads_upper", params["num_treads_upper"])
            group.set_attribute("stair_generator", "header_to_wall", params["header_to_wall"])
            group.set_attribute("stair_generator", "tread_width_lower", params["tread_width_lower"])
            group.set_attribute("stair_generator", "tread_width_upper", params["tread_width_upper"])
            group.set_attribute("stair_generator", "landing_width", params["landing_width"])
            group.set_attribute("stair_generator", "landing_depth", params["landing_depth"])
            group.set_attribute("stair_generator", "tread_run", params["tread_run"])
            group.set_attribute("stair_generator", "stair_rise", params["stair_rise"])
            group.set_attribute("stair_generator", "total_rise", params["total_rise"])
            group.set_attribute("stair_generator", "turn_direction", params["turn_direction"])
            group.set_attribute("stair_generator", "glass_railing", params["glass_railing"])
          when :landing_u
            group.set_attribute("stair_generator", "segment_type", "landing_u")
            group.set_attribute("stair_generator", "num_treads_lower", params["num_treads_lower"])
            group.set_attribute("stair_generator", "num_treads_middle", params["num_treads_middle"])
            group.set_attribute("stair_generator", "num_treads_upper", params["num_treads_upper"])
            group.set_attribute("stair_generator", "header_to_wall", params["header_to_wall"])
            group.set_attribute("stair_generator", "wall_to_wall", params["wall_to_wall"])
            group.set_attribute("stair_generator", "tread_width_lower", params["tread_width_lower"])
            group.set_attribute("stair_generator", "tread_width_middle", params["tread_width_middle"])
            group.set_attribute("stair_generator", "tread_width_upper", params["tread_width_upper"])
            group.set_attribute("stair_generator", "lower_landing_width", params["lower_landing_width"])
            group.set_attribute("stair_generator", "lower_landing_depth", params["lower_landing_depth"])
            group.set_attribute("stair_generator", "upper_landing_width", params["upper_landing_width"])
            group.set_attribute("stair_generator", "upper_landing_depth", params["upper_landing_depth"])
            group.set_attribute("stair_generator", "tread_run", params["tread_run"])
            group.set_attribute("stair_generator", "stair_rise", params["stair_rise"])
            group.set_attribute("stair_generator", "total_rise", params["total_rise"])
            group.set_attribute("stair_generator", "turn_direction", params["turn_direction"])
            group.set_attribute("stair_generator", "glass_railing", params["glass_railing"])
        end
      end # store_stair_parameters

      def show_about
        UI.messagebox(
          "Stair Generator Extension v3.1.0\n\n" +
          "Creates parametric stairs for architectural visualization.\n\n" +
          "Features:\n" +
          "• Straight stairs with customizable dimensions\n" +
          "• L-shaped (90°) stairs with landing\n" +
          "• U-shaped stairs with two landings\n" +
          "• Automatic calculation of stair rise\n" +
          "• Building code compliance checking\n" +
          "• 3D stair geometry with glass railings\n" +
          "• Modular stair segments and landings\n\n" +
          "© 2025 Viewrail",
          MB_OK,
          "About Stair Generator"
        )
      end

    end # class << self

    # Create toolbar
    unless file_loaded?(__FILE__)

      # Init selection cache for modify tool
      Viewrail::StairGenerator.init_selection_cache

      # Create the toolbar
      toolbar = UI::Toolbar.new("Stair Generator")

      # Create commands for straight stairs
      cmd_stairs = UI::Command.new("Create Straight Stairs") {
        self.add_stair_menu
      }
      cmd_stairs.small_icon = File.join(File.dirname(__FILE__), "icons", "add_straight.svg")
      cmd_stairs.large_icon = File.join(File.dirname(__FILE__), "icons", "add_straight.svg")
      cmd_stairs.tooltip = "Create Straight Stairs"
      cmd_stairs.status_bar_text = "Create parametric straight stairs with customizable dimensions"
      cmd_stairs.menu_text = "Create Straight Stairs"

      # Create command for landing stairs
      cmd_landing_stairs = UI::Command.new("Create 90") {
        self.add_landing_stair_menu
      }
      cmd_landing_stairs.small_icon = File.join(File.dirname(__FILE__), "icons", "add_90.svg")
      cmd_landing_stairs.large_icon = File.join(File.dirname(__FILE__), "icons", "add_90.svg")
      cmd_landing_stairs.tooltip = "Create 90 Stairs"
      cmd_landing_stairs.status_bar_text = "Create L-shaped stairs with landing platform"
      cmd_landing_stairs.menu_text = "Create 90 System Stairs"

      # Create command for switchback stairs
      cmd_switchback_stairs = UI::Command.new("Create Switchback") {
        self.add_switchback_stair_menu
      }
      cmd_switchback_stairs.small_icon = "C:/Viewrail-Sketchup/plugins/stair_generator/icons/add_switchback.svg"
      cmd_switchback_stairs.large_icon = "C:/Viewrail-Sketchup/plugins/stair_generator/icons/add_switchback.svg"
      cmd_switchback_stairs.tooltip = "Create Switchback Stairs"
      cmd_switchback_stairs.status_bar_text = "Create U-shaped stairs with landing platform"
      cmd_switchback_stairs.menu_text = "Create Switchback System Stairs"

      # Create command for U-shaped stairs
      cmd_u_stairs = UI::Command.new("Create U-Shaped Stairs") {
        self.add_u_stair_menu
      }
      cmd_u_stairs.small_icon = File.join(File.dirname(__FILE__), "icons", "add_u.svg")
      cmd_u_stairs.large_icon = File.join(File.dirname(__FILE__), "icons", "add_u.svg")
      cmd_u_stairs.tooltip = "Create U-Shaped Stairs"
      cmd_u_stairs.status_bar_text = "Create U-shaped stairs with two landings"
      cmd_u_stairs.menu_text = "Create U-Shaped Stairs"

      # Create command for modifying existing stairs
      cmd_modify = UI::Command.new("Modify Stairs") {
        Viewrail::StairGenerator::Tools::ModifyStairTool.activate
      }
      cmd_modify.small_icon = File.join(File.dirname(__FILE__), "icons", "modify.svg")
      cmd_modify.large_icon = File.join(File.dirname(__FILE__), "icons", "modify.svg")
      cmd_modify.tooltip = "Modify Existing Stairs"
      cmd_modify.status_bar_text = "Modify parameters of selected stairs"
      cmd_modify.menu_text = "Modify Stairs"

      # Add validation proc to enable/disable based on selection
      cmd_modify.set_validation_proc {
        if Viewrail::StairGenerator.has_valid_stair_selection_cached?
          MF_ENABLED
        else
          MF_GRAYED
        end
      }

      # Create command for About
      cmd_about = UI::Command.new("About") {
        self.show_about
      }
      cmd_about.small_icon = File.join(File.dirname(__FILE__), "icons", "logo-black.svg")
      cmd_about.large_icon = File.join(File.dirname(__FILE__), "icons", "logo-black.svg")
      cmd_about.tooltip = "About Stair Generator"
      cmd_about.status_bar_text = "About Stair Generator Extension"
      cmd_about.menu_text = "About"

      # Add commands to toolbar
      toolbar = toolbar.add_item(cmd_stairs)
      toolbar = toolbar.add_item(cmd_landing_stairs)
      toolbar = toolbar.add_item(cmd_switchback_stairs)
      toolbar = toolbar.add_item(cmd_u_stairs)
      toolbar = toolbar.add_item(cmd_modify)
      toolbar = toolbar.add_separator
      toolbar = toolbar.add_item(cmd_about)

      # Show the toolbar
      toolbar.show

      # Create menu
      menu = UI.menu("Extensions")
      stairs_menu = menu.add_submenu("Stair Generator")
      stairs_menu.add_item(cmd_stairs)
      stairs_menu.add_item(cmd_landing_stairs)
      stairs_menu.add_item(cmd_switchback_stairs)
      stairs_menu.add_item(cmd_u_stairs)
      stairs_menu.add_item(cmd_modify)
      stairs_menu.add_separator
      stairs_menu.add_item(cmd_about)

      # Create context menu items (right-click menu)
      UI.add_context_menu_handler do |context_menu|
        context_menu.add_separator
        stairs_context = context_menu.add_submenu("Stair Generator")
        stairs_context.add_item(cmd_stairs)
        stairs_context.add_item(cmd_landing_stairs)
        stairs_context.add_item(cmd_switchback_stairs)
        stairs_context.add_item(cmd_u_stairs)
        stairs_context.add_item(cmd_modify)
      end

      file_loaded(__FILE__)
    end

  end # module StairGenerator

end # module Viewrail
