module Viewrail

  module SharedUtilities

    class FormRenderer

      def initialize(values)
        @last_values = values
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
