# frozen_string_literal: true

RSpec.describe Keema::Resource do
  Product = Struct.new(:id, :name, :price, :created_at, :description, :out_of_stock, :tags, :image_url, keyword_init: true)

  class ProductResource < Keema::Resource
    field :id, Integer
    field :name, String
    field :price, Float
    # field :status, enum: [:published, :unpublished]
    field :description, String, null: true
    field :image_url, String, optional: true

    field :out_of_stock, Boolean
    field :tags, [String]

    field :created_at, Time
  end

  let(:product) do
    Product.new(id: 1, name: "foo", price: 12.3, description: nil, out_of_stock: false, tags: ['food', 'sushi'], image_url: 'foo.png', created_at: Time.now)
  end

  it do
    resource = ProductResource.new(product)
    hash = resource.serialize
    expect(hash).to match(
      id: 1,
      name: 'foo',
      price: 12.3,
      description: nil,
      image_url: 'foo.png',
      out_of_stock: false,
      tags: ['food', 'sushi'],
      created_at: String
    )
    pp hash
  end

  it do
    require 'json'
    expect(ProductResource.to_json_schema).to match(
      properties: Hash,
      additionalProperties: false,
      required: Array
    )
    expect(ProductResource.to_json_schema(openapi: true)).to match(Hash)
    puts JSON.pretty_generate(ProductResource.to_json_schema)
  end
end
