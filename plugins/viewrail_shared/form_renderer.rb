# viewrail_shared/form_renderer.rb
module Viewrail
  module SharedUtilities
    class FormRenderer
      def initialize(values)
        @last_values = values  # ERB templates expect @last_values
      end

      def render(template_path)
        # Read the template file
        template_string = File.read(template_path)
        
        # Create ERB object and render with current binding
        erb = ERB.new(template_string)
        erb.result(binding)
      end
      
      # Make values accessible in ERB templates
      attr_reader :values
      
      # Helper method for backward compatibility with existing templates
      def method_missing(method, *args)
        if @values.respond_to?(:[]) && @values.key?(method)
          @values[method]
        else
          super
        end
      end
    end
  end
end