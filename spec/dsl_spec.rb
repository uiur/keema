# frozen_string_literal: true

RSpec.describe Keema::DSL do
  class ProductResource < Keema::Resource
    field :id, Integer
    field :name, String
  end

  class ProductsController
    extend Keema::DSL

    get '/products'
    param :page, Integer, default: 1
    param :per_page, Integer, default: 10
    response [ProductResource]
    def index
    end

    get '/products/{id}'
    response ProductResource
    def show
      # ...
    end

    post '/products'
    body ProductResource.partial([:name])
    response ProductResource
    def create
    end

    patch '/products/{id}'
    body ProductResource.partial([:name])
    response ProductResource
    def update
    end

    delete '/products/{id}'
    def destroy
    end

    private

    def schema
      self.class.schema
    end
  end

  it do
    expect(ProductsController.schema).to be_a(Keema::Schema)
    pp ProductsController.schema.to_openapi
  end
end
