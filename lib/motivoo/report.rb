module Motivoo
  
  # Reporting.
  #
  class Report
    def initialize(connection)
      @connection = connection
    end
    
    [:acquisition, :activation, :retention, :referral, :revenue].each do |category| # TODO: Duplication -- Tracker#acquisition etc.
      
      # Absolute values for a cohort + event.
      # For example
      #   report.acquisitions_by(:month, :visit) => {"2012-10" => 3, "2012-11" => 4}
      # means that there were three visits for the October 2012 cohort (i.e. for people who first visited the site in October) and 4 for the November cohort.
      #
      define_method("#{category.to_s}s_by".to_sym) do |cohort, event|
        @connection.find(category.to_s, event.to_s, cohort.to_s)
      end

      # Relative values for a cohort + event.
      # For example
      #   report.activations_by(:month, :signup) => {"2012-10" => 1, "2012-11" => 0.25}
      # means that our of the October cohort 100% users signed up and only 25% out of the November cohort.
      #
      define_method("relative_#{category.to_s}s_by".to_sym) do |cohort, event, base_report|
        this = @connection.find(category.to_s, event.to_s, cohort.to_s)
        
        this.inject({}) do |acc, (cohort, count)|
          base_count = base_report[cohort] || 0 # If no base actions, make it 100%
          ratio = count.to_f / base_count
          acc.merge(cohort => ratio.infinite? ? 1 : ratio)
        end
      end
    end
  end
end