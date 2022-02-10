module Keema
  class Operation
    attr_reader :path, :method, :responses, :body
    def initialize(path:, method:, responses:, body: nil, parameters: [])
      @path = path
      @method = method
      @responses = responses
      @parameters = parameters
      @body = body
    end

    def parameters
      @parameters || []
    end
  end

  class Parameter
    attr_reader :name, :field, :required, :default
    def initialize(name:, field:, required: true, default: nil)
      @name = name
      @field = field
      @required = required
      @default = default
    end

    def to_openapi
      hash = {
        name: name,
        schema: field.to_json_schema(openapi: true),
        required: true
      }.merge(in: :query)

      if default
        hash[:default] = default
      end

      hash
    end
  end

  class Schema
    attr_accessor :operations
    def initialize
      @operations = []
    end

    def to_openapi
      paths = {}
      operations.each do |operation|
        path = operation.path
        method = operation.method
        paths[path] ||= {}
        paths[path][method] ||= {}
        paths[path][method][:parameters] ||= []
        paths[path][method][:parameters] += operation.parameters.map do |parameter|
          if parameter.respond_to?(:to_openapi)
            parameter.to_openapi.merge(in: :query)
          else
            parameter
          end
        end

        paths[path][method][:parameters] +=
          path.scan(/\{(.*?)\}/).map do |(name)|
            {
              name: name,
              in: :path,
              required: true,
              schema: { type: :string }
            }
          end

        if operation.body
          paths[path][method][:requestBody] = {
            content: {
              'application/json' => {
                schema: operation.body.to_json_schema(openapi: true)
              }
            },
            required: true
          }
        end

        paths[path][method][:responses] = operation.responses.map do |key, value|
          next unless value
          schema =
            if value.is_a?(Array)
              { type: :array, items: value.first.to_json_schema(openapi: true) }
            else
              value.to_json_schema(openapi: true)
            end

          [
            key,
            {
              description: '',
              content: {
                'application/json' => {
                  schema: schema
                }
              }
            }
          ]
        end.compact.to_h
      end

      {
        openapi: '3.0.0',
        info: {
          title: 'api',
          version: '1.0.0'
        },
        paths: paths
      }
    end
  end
end
