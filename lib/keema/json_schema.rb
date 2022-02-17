module Keema
  class JsonSchema
    attr_reader :openapi, :use_ref
    def initialize(openapi: false, use_ref: false)
      @openapi = openapi
      @use_ref = use_ref
    end

    def convert_type(type)
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
      when type == ::Keema::Type::Bool
        { type: :boolean }
      when type.is_a?(::Keema::Type::Enum)
        result = convert_type(type.values.first.class)
        result[:enum] = type.values
        result
      when type.is_a?(Array)
        item_type = type.first
        { type: :array, items: convert_type(item_type) }
      when type.respond_to?(:to_json_schema)
        if use_ref
          type.to_json_schema_reference
        else
          type.to_json_schema(openapi: openapi)
        end
      else
        raise "unsupported type #{type}"
      end
    end

    def self.underscore(camel_cased_word)
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
end
