require 'sketchup.rb'
require 'extensions.rb'

module Viewrail
  
  module RailingGeneratorLoader

    unless file_loaded?(__FILE__)
      ex = SketchupExtension.new('Viewrail Railing Generator', 'railing_generator/main')
      ex.description = 'Creates various types of railings including glass and cable systems.'
      ex.version = '1.0.0'
      ex.copyright = '© 2025 Viewrail'
      ex.creator = 'Viewrail Development Team'
      Sketchup.register_extension(ex, true)
      file_loaded(__FILE__)
    end

  end # module RailingGeneratorLoader

end # module Viewrail