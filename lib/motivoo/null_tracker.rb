require 'nullobject'

module Motivoo
  class NullTracker
    include Null

    def serialize_into(env)
      env.merge("null_tracker" => self)
    end
    
    def self.deserialize_from(env)
      env["null_tracker"] or raise "NullTracker couldn't be found in the env hash. Internal error."
    end
  end
end