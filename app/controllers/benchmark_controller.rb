# frozen_string_literal: true

class BenchmarkController < ApplicationController
  def normal_html
    @complex_data = generate_complex_data
  end

  def ruby_2html
    @complex_data = generate_complex_data
  end

  private
    def generate_complex_data
      {
        users: 50.times.map do |i|
          {
            id: i + 1,
            name: Faker::Name.name,
            email: Faker::Internet.email,
            address: {
              street: Faker::Address.street_address,
              city: Faker::Address.city,
              country: Faker::Address.country
            },
            orders: rand(1..5).times.map do
              {
                id: Faker::Alphanumeric.alphanumeric(number: 10),
                total: Faker::Commerce.price(range: 10..1000.0),
                items: rand(1..10).times.map do
                  {
                    name: Faker::Commerce.product_name,
                    price: Faker::Commerce.price(range: 5..500.0),
                    quantity: rand(1..5)
                  }
                end
              }
            end
          }
        end,
        stats: {
          total_users: 50,
          average_orders_per_user: rand(1.0..5.0).round(2),
          most_expensive_item: Faker::Commerce.product_name,
          most_popular_country: Faker::Address.country
        }
      }
    end
end
