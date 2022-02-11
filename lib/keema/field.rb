module Keema
  class Field
    attr_reader :name, :type, :null, :optional
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

    def parse_name(name)
      is_optional = name.end_with?('?')
      real_name = is_optional ? name[0..-2] : name

      [real_name.to_sym, is_optional]
    end

    def type_to_json_schema(type, openapi: false)
      case
      when type == Integer
        { type: :integer }
      when type == Float
        { type: :number }
      when type == String || type == Symbol
        { type: :string }
      when type == Date
        { type: :string, format: :date }
      when type == Time
        { type: :string, format: :'date-time' }
      when type == ::Keema::Type::Boolean
        { type: :boolean }
      when type.is_a?(::Keema::Type::Enum)
        result = type_to_json_schema(type.values.first.class, openapi: openapi)
        result[:enum] = type.values
        result
      when type.is_a?(Array)
        item_type = type.first
        { type: :array, items: type_to_json_schema(item_type, openapi: openapi) }
      when type.respond_to?(:to_json_schema)
        type.to_json_schema(openapi: openapi)
      else
        raise "unsupported type #{type}"
      end
    end
  end
end