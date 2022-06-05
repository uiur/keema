require 'time'

module Keema
  module Type
    class Bool; end

    class Enum
      attr_reader :values
      def initialize(values)
        @values = values
      end
    end
  end

  class FieldSelector
    attr_reader :selector, :resource
    def initialize(resource:, selector:)
      @resource = resource
      @selector = selector
    end

    def field_names
      selector.reduce([]) do |result, item|
        if item.is_a?(Hash)
          result += item.keys
        else
          if item == :*
            result += resource.fields.values.reject(&:optional).map(&:name)
          else
            result += [item]
          end
        end
      end
    end

    def fetch(name)
      nested_map[name] || [:*]
    end

    def nested_map
      if selector[-1]&.is_a?(Hash)
        selector[-1]
      else
        {}
      end
    end
  end

  class Resource
    Bool = ::Keema::Type::Bool

    class <<self
      def field(name, type, null: false, optional: false, **options)
        @fields ||= {}
        field = ::Keema::Field.new(name: name, type: type, null: null, optional: optional)
        @fields[field.name] = field
      end

      def enum(*values)
        ::Keema::Type::Enum.new(values)
      end

      def fields
        @fields ||= {}
      end

      def select(selector)
        new(fields: selector)
      end

      def is_keema_resource_class?
        true
      end

      def to_json_schema(openapi: false, use_ref: false)
        new.to_json_schema(openapi: openapi, use_ref: use_ref)
      end

      def serialize(object, context: {})
        new(context: context).serialize(object)
      end
    end

    attr_reader :object, :context, :selected_fields
    def initialize(context: {}, fields: [:*])
      @context = context
      @selected_fields = fields
    end

    def ts_type
      self.class.name&.gsub('::', '')
    end

    def fields
      self.class.fields.select { |field|
        field_selector.field_names.include?(field)
      }
    end

    def is_keema_resource_class?
      true
    end

    def to_json_schema(openapi: false, use_ref: false)
      ::Keema::JsonSchema.new(openapi: openapi, use_ref: use_ref).convert_type(self)
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

    def field_selector
      @field_selector ||= FieldSelector.new(resource: self.class, selector: selected_fields)
    end

    def serialize_one(object)
      @object = object
      hash = {}
      fields.each do |field_name, field|
        value =
          if respond_to?(field_name)
            send(field_name)
          elsif object.respond_to?(field_name)
            object.public_send(field_name)
          elsif object.respond_to?(:"#{field_name}?")
            object.public_send(:"#{field_name}?")
          else
            raise ::Keema::RuntimeError.new("object #{object.inspect} does not respond to `#{field_name}` (#{self.class.name})")
          end

        type = field.type

        is_array = type.is_a?(Array)
        sub_type = is_array ? type.first : type
        values = is_array ? value : [value]

        result = values.map do |value|
          case
          when sub_type == Time
            value.iso8601(3)
          when value && sub_type.respond_to?(:is_keema_resource_class?) && sub_type.is_keema_resource_class?
            nested_fields = field_selector.fetch(field_name)
            sub_type.new(context: context, fields: nested_fields).serialize(value)
          else
            value
          end
        end

        hash[field_name] = is_array ? result : result.first
      end

      @object = nil

      hash
    end
  end
end
