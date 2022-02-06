require 'time'

module Keema
  module Type
    class Boolean; end
  end

  class Resource
    Boolean = ::Keema::Type::Boolean

    class Field
      attr_reader :name, :type, :null, :optional
      def initialize(name:, type:, null: false, optional: false)
        @name = name
        @type = type
        @null = null
        @optional = optional
      end

      def cast_value(value)
        case
        when type == Time
          value.iso8601(3)
        else
          value
        end
      end

      def to_json_schema(openapi: false)
        hash = type_to_json_schema(type, openapi: openapi)

        if null
          if openapi
            hash[:nullable] = true
          else
            hash[:type] = [hash[:type], :null]
          end
        end

        hash
      end

      private
      def type_to_json_schema(type, openapi: false)
        case
        when type == Integer
          # todo: support openapi integer
          { type: :number }
        when type == String
          { type: :string }
        when type == Date
          { type: :string, format: :date }
        when type == Time
          { type: :string, format: :'date-time' }
        when type == Boolean
          { type: :boolean }
        when type.is_a?(Array)
          item_type = type.first
          { type: :array, items: type_to_json_schema(item_type, openapi: openapi) }
        else
          raise "unsupported type #{type}"
        end
      end
    end

    class <<self
      def field(name, type, null: false, optional: false, **options)
        @fields ||= {}
        @fields[name] = Field.new(name: name, type: type, null: null, optional: optional)
      end

      def fields
        @fields ||= {}
      end

      def select(field_names)
        klass = Class.new do
          include BaseResource
        end

        field_names.each do |name|
          klass.fields[name] = fields[name].dup
        end

        klass
      end

      def to_json_schema(openapi: false)
        {
          properties: fields.map do |name, field|
            [
              name, field.to_json_schema(openapi: openapi)
            ]
          end.to_h,
          additionalProperties: false,
          required: fields.values.reject(&:optional).map(&:name),
        }
      end
    end

    attr_reader :object, :context
    def initialize(object, context: {})
      @object = object
      @context = context
    end

    def serialize
      serialize_one(object)
    end

    private

    def serialize_one(object)
      hash = {}
      self.class.fields.each do |field_name, field|
        value =
          if respond_to?(field_name)
            send(field_name)
          elsif object.respond_to?(field_name)
            object.public_send(field_name)
          elsif object.respond_to?(:"#{field_name}?")
            object.public_send(:"#{field_name}?")
          else
            raise ::Keema::RuntimeError.new("object does not respond to `#{field_name}` (#{self.class.name})\n#{object.inspect}")
          end

        hash[field_name] = field.cast_value(value)
      end

      hash
    end
  end
end
