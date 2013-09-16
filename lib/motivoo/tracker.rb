require_relative 'user_data'

module Motivoo
  
  # Event tracking.
  #
  class Tracker

    DEFAULT_COHORTS = {
      # Note: 'today' method is provided by Tracker. Use it instead of Date.today to make it possible for tracker to track events
      # on a different date than the current one.
      "day" => proc { today.strftime("%Y-%m-%d") },
      "month" => proc { today.strftime("%Y-%m") },
      "week" => proc { date = today; "#{date.year}(#{date.cweek})" }
    }
    
    @@callbacks = {}
    @@cohorts = DEFAULT_COHORTS
    
    # Returns defined cohorts.
    #
    def Tracker.cohorts
      @@cohorts
    end
    
    # Define a cohort.
    #
    # @example
    #   Tracker.define_cohort("release") { "1.0.2" }
    #
    def Tracker.define_cohort(name)
      raise "Cohort #{name} already defined." if @@cohorts.member?(name)
      @@cohorts[name] = Proc.new # Let users use define_cohort without any block arguments.
    end
    
    # Creates a tracker.
    #
    def initialize(user_data, connection, options = {})
      @connection = connection
      @user_data = user_data
      @env = {}
      invoke_repeat_visit_callback if options[:existing_user]
    end
    
    def initialize_copy(_)
      super
      @env = if @env then @env.clone end
      @user_data = @user_data.clone
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
    def Tracker.deserialize_from(env)
      env[HASH_KEY] or raise "Tracker couldn't be found in the env hash. Internal error."
    end
    
    # Associates the currently tracked user with an external user.
    # Usually called after login or signup with id of the user in the user's database.
    # This id is not visible in the cookies.
    #
    def set_ext_user_id(ext_user_id)
      log "set_ext_user_id(#{ext_user_id.to_s})"
      old_user_id = @user_data.user_id
      @user_data.set_ext_user_id(ext_user_id)
      invoke_repeat_visit_callback if @user_data.user_id != old_user_id
    end
    
    # Returns copy of the tracker switched to user based on external user id. Allows to act on behalf on another user.
    # It doesn't trigger on_repeat_visit callback.
    #
    def act_as(ext_user_id)
      log "act_as(#{ext_user_id.to_s})"
      self.clone.act_as!(ext_user_id)
    end
    
    # Internal id of the currently tracked user.
    # Note: It's not the same as external user id set by a call to set_ext_user_id!
    #
    def user_id
      @user_data.user_id
    end
    
    # Assigns the current user to cohorts unless they're already assigned.
    #
    def ensure_assigned_to_cohorts(date_override = nil)
      if @user_data.cohorts.empty?
        Tracker.cohorts.each_pair do |cohort_category, generator| 
          cohort = generate_cohort(generator, date_override)
          @user_data.assign_to(cohort_category, cohort) if cohort
        end 
      end      
    end

    # Callback invoked before any event is tracked whether it's actually tracked or not (track_once).
    def Tracker.before_tracking(&callback)
      @@callbacks[:before_tracking] = callback
    end

    # Callback invoked before any event is tracked iff the event is tracked (track_once)..
    def Tracker.before_any(&callback)
      @@callbacks[:before_any] = callback
    end

    [:acquisition, :activation, :retention, :referral, :revenue].each do |category| # TODO: Duplication -- Report#acquisitions_by etc.
      
      # Event tracking methods.
      # 
      # @example
      #   tracker.activation(:signup)
      # tracks a signup of the current user.
      #
      define_method(category) do |event, options = {}|
        # puts "#{category.to_s}(#{event.inspect}) -- @user_data = #{@user_data.inspect}"
        opts = options.dup
        allow_repeated = opts.delete(:allow_repeated)
        on_date = opts.delete(:on_date)
        raise "Unrecognized option(s): #{options.keys.join(', ')}." unless opts.empty?
        
        begin
          return if invoke_callback(@@callbacks[:before_tracking], event).skip?
          if allow_repeated
            do_track(category, event, on_date)
          else
            ensure_track_once(category, event) do
              do_track(category, event, on_date)
            end
          end
        rescue => e
          Kernel.puts "Error in Motivoo::Tracker##{category.to_s}: #{e}"
        end
      end
      
      # Callbacks invoked before an event is tracked in a given category iff the event is tracked (track_once).
      #
      # @example
      #   Tracker.before_activation { }
      # will be invoked once before every activation.
      #
      # In addition, before_any is invoked for any category in addition to the category-specific handler.
      #
      # Arguments passed to the callback block:
      #   event - the event (e.g. :visit),
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
      #   Tracker.before_acquisition { |event, | puts event }
      # will trace event for each acquisition.
      #
      # Following this with:
      #   Tracker.before_acquisition {}
      # turns off tracing.
      #
      (class << self; self; end).send(:define_method, "before_#{category.to_s}".to_sym) do |&callback|
        @@callbacks["before_#{category.to_s}".to_sym] = callback
      end
    end

    # Callback invoked for every repeat visit (actually, every repeat HTTP request) of the same user.
    def Tracker.on_repeat_visit(&callback)
      @@callbacks[:on_repeat_visit] = callback
    end
    
    # Removes a cohort. Doesn't delete the corresponding data from the database.
    # For testing purposes only.
    def Tracker.remove_cohort!(category)
      @@cohorts.delete(category)
    end
    
    private

    def ensure_track_once(category, event)
      key = "#{category.to_s}##{event.to_s}"
      # puts "ensure_track_once key = #{key.inspect} #{@user_data.inspect}"
      already_tracked = @user_data[key]
      # puts "already_tracked? #{already_tracked}"
      unless already_tracked
        @user_data[key] = true
        yield
      end
    end
    
    def do_track(category, event, date_override = nil)
      callback_result = invoke_before_callbacks(category, event)
      return if callback_result.skip?
      
      log "#{category} #{event}"
      
      ensure_assigned_to_cohorts(date_override)
      
      @user_data.cohorts.each_pair do |cohort_category, cohort|
        # When cohort is nil, it means that it shouldn't be tracked (usually, because it'll be set later into the funnel because it depends on some action of the user).
        unless cohort.nil?
          # TODO: Performance issue, each one is a separate HTTP call to the database server. Calls can be easily combined:
          # @user_data.assign_to(cohort_category1: cohort1, cohort_category2: cohort2 ...)
          # @connection.track(..array...)
          # Arguments to these calls can be easily built using inject instead of each_pair above.
          @connection.track(category.to_s, event.to_s, cohort_category, cohort)
        end
      end
    end
    
    class CallbackContext
      def initialize(*args)
        @args = args
        @skip = false
      end
      
      def run(&block)
        instance_exec(*@args, &block)
        self
      end

      def skip!
        @skip = true
      end
      
      def skip?
        @skip
      end
    end
    
    def invoke_before_callbacks(category, event)
      before_any = @@callbacks[:before_any]
      result_for_any = invoke_callback(before_any, event)
      if result_for_any.skip?
        result_for_any
      else
        result = invoke_callback(find_callback(category), event)
        result.skip! if result_for_any.skip?
        result
      end
    end
    
    def find_callback(category)
      @@callbacks["before_#{category.to_s}".to_sym]
    end
    
    def invoke_callback(callback, event)
      block = (callback || lambda {|*args| })
      CallbackContext.new(event, @env, self, @user_data).run(&block)
    end   
    
    def invoke_repeat_visit_callback
      callback = @@callbacks[:on_repeat_visit]
      callback.call(self, @user_data) if callback
    end 
    
    protected
    
    def act_as!(ext_user_id)
      @user_data.set_ext_user_id(ext_user_id)
      self
    end
    
    class CohortContext
      def initialize(*args)
        @args = args
      end
      
      def run(&block)
        instance_exec(*@args, &block)
      end
      
      def today=(date)
        @today_override = date
      end
      
      def today
        @today_override || Date.today
      end
    end
    
    def generate_cohort(generator, date_override = nil)
      ctx = CohortContext.new(@env)
      ctx.today = date_override if date_override
      ctx.run(&generator)
    end
    
    private
    
    def remote_ip
      (@env['HTTP_X_FORWARDED_FOR'] || "").split(",").first
    end
    
    def log(str)
      if ENV["RACK_ENV"] == "production"
        puts "[MOTIVOO] #{remote_ip} #{@user_data.user_id} #{str}"
        $stdout.flush
      end
    end
  end
end