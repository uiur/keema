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
          nested_map[name]
        end

        def nested_map
          if selector[-1]&.is_a?(Hash)
            selector[-1]
          else
            {}
          end
        end
      end

      def select(selector)
        klass = Class.new(self)
        field_selector = FieldSelector.new(resource: self, selector: selector)
        field_selector.field_names.each do |name|
          nested_fields = field_selector.fetch(name)

          source_field = fields[name]
          unless source_field
            raise "field `#{name}` is not found in #{self.name}"
          end

          field = ::Keema::Field.new(
            name: source_field.name,
            type: source_field.type,
            null: source_field.null,
            optional: false,
          )

          klass.fields[name] =
            if nested_fields
              is_array = field.type.is_a?(Array)
              inner_type = is_array ? field.type.first : field.type
              select_type = inner_type.select(nested_fields)
              field.type = is_array ? [select_type] : select_type
              field
            else
              field
            end
        end

        klass
      end

      def is_keema_resource_class?
        true
      end

      def to_json_schema(openapi: false, use_ref: false)
        ::Keema::JsonSchema.new(openapi: openapi, use_ref: use_ref).convert_type(self)
      end

      def serialize(object, context: {})
        new(context: context).serialize(object)
      end

      private

      def underscore(camel_cased_word)
        return camel_cased_word unless /[A-Z-]|::/.match?(camel_cased_word)
        word = camel_cased_word.to_s.gsub("::", "/")
        # word.gsub!(inflections.acronyms_underscore_regex) { "#{$1 && '_' }#{$2.downcase}" }
        word.gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
        word.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
        word.tr!("-", "_")
        word.downcase!
        word
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
        next if field.optional
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

        hash[field_name] = field.cast_value(value)
      end

      @object = nil

      hash
    end
  end
end
