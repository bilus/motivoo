require 'nullobject'

module Motivoo
  class NullTracker
    include Null

    def serialize_into(env)
      env.merge(Tracker::HASH_KEY => self)
    end
  end
end