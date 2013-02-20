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
    end
  end
end