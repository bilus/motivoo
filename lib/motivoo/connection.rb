require 'mongo'

module Motivoo
  class Connection
    def initialize
      db = Mongo::Connection.new("localhost")["motivoo"]
      @tracking = db["motivoo.tracking"]
      @user_data = db["motivoo.user_data"]
      create_indices
    end
    
    # Tracking
    
    def track(category, status, cohort_name, cohort)
      @tracking.update({category: category, status: status, cohort_name: cohort_name, cohort: cohort}, {"$inc" => {count: 1}}, upsert: true)
    end
  
    def find(category, status, cohort_name)
      @tracking.find(category: category, status: status, cohort_name: cohort_name).to_a.inject({}) {|a, r| a.merge(r["cohort"] => r["count"])}
    end
    
    # User data
    
    def find_or_create_user_data(id)
      # TODO: Using exceptions to handle this is slow and ugly. 
      
      # NOTE: The code below is designed to avoid a race condition.
      begin
        @user_data.insert("_id" => id) 
        {}  # New record.
      rescue Mongo::OperationFailure => e
        raise unless e.error_code == 11000 # duplicate key error index
        reject_record_id(@user_data.find_one("_id" => id))  # Existing record.
      end
    end
    
    def find_user_data_by_ext_user_id(ext_user_id)
      if existing_record = @user_data.find_one("ext_user_id" => ext_user_id)
        [existing_record["_id"], reject_record_id(existing_record)]
      end
    end
    
    def generate_user_id
      @user_data.insert({})
    end
    
    def assign_cohort(user_id, cohort_name, cohort)
      @user_data.update({"_id" => user_id}, "$set" => {"cohorts.#{cohort_name}" => cohort})
    end
    
    def set_user_data(user_id, hash)
      @user_data.update({"_id" => user_id}, "$set" => hash)
    end
    
    def destroy_user_data(user_id)
      @user_data.remove("_id" => user_id)
    end
    
    # Testing
    
    def reject_record_id(mongo_record)
      mongo_record.reject {|k, v| k == "_id"}
    end
    
    def clear!
      @tracking.drop
      @user_data.drop
      create_indices
    end
    
    private
    
    def create_indices
      @user_data.create_index('ext_user_id', unique: true, sparse: true)
    end
  end
end