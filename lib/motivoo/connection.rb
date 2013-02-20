require 'mongo'

module Motivoo
  class Connection
    def initialize
      db = Mongo::Connection.new("localhost")["motivoo"]
      @tracking = db["motivoo.tracking"]
      @user_data = db["motivoo.user_data"]
    end
    
    # Tracking
    
    def track(category, status, period_name, period)
      @tracking.update({category: category, status: status, period_name: period_name, period: period}, {"$inc" => {count: 1}}, upsert: true)
    end
  
    def find(category, status, period_name)
      @tracking.find(category: category, status: status, period_name: period_name).to_a.inject({}) {|a, r| a.merge(r["period"] => r["count"])}
    end
    
    # User data
    
    def find_or_create_user_data(id)
      existing = @user_data.find_one("_id" => id) 
      if existing 
        existing
      else
        @user_data.insert({"_id" => id}) 
        {"_id" => id}
      end
    end
    
    def generate_user_id
      @user_data.insert({})
    end
    
    def assign_cohort(user_id, cohort_name, cohort)
      @user_data.update({"_id" => user_id}, "$set" => {"cohorts.#{cohort_name}" => cohort})
    end
    
    # Testing
    
    def clear!
      @tracking.drop
      @user_data.drop
    end
  end
end