require 'mongo'
require 'singleton'
require_relative 'configuration'

module Motivoo
  
  # Connection to a MongoDB database storing Motivoo data.
  #
  class Connection
    include Singleton
    
    # Creates a new connection.
    #
    def initialize
      config = Motivoo.configuration
      db = Mongo::Connection.new(config.mongo_host, config.mongo_port)[config.mongo_db]
      db.authenticate(config.mongo_user, config.mongo_password) if config.mongo_user
      
      @tracking = db["tracking"]
      @user_data = db["user_data"]
      create_indices
    end
    
    # Event tracking
    
    # Tracks an event.
    #
    def track(category, status, cohort_name, cohort)
      # When changing the query, revise Connection#create_indices.
      @tracking.update({category: category, status: status, cohort_name: cohort_name, cohort: cohort}, {"$inc" => {count: 1}}, upsert: true)
    end
  
    # Finds an event.
    #
    def find(category, status, cohort_name)
      # When changing the query, revise Connection#create_indices. It's less important than Connection#track while only Report uses it.
      @tracking.find(category: category, status: status, cohort_name: cohort_name).to_a.inject({}) {|a, r| a.merge(r["cohort"] => r["count"])}
    end
    
    # User data
    
    # Finds user data given an internal user id and if it's not there, creates it.
    # Returns a hash containing user data without the primary key itself (user id).
    #
    def find_or_create_user_data(user_id)
      # NOTE: The code below is designed to avoid a race condition.
      begin
        @user_data.insert("_id" => BSON::ObjectId(user_id)) 
        {}  # New record.
      rescue Mongo::OperationFailure => e
        raise unless e.error_code == 11000 # duplicate key error index
        reject_record_id(@user_data.find_one("_id" => BSON::ObjectId(user_id)))  # Existing record.
      end
      # TODO: Using exceptions to handle this is slow and ugly. 
    end
    
    # Finds user data by an external user id.
    # Returns ar array consisting of a primary key (user id) and a hash containing user data or nil if record not found.
    # TODO: Change it to find_user_data(query_hash), in this specific case find_user_data("ext_user_id" => ext_user_id) so UserData completely encapsulates the concept.
    #
    def find_user_data_by_ext_user_id(ext_user_id)
      if existing_record = @user_data.find_one("ext_user_id" => ext_user_id)
        [existing_record["_id"].to_s, reject_record_id(existing_record)]
      end
    end
    
    # Generates a new unique user id. 
    # It inserts a new record to make it possible to update it using assign_cohort, set_user_data without worrying about the record's existence but technically this isn't necessary.
    #
    def generate_user_id
      @user_data.insert({}).to_s
    end
    
    # Assigns a user to a cohort.
    #
    def assign_cohort(user_id, cohort_name, cohort)
      @user_data.update({"_id" => BSON::ObjectId(user_id)}, "$set" => {"cohorts.#{cohort_name}" => cohort})
    end
    
    # Sets a user-defined user data field.
    #
    def set_user_data(user_id, hash)
      @user_data.update({"_id" => BSON::ObjectId(user_id)}, "$set" => hash)
    end
    
    # Returns a user-defined user data field or nil if record not found.
    #
    def get_user_data(user_id, key)
      record = @user_data.find_one({"_id" => BSON::ObjectId(user_id)}, fields: {key => 1})
      if record
        record[key]
      else
        nil
      end
    end
    
    # Removes user data from the database.
    #
    def destroy_user_data(user_id)
      @user_data.remove("_id" => BSON::ObjectId(user_id))
    end
    
    # Testing

    # Removes all tables and indices.
    #
    def clear!
      @tracking.drop
      @user_data.drop
      create_indices
    end
    
    private
    
    def reject_record_id(mongo_record)
      mongo_record.reject {|k, v| k == "_id"}
    end
    
    def create_indices
      @user_data.ensure_index('ext_user_id', unique: true, sparse: true)
      @tracking.ensure_index("category" => 1, "status" => 1, "cohort_name" => 1, "cohort" => 1)
    end
  end
end