require_relative 'connection'
require_relative 'tracker'
require_relative 'null_tracker'
require_relative 'limited_tracker'
require_relative 'user_data'
require 'rack/request'

module Motivoo

  # Context for the execution of tracking based on an env hash.
  #
  class Context
    
    # Creates the context for a given block. Used by Rack::Motivoo middleware.
    #
    def self.create!(env, &block)
      self.do_create(env, block) do 
        Tracker
      end
    end
    
    # Creates the context for a given block. Used by Rack::Motivoo middleware.
    # If there is no existing user, it prevents tracking.
    #
    def self.create(env, &block)
      self.do_create(env, block) do |is_existing_user|
        is_existing_user ? Tracker : LimitedTracker
      end
    end
    
    private

    def self.do_create(env, block, &tracker_type)
      connection = Connection.instance
      user_data, is_existing_user = UserData.deserialize_from!(env, connection)
      tracker = create_tracker(tracker_type.call(is_existing_user), user_data, connection, existing_user: is_existing_user)
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
