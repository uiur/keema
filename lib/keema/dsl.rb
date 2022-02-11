module Keema
  module DSL
    attr_writer :schema
    def schema
      @schema ||= Keema::Schema.new
    end

    def action_to_operation
      @action_to_operation ||= {}
    end

    def method_added(name)
      return unless @path
      operation = Keema::Operation.new(
        path: @path,
        method: @method,
        parameters: @parameters,
        body: @body,
        responses: {
          '2XX' => @response
        }
      )
      action_to_operation[name] = operation

      @path = nil
      @parameters = nil
      @body = nil
      @method = nil
      @response = nil

      schema.operations << operation
    end

    %w[get post patch delete].each do |method_name|
      define_method(method_name) do |path|
        @path = path
        @method = method_name.to_sym
      end
    end

    def response(data)
      @response = data
    end

    def param(name, type, required: true, default: nil)
      field = ::Keema::Field.new(name: name, type: type)
      parameter = Parameter.new(name: name, field: field, required: required, default: default)
      @parameters ||= []
      @parameters << parameter
    end

    def body(data)
      @body = data
    end
  end
end
