# frozen_string_literal: true

# Same markup as BenchmarkComponent, built on Ruby2html::Component (no
# ViewComponent): tags write straight into the buffer, ivars are the
# component's own.
class NativeBenchmarkComponent < Ruby2html::Component
  def initialize(data)
    @complex_data = data
  end

  def view_template
    h1 'Benchmark: Ruby2html'

    h2 'User Statistics'
    ul do
      li "Total Users: #{@complex_data[:stats][:total_users]}"
      li "Average Orders per User: #{@complex_data[:stats][:average_orders_per_user]}"
      li "Most Expensive Item: #{@complex_data[:stats][:most_expensive_item]}"
      li "Most Popular Country: #{@complex_data[:stats][:most_popular_country]}"
    end

    h2 'User List'
    @complex_data[:users].each { |user| render NativeUserCardComponent.new(user) }
  end
end
