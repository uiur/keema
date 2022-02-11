require 'time'

module Keema
  module Type
    class Boolean; end

    class Enum
      attr_reader :values
      def initialize(values)
        @values = values
      end
    end
  end

  class Resource
    Boolean = ::Keema::Type::Boolean

    class <<self
      def field(name, type, null: false, optional: false, **options)
        @fields ||= {}
        field = ::Keema::Field.new(name: name, type: type, null: null, optional: optional)
        @fields[field.name] = field
      end

      def fields
        @fields ||= {}
      end

      def partial(field_names)
        klass = Class.new(self.superclass)
        field_names.each do |name|
          klass.fields[name] = fields[name].dup
        end

        klass
      end

      def is_keema_resource_class?
        true
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

      def serialize(object, context: {})
        new(context: context).serialize(object)
      end
    end

    attr_reader :object, :context
    def initialize(context: {})
      @context = context
    end

    def serialize(object)
      is_hash_like = object.respond_to?(:keys) || object.is_a?(Struct)
      if !is_hash_like && object.respond_to?(:each)
        object.map do |item|
          serialize_one(item)
        end
      else
        serialize_one(object)
      end
    end

    private

    def serialize_one(object)
      @object = object
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

      @object = nil

      hash
    end
  end
end
