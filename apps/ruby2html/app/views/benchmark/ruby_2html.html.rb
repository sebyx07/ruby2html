# frozen_string_literal: true

h1 'Benchmark: Ruby2html'

h2 'User Statistics'
ul do
  li "Total Users: #{@complex_data[:stats][:total_users]}"
  li "Average Orders per User: #{@complex_data[:stats][:average_orders_per_user]}"
  li "Most Expensive Item: #{@complex_data[:stats][:most_expensive_item]}"
  li "Most Popular Country: #{@complex_data[:stats][:most_popular_country]}"
end

h2 'User List'
@complex_data[:users].each do |user|
  div class: 'user-card' do
    h3 user[:name]
    p "Email: #{user[:email]}"
    p "Address: #{user[:address][:street]}, #{user[:address][:city]}, #{user[:address][:country]}"

    h4 'Orders'
    user[:orders].each do |order|
      div class: 'order' do
        p "Order ID: #{order[:id]}"
        p "Total: $#{order[:total]}"
        ul do
          order[:items].each do |item|
            li "#{item[:name]} - $#{item[:price]} (Quantity: #{item[:quantity]})"
          end
        end
      end
    end
  end
end
