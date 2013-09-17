# Limited tracking. Doesn't track any events, just assigns the user to cohorts when explicitly asked.

module Motivoo
  class LimitedTracker
    def initialize(*args)
      @full_tracker = Tracker.new(*args)
    end

    def method_missing(*args, &block)
      self
    end

    def respond_to?(message, include_private=false)
      true
    end
    
    def to_a; []; end
    def to_ary; []; end
    def to_s; ""; end
    def to_f; 0.0; end;
    def to_i; 0; end
    def nil?; true; end

    def inspect
      "#<%s:0x%x>" % [self.class, object_id]
    end

    def serialize_into(env)
      env.merge(Tracker::HASH_KEY => self)
      @full_tracker.env = env
    end
    
    def ensure_assigned_to_cohorts
      ap "ensure_assigned_to_cohorts"
      @full_tracker.ensure_assigned_to_cohorts
    end
  end
end