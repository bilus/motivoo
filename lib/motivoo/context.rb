require_relative 'connection'
require_relative 'tracker'
require_relative 'null_tracker'
require_relative 'user_data'
require 'rack/request'

module Motivoo

  # Context for the execution of tracking based on an env hash.
  #
  class Context
    
    # Creates the context for a given block. Used by Rack::Motivoo middleware.
    #
    def self.create!(env, &block)
      connection = Connection.instance
      user_data, is_existing_user = UserData.deserialize_from!(env, connection)
      tracker = Tracker.new(user_data, connection, existing_user: is_existing_user)
      
      run_within_context(env, user_data, tracker, true, &block)
    end
    
    # Creates the context for a given block. Used by Rack::Motivoo middleware.
    # If there is no existing user, it prevents tracking.
    #
    def self.create(env, &block)
      connection = Connection.instance
      user_data, is_existing_user = UserData.deserialize_from(env, connection)
      tracker =
        if is_existing_user
          Tracker.new(user_data, connection, existing_user: is_existing_user)
        else
          NullTracker.instance
        end
      run_within_context(env, user_data, tracker, is_existing_user, &block)
    end
    
    private
    
    def self.run_within_context(env, user_data, tracker, serialize_user_data, &block)
      request = Rack::Request.new(tracker.serialize_into(env))      
      if block_given?
        response = yield(tracker, request) 
        user_data.serialize_into(response) if serialize_user_data
        response.finish
      end
    end
  end
end