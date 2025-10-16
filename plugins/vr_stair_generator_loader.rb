require 'sketchup.rb'
require 'extensions.rb'

module Viewrail
  
  module StairGeneratorLoader

    unless file_loaded?(__FILE__)
      ex = SketchupExtension.new('Stair Generator', 'stair_generator/main')
      ex.description = 'Tool to create Viewrail based stair runs.'
      ex.version = '1.0.0'
      ex.copyright = '© 2025 Viewrail'
      ex.creator = 'Viewrail Development Team'
      Sketchup.register_extension(ex, true)
      file_loaded(__FILE__)
    end

  end # module StairGeneratorLoader

end # module Viewrail