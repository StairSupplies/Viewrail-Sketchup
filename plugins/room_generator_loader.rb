# Developed by: D Mosher using Claude

require 'sketchup.rb'
require 'extensions.rb'

module Viewrail
  module RoomGenerator

    unless file_loaded?(__FILE__)
      ex = SketchupExtension.new('Room Generator', 'room_generator/main')
      ex.description = 'SketchUp Ruby API test creating a simple room with 3 walls and a floor.'
      ex.version     = '1.0.0'
      ex.creator     = 'D Mosher'
      Sketchup.register_extension(ex, true)
      file_loaded(__FILE__)
    end

  end # module RoomGenerator
end # module Viewrail
