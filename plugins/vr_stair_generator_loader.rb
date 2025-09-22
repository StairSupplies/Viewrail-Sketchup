# Developed by: D Mosher using Claude

require 'sketchup.rb'
require 'extensions.rb'

module Viewrail
  module StairGenerator

    unless file_loaded?(__FILE__)
      ex = SketchupExtension.new('Stair Generator', 'stair_generator/main.rb')
      ex.description = 'Tool to create Viewrail based stair runs.'
      ex.version     = '1.0.0'
      ex.creator     = 'D Mosher'
      Sketchup.register_extension(ex, true)
      file_loaded(__FILE__)
    end

  end # module StairGenerator
end # module Viewrail
