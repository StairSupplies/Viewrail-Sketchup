require_relative 'vr_generators\load_plugins.rb'
require 'sketchup.rb'
require 'extensions.rb'

module Viewrail
  unless file_loaded?(__FILE__)
    ex = SketchupExtension.new('Viewrail Tools', 'vr_generators\load_plugins')
    ex.description = 'Creation tool for Viewrail Stairs and Railings'
    ex.version     = '0.1.1'
    ex.creator     = 'B. Good-Elliott, D. Mosher'
    ex.copyright   = '2025, Viewrail'

    Sketchup.register_extension(ex, true)
    file_loaded(__FILE__)
  end
end
