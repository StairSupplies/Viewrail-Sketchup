module Viewrail

  module ProductData

    class << self

      GLASS_STANDARDS = {
        thickness: 0.5,
        max_panel_width: 48.0,
        default_panel_gap: 1.0,
        default_height: 42.0
      }

      BASE_CHANNEL_STANDARDS = {
        width: 2.5,
        height: 4.188,
        glass_bottom_offset: 1.188,
        corner_radius: 0.0625
      }

      HANDRAIL_STANDARDS = {
        width: 1.69,
        height: 1.35,
        glass_recess: 0.851,
        corner_radius: 0.160
      }

      FLOOR_COVER_STANDARDS = {
        width: 1.625,
        height: 7.5,
        glass_below_floor: 6.0
      }

      RAILING_TYPE_OFFSETS = {
        hidden: 0.0,
        baserail: 2.125,
        fascia: -1.0
      }

      MATERIAL_TYPES = {
        aluminum: "Aluminum",
        wood: "Wood",
        steel: "Steel"
      }

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

      def handrail_width
        HANDRAIL_STANDARDS[:width]
      end

      def handrail_thickness
        HANDRAIL_STANDARDS[:height]
      end

      def glass_recess
        HANDRAIL_STANDARDS[:glass_recess]
      end

      def handrail_corner_radius
        HANDRAIL_STANDARDS[:corner_radius]
      end

      def floor_cover_width
        FLOOR_COVER_STANDARDS[:width]
      end

      def floor_cover_height
        FLOOR_COVER_STANDARDS[:height]
      end

      def glass_below_floor
        FLOOR_COVER_STANDARDS[:glass_below_floor]
      end

      def offset_for_railing_type(type)
        type_sym = type.to_s.downcase.to_sym
        RAILING_TYPE_OFFSETS[type_sym] || 0.0
      end

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
      end # get_standards

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
      end # update_standard

      def calculate_glass_height(total_height, include_handrail, railing_type)
        
        glass_height = total_height
        
        if railing_type.to_s.downcase == "hidden"
          glass_height += glass_below_floor
        end

        if include_handrail
          glass_height = glass_height - handrail_thickness + glass_recess
        end

        return glass_height

      end # calculate_glass_height

      def calculate_handrail_z_adjustment(total_height)
          total_height - (handrail_thickness / 2.0)
      end # calculate_handrail_z_adjustment

      def base_channel_center_offset(glass_offset, glass_thickness)
        glass_offset - (glass_thickness / 2.0)
      end

      def handrail_center_offset(glass_offset, glass_thickness)
        glass_offset - (glass_thickness / 2.0)
      end

      def valid_panel_width?(width)
        width > 0 && width <= max_panel_width
      end

      def available_materials
        MATERIAL_TYPES.values
      end

      def valid_material?(material)
        MATERIAL_TYPES.values.include?(material.to_s)
      end

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
      end # create_profile

      def default_center_offset(glass_offset, glass_thickness)
        glass_offset - (glass_thickness / 2.0)
      end

      def default_floor_cover_offset(floor_cover_width)
        -floor_cover_width / 2.0
      end

      private

      def create_handrail_profile
        half_width = handrail_width / 2.0
        half_thickness = handrail_thickness / 2.0
        corner = handrail_corner_radius

        [
          [-half_width + corner, -half_thickness],
          [-half_width, -half_thickness + corner],
          [-half_width, half_thickness - corner],
          [-half_width + corner, half_thickness],
          [half_width - corner, half_thickness],
          [half_width, half_thickness - corner],
          [half_width, -half_thickness + corner],
          [half_width - corner, -half_thickness]
        ]
      end # create_handrail_profile

      def create_base_channel_profile
        half_width = base_channel_width / 2.0

        [
          [-half_width, 0],
          [-half_width, base_channel_height],
          [half_width, base_channel_height],
          [half_width, 0]
        ]
      end # create_base_channel_profile

      def create_floor_cover_profile
        half_width = floor_cover_width / 2.0

        [
          [-half_width, 0],
          [-half_width, -floor_cover_height],
          [half_width, -floor_cover_height],
          [half_width, 0]
        ]
      end # create_floor_cover_profile

    end # class << self

  end # module ProductData

end # module Viewrail
