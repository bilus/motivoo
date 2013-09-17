require_relative 'connection'
require_relative 'user_data'
require 'rack/request'

module Motivoo

  # Context for the execution of tracking based on an env hash.
  #
  class Context
    
    # Creates the context for a given block using tracker class returned by tracker_type_factory. 
    # Used by Rack::Motivoo middleware.
    #
    def self.create(env, tracker_type_factory, &block)
      self.do_create(env, block, &tracker_type_factory)
    end
    
    private

    def self.do_create(env, block, &tracker_type)
      connection = Connection.instance
      user_data, is_existing_user = UserData.deserialize_from!(env, connection)
      tracker = create_tracker(tracker_type.call(user_data, is_existing_user), user_data, connection, existing_user: is_existing_user)
      run_within_context(env, user_data, tracker, &block)
    end
    
    def self.create_tracker(type, user_data, connection, opts)
      type.new(user_data, connection, opts)
    end
    
    def self.run_within_context(env, user_data, tracker, &block)
      request = Rack::Request.new(tracker.serialize_into(env))    
      tracker.ensure_assigned_to_cohorts
      if block_given?
        response = yield(tracker, request) 
        user_data.serialize_into(response)
        response.finish
      end
    end
  end
end
