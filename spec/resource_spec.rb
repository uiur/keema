# frozen_string_literal: true

RSpec.describe Keema::Resource do
  require 'json'

  describe 'flat resource' do
    class ProductResource < Keema::Resource
      field :id, Integer
      field :name, String
      field :price, Float
      field :status, { enum: [:published, :unpublished] }
      field :description, String, null: true
      field :image_url?, String

      field :out_of_stock, Boolean
      field :tags, [String]

      field :created_at, Time
    end

    Product = Struct.new(*ProductResource.fields.keys, keyword_init: true)

    let(:product) do
      Product.new(
        id: 1,
        name: "foo",
        status: 'published',
        price: 12.3,
        description: nil,
        out_of_stock: false,
        tags: ['food', 'sushi'],
        image_url: 'foo.png',
        created_at: Time.now
      )
    end

    describe '#serialize' do
      it 'returns serializable hash' do
        hash = ProductResource.serialize(product)
        expect(hash).to match(
          id: 1,
          name: 'foo',
          status: 'published',
          price: 12.3,
          description: nil,
          image_url: 'foo.png',
          out_of_stock: false,
          tags: ['food', 'sushi'],
          created_at: String
        )
        pp hash
      end
    end

    describe '.to_json_schema' do
      it 'generetes json schema' do
        expect(ProductResource.to_json_schema).to match(
          properties: Hash,
          additionalProperties: false,
          required: Array
        )
        expect(ProductResource.to_json_schema(openapi: true)).to match(Hash)
        puts JSON.pretty_generate(ProductResource.to_json_schema)
      end
    end

    describe '.partial' do
      it 'returns partial resource class' do
        partial_resource_klass = ProductResource.partial([:id, :name])
        expect(partial_resource_klass.to_json_schema).to match(Hash)
        expect(partial_resource_klass.serialize(product)).to match(
          id: Integer,
          name: String
        )
      end
    end
  end

  describe 'nested resource' do
    module Nested
      class ProductImageResource < Keema::Resource
        field :id, Integer
        field :url, String
      end

      class ProductResource < Keema::Resource
        field :id, Integer
        field :product_images, [ProductImageResource]
      end

      Product = Struct.new(:id, :product_images, keyword_init: true)
      ProductImage = Struct.new(:id, :url, keyword_init: true)
    end

    let(:product_images) { [Nested::ProductImage.new(id: 1, url: '/foo.png'), Nested::ProductImage.new(id: 2, url: '/bar.png')] }
    let(:product) { Nested::Product.new(id: 1, product_images: product_images) }

    it do
      puts JSON.pretty_generate(Nested::ProductResource.to_json_schema)
      pp Nested::ProductResource.serialize(product)
    end
  end
end
