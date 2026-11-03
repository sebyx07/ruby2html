# frozen_string_literal: true

# Nested Ruby2html::Component: rendered into the parent's buffer directly.
class NativeUserCardComponent < Ruby2html::Component
  def initialize(user)
    @user = user
  end

  def view_template
    div class: 'user-card' do
      h3 @user[:name]
      p "Email: #{@user[:email]}"
      p "Address: #{@user[:address][:street]}, #{@user[:address][:city]}, #{@user[:address][:country]}"

      h4 'Orders'
      @user[:orders].each do |order|
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
end
