module Keema
  class Field
    attr_reader :name, :type, :null, :optional
    attr_writer :type
    def initialize(name:, type:, null: false, optional: false)
      parsed_name, parsed_optional = parse_name(name)
      @name = parsed_name
      @type = convert_type(type)
      @null = null
      @optional = parsed_optional || optional
    end

    def convert_type(type)
      if type.is_a?(Hash) && type[:enum]
        ::Keema::Type::Enum.new(type[:enum])
      else
        type
      end
    end

    def cast_value(value)
      is_array = type.is_a?(Array)
      sub_type = is_array ? type.first : type
      values = is_array ? value : [value]

      result = values.map do |value|
        case
        when sub_type == Time
          value.iso8601(3)
        when sub_type.respond_to?(:is_keema_resource_class?) && sub_type.is_keema_resource_class?
          sub_type.serialize(value)
        else
          value
        end
      end

      is_array ? result : result.first
    end

    def to_json_schema(openapi: false, use_ref: false)
      hash = ::Keema::JsonSchema.new(openapi: openapi, use_ref: use_ref).convert_type(type)

      if null
        if openapi
          hash[:nullable] = true
        else
          hash[:type] = [hash[:type], :null]
        end
      end

      hash
    end

    def is_reference?
      item_type.respond_to?(:is_keema_resource_class?) && item_type.is_keema_resource_class?
    end

    def item_type
      type.is_a?(Array) ? type.first : type
    end

    private

    def parse_name(name)
      is_optional = name.end_with?('?')
      real_name = is_optional ? name[0..-2] : name

      [real_name.to_sym, is_optional]
    end
  end
end
