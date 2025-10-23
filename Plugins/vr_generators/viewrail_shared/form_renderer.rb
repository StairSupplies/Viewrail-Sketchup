require 'base64'
module Viewrail

  module SharedUtilities

    class FormRenderer

      def initialize(values)
        @last_values = values  # ERB templates expect @last_values
        load_icon_data_uris
      end

      def load_icon_data_uris
        base_dir = File.dirname(__FILE__)
        icons_dir = File.join(base_dir, '..', 'stair_generator', 'icons')

        unlocked_path = File.join(icons_dir, 'padlock_unlocked.svg')
        locked_path = File.join(icons_dir, 'padlock_locked.svg')

        if File.exist?(unlocked_path) && File.exist?(locked_path)
          unlocked_svg = File.read(unlocked_path)
          locked_svg = File.read(locked_path)

          # Convert to data URIs
          @unlocked_icon = "data:image/svg+xml;base64,#{Base64.strict_encode64(unlocked_svg)}"
          @locked_icon = "data:image/svg+xml;base64,#{Base64.strict_encode64(locked_svg)}"
        else
          puts "Warning: Could not find lock icon files"
          puts "Looked in: #{icons_dir}"
          @unlocked_icon = ""
          @locked_icon = ""
        end
      end

      def render(template_path)
        template_string = File.read(template_path)

        erb = ERB.new(template_string)
        erb.result(binding)
      end

      attr_reader :values

      def method_missing(method, *args)
        if @values.respond_to?(:[]) && @values.key?(method)
          @values[method]
        else
          super
        end
      end

    end # class FormRenderer

  end # module SharedUtilities

end # module Viewrail
