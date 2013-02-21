module Motivoo
  class Report
    def initialize(connection)
      @connection = connection
    end
    
    # TODO: Duplication -- Tracker#acquisition etc.
    [:acquisition, :activation, :retention, :referral, :revenue].each do |category|
      define_method("#{category.to_s}s_by".to_sym) do |cohort, status|
        @connection.find(category.to_s, status.to_s, cohort.to_s)
      end

      define_method("relative_#{category.to_s}s_by".to_sym) do |cohort, status|
        visits = @connection.find("acquisition", "visit", cohort.to_s)
        this = @connection.find(category.to_s, status.to_s, cohort.to_s)
        
        this.inject({}) do |acc, (cohort, count)|
          visit_count = visits[cohort] || 0 # If no visits, make it 100%
          ratio = count.to_f / visit_count
          acc.merge(cohort => ratio.infinite? ? 1 : ratio)
        end
      end
    end
  end
end