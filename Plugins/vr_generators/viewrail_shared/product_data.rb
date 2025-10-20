# viewrail_shared/product_data.rb

module Viewrail

  module ProductData

    class << self

      # Glass Panel Standards
      GLASS_STANDARDS = {
        thickness: 0.5,
        max_panel_width: 48.0,
        default_panel_gap: 1.0,
        default_height: 42.0
      }

      # Base Channel (Baserail) Standards
      BASE_CHANNEL_STANDARDS = {
        width: 2.5,
        height: 4.188,
        glass_bottom_offset: 1.188,
        corner_radius: 0.0625
      }

      # Handrail Standards
      HANDRAIL_STANDARDS = {
        width: 1.69,
        height: 1.35,
        glass_recess: 0.851,
        corner_radius: 0.160
      }

      # Floor Cover Standards (for Hidden type railings)
      FLOOR_COVER_STANDARDS = {
        width: 1.625,
        height: 7.5,
        glass_below_floor: 6.0
      }

      # Railing Type Offset Standards
      RAILING_TYPE_OFFSETS = {
        hidden: 0.0,
        baserail: 2.125,
        fascia: -1.0
      }

      # Material Type Options
      MATERIAL_TYPES = {
        aluminum: "Aluminum",
        wood: "Wood",
        steel: "Steel"
      }

      # Accessor methods for glass standards
      def glass_thickness
        GLASS_STANDARDS[:thickness]
      end

      def max_panel_width
        GLASS_STANDARDS[:max_panel_width]
      end

      def default_panel_gap
        GLASS_STANDARDS[:default_panel_gap]
      end

      def default_glass_height
        GLASS_STANDARDS[:default_height]
      end

      # Accessor methods for base channel standards
      def base_channel_width
        BASE_CHANNEL_STANDARDS[:width]
      end

      def base_channel_height
        BASE_CHANNEL_STANDARDS[:height]
      end

      def glass_bottom_offset
        BASE_CHANNEL_STANDARDS[:glass_bottom_offset]
      end

      def base_corner_radius
        BASE_CHANNEL_STANDARDS[:corner_radius]
      end

      # Accessor methods for handrail standards
      def handrail_width
        HANDRAIL_STANDARDS[:width]
      end

      def handrail_height
        HANDRAIL_STANDARDS[:height]
      end

      def glass_recess
        HANDRAIL_STANDARDS[:glass_recess]
      end

      def handrail_corner_radius
        HANDRAIL_STANDARDS[:corner_radius]
      end

      # Accessor methods for floor cover standards
      def floor_cover_width
        FLOOR_COVER_STANDARDS[:width]
      end

      def floor_cover_height
        FLOOR_COVER_STANDARDS[:height]
      end

      def glass_below_floor
        FLOOR_COVER_STANDARDS[:glass_below_floor]
      end

      # Get offset distance for railing type
      def offset_for_railing_type(type)
        type_sym = type.to_s.downcase.to_sym
        RAILING_TYPE_OFFSETS[type_sym] || 0.0
      end

      # Get all standards for a component type
      def get_standards(component_type)
        case component_type.to_sym
        when :glass
          GLASS_STANDARDS
        when :base_channel, :baserail
          BASE_CHANNEL_STANDARDS
        when :handrail, :caprail
          HANDRAIL_STANDARDS
        when :floor_cover
          FLOOR_COVER_STANDARDS
        else
          {}
        end
      end

      # Update a standard value (useful for project-specific overrides)
      def update_standard(component_type, key, value)
        case component_type.to_sym
        when :glass
          GLASS_STANDARDS[key] = value if GLASS_STANDARDS.key?(key)
        when :base_channel, :baserail
          BASE_CHANNEL_STANDARDS[key] = value if BASE_CHANNEL_STANDARDS.key?(key)
        when :handrail, :caprail
          HANDRAIL_STANDARDS[key] = value if HANDRAIL_STANDARDS.key?(key)
        when :floor_cover
          FLOOR_COVER_STANDARDS[key] = value if FLOOR_COVER_STANDARDS.key?(key)
        end
      end

      # Calculate glass height based on configuration
      def calculate_glass_height(total_height, include_handrail, railing_type)
        if railing_type.to_s.downcase == "hidden"
          total_height + glass_below_floor
        elsif include_handrail
          total_height - handrail_height + glass_recess
        else
          total_height
        end
      end

      # Calculate handrail Z adjustment based on configuration
      def calculate_handrail_z_adjustment(total_height, include_floor_cover, glass_height)
        if include_floor_cover
          total_height - (glass_recess - handrail_height / 2.0)
        else
          glass_height - (glass_recess - handrail_height / 2.0)
        end
      end

      # Get center offset for base channel relative to glass
      def base_channel_center_offset(glass_offset, glass_thickness)
        glass_offset - (glass_thickness / 2.0)
      end

      # Get center offset for handrail relative to glass
      def handrail_center_offset(glass_offset, glass_thickness)
        glass_offset - (glass_thickness / 2.0)
      end

      # Validate if a panel width is within acceptable range
      def valid_panel_width?(width)
        width > 0 && width <= max_panel_width
      end

      # Get available material types
      def available_materials
        MATERIAL_TYPES.values
      end

      # Check if material type is valid
      def valid_material?(material)
        MATERIAL_TYPES.values.include?(material.to_s)
      end

      # Create profile for a given component type
      def create_profile(component_type)
        case component_type.to_sym
        when :handrail, :caprail
          create_handrail_profile
        when :base_channel, :baserail
          create_base_channel_profile
        when :floor_cover
          create_floor_cover_profile
        else
          []
        end
      end

      # Optional: Provide default offset helpers (not enforced)
      def default_center_offset(glass_offset, glass_thickness)
        glass_offset - (glass_thickness / 2.0)
      end

      def default_floor_cover_offset(floor_cover_width)
        -floor_cover_width / 2.0
      end

      private

      # Create handrail profile with rounded corners
      def create_handrail_profile
        half_width = handrail_width / 2.0
        half_height = handrail_height / 2.0
        corner = handrail_corner_radius
        
        [
          [-half_width + corner, -half_height],
          [-half_width, -half_height + corner],
          [-half_width, half_height - corner],
          [-half_width + corner, half_height],
          [half_width - corner, half_height],
          [half_width, half_height - corner],
          [half_width, -half_height + corner],
          [half_width - corner, -half_height]
        ]
      end

      # Create base channel profile (U-channel)
      def create_base_channel_profile
        half_width = base_channel_width / 2.0
        
        [
          [-half_width, 0],
          [-half_width, base_channel_height],
          [half_width, base_channel_height],
          [half_width, 0]
        ]
      end

      # Create floor cover profile (inverted channel below floor level)
      def create_floor_cover_profile
        half_width = floor_cover_width / 2.0
        
        [
          [-half_width, 0],
          [-half_width, -floor_cover_height],
          [half_width, -floor_cover_height],
          [half_width, 0]
        ]
      end

    end # class << self

  end # module ProductData

end # module Viewrail