module Motivoo
  class Report
    def initialize(connection)
      @connection = connection
    end
    
    def acquisitions_by(cohort, status)
      @connection.find("acquisition", status.to_s, cohort.to_s)
    end
    
    def activations_by(cohort, status)
      @connection.find("activation", status.to_s, cohort.to_s)
    end
  end
end