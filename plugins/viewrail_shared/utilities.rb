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

    end # class << self

  end # module SharedUtilities

end # module Viewrail