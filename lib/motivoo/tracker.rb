require_relative 'user_data'

module Motivoo
  
  # Event tracking.
  #
  class Tracker
    
    @@callbacks = {}
    
    @@cohorts = {
      "day" => lambda { Date.today.strftime("%Y-%m-%d") },
      "month" => lambda { Date.today.strftime("%Y-%m") },
      "week" => lambda { date = Date.today; "#{date.year}(#{date.cweek})" }
    }
    
    # Returns defined cohorts.
    #
    def self.cohorts
      @@cohorts
    end
    
    # Define a cohort.
    #
    # @example
    #   Tracker.define_cohort("release") { "1.0.2" }
    #
    def self.define_cohort(name, &block)
      raise "Cohort #{name} already defined." if @@cohorts.member?(name)
      @@cohorts[name] = block
    end
    
    # Creates a tracker.
    #
    def initialize(user_data, connection, options = {})
      @connection = connection
      @user_data = user_data
      invoke_repeat_visit_callback if options[:existing_user]
    end
    
    HASH_KEY = "motivoo.tracker"
    
    # Injects itself into the env hash (used internally to store a Tracker object in Rack env).
    #
    def serialize_into(env)
      @env = env.dup
      env.merge(HASH_KEY => self)
    end
    
    # Returns a Tracker instance from the env hash (used internally with Rack env).
    #
    def self.deserialize_from(env)
      env[HASH_KEY] or raise "Tracker couldn't be found in the hash. Internal error."
    end
    
    # Associates the currently tracked user with an external user.
    # Usually called after login or signup with id of the user in the user's database.
    # This id is not visible in the cookies.
    #
    def set_ext_user_id(ext_user_id)
      old_user_id = @user_data.user_id
      @user_data.set_ext_user_id(ext_user_id)
      invoke_repeat_visit_callback if @user_data.user_id != old_user_id
    end
    
    # Switches to user based on external user id. Allows to act on behalf on another user.
    # It doesn't trigger on_repeat_visit callback.
    #
    def act_as!(ext_user_id)
      @user_data.set_ext_user_id(ext_user_id)
      self
    end
    
    # Internal id of the currently tracked user.
    # Note: It's not the same as external user id set by a call to set_ext_user_id!
    #
    def user_id
      @user_data.user_id
    end

    [:acquisition, :activation, :retention, :referral, :revenue].each do |category| # TODO: Duplication -- Report#acquisitions_by etc.
      
      # Event tracking methods.
      # 
      # @example
      #   tracker.activation(:signup)
      # tracks a signup of the current user.
      #
      define_method(category) do |status, options = {}|
        # puts "#{category.to_s}(#{status.inspect}) -- @user_data = #{@user_data.inspect}"
        allow_repeated = options.delete(:allow_repeated)
        raise "Unrecognized option(s): #{options.keys.join(', ')}." unless options.empty?
        
        begin
          if allow_repeated
            do_track(category, status)
          else
            ensure_track_once(category, status) do
              do_track(category, status)
            end
          end
        rescue => e
          Kernel.puts "Error in Motivoo::Tracker##{category.to_s}: #{e}"
        end
      end
      
      # Callbacks invoked before an event is tracked in a given category.
      #
      # @example
      #   Tracker.before_activation { }
      # will be invoked once before every activation.
      #
      # In addition, before_any is invoked for any category in addition to the category-specific handler.
      #
      # Arguments passed to the callback block:
      #   status - the status (e.g. :visit),
      #   env - the env hash,
      #   tracker - Tracker instance,
      #   user_data - UserData instance.
      #
      # To skip tracking, call skip! (see skip_tracking_spec for an example).
      #
      # NOTE: Be careful when tracking events from within the handler to avoid stack overflow errors.
      #
      # IMPORTANT: Only one callback per category is currently supported.
      #
      # @example
      #   Tracker.before_acquisition { |status, | puts status }
      # will trace status for each acquisition.
      #
      # Following this with:
      #   Tracker.before_acquisition {}
      # turns off tracing.
      #
      (class << self; self; end).send(:define_method, "before_#{category.to_s}".to_sym) do |&callback|
        @@callbacks["before_#{category.to_s}".to_sym] = callback
      end
    end

    # Callback invoked before any event is tracked.
    def Tracker.before_any(&callback)
      @@callbacks[:before_any] = callback
    end
    
    # Callback invoked for every repeat visit (actually, every repeat HTTP request) of the same user.
    def Tracker.on_repeat_visit(&callback)
      @@callbacks[:on_repeat_visit] = callback
    end
    
    private

    def ensure_track_once(category, status)
      key = "#{category.to_s}##{status.to_s}"
      # puts "ensure_track_once key = #{key.inspect} #{@user_data.inspect}"
      already_tracked = @user_data[key]
      # puts "already_tracked? #{already_tracked.inspect}"
      unless already_tracked
        @user_data[key] = true
        yield
      end
    end
    
    def do_track(category, status)
      callback_result = invoke_before_callbacks(category, status)
      return if callback_result.skip?
      
      user_cohorts = @user_data.cohorts
      Tracker.cohorts.each_pair do |cohort_name, proc|
        assigned_cohort = user_cohorts[cohort_name]
        cohort = assigned_cohort || proc.call
        
        # When cohort is nil, it means that it shouldn't be tracked (usually, because it'll be set later into the funnel because it depends on some action of the user).
        unless cohort.nil?
          # TODO: Performance issue, each one is a separate HTTP call to the database server. Calls can be easily combined:
          # @user_data.assign_to(cohort_name1: cohort1, cohort_name2: cohort2 ...)
          # @connection.track(..array...)
          # Arguments to these calls can be easily built using inject instead of each_pair above.
          @user_data.assign_to(cohort_name, cohort) unless assigned_cohort
          @connection.track(category.to_s, status.to_s, cohort_name, cohort)
        end
      end
    end
    
    class CallbackContext
      def initialize(*args, &block)
        @skip = false
        instance_exec(*args, &block)
      end

      def skip!
        @skip = true
      end
      
      def skip?
        @skip
      end
    end
    
    def invoke_before_callbacks(category, status)
      before_any = @@callbacks[:before_any]
      result_for_any = invoke_callback(before_any, status)
      if result_for_any.skip?
        result_for_any
      else
        result = invoke_callback(find_callback(category), status)
        result.skip! if result_for_any.skip?
        result
      end
    end
    
    def find_callback(category)
      @@callbacks["before_#{category.to_s}".to_sym]
    end
    
    def invoke_callback(callback, status)
      block = (callback || lambda {|*args| })
      CallbackContext.new(status, @env, self, @user_data, &block)
    end   
    
    def invoke_repeat_visit_callback
      callback = @@callbacks[:on_repeat_visit]
      callback.call(self, @user_data) if callback
    end 
  end
end