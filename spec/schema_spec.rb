# frozen_string_literal: true

RSpec.describe Keema do
  class ProductResource < Keema::Resource
    field :id, Integer
    field :name, String
  end

  def deep_stringify(value)
    if value.is_a?(Array)
      value.map { |v| deep_stringify(v) }
    elsif value.is_a?(Hash)
      value.map { |k, v| [k.to_s, deep_stringify(v)] }.to_h
    elsif value.is_a?(Symbol)
      value.to_s
    else
      value
    end
  end

  it do
    schema = Keema::Schema.new
    schema.operations << Keema::Operation.new(
      path: '/products',
      method: :get,
      parameters: [
        { name: :page, in: :query, schema: { type: :integer, default: 1 }, required: false },
        { name: :per_page, in: :query, schema: { type: :integer, default: 20 }, required: false  },
      ],
      responses: {
        200 => [ProductResource],
      }
    )

    schema.operations << Keema::Operation.new(
      path: '/products/{id}',
      method: :get,
      responses: {
        200 => ProductResource,
      }
    )

    schema.operations << Keema::Operation.new(
      path: '/products',
      method: :post,
      body: ProductResource.partial([:name]),
      responses: {
        200 => ProductResource,
      }
    )

    schema.operations << Keema::Operation.new(
      path: '/products/{id}',
      method: :patch,
      body: ProductResource.partial([:name]),
      responses: {
        200 => ProductResource,
      }
    )

    schema.operations << Keema::Operation.new(
      path: '/products/{id}',
      method: :delete,
      responses: {
        200 => ProductResource,
      }
    )

    pp schema.to_openapi
    require 'yaml'
    File.open('./spec.yaml', 'w') do |f|
      f.write(YAML.dump(deep_stringify(schema.to_openapi)))
    end
  end
end
