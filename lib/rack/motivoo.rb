require_relative '../motivoo/context'
require_relative '../motivoo/visit'
require_relative './bot_protection'
require_relative './disable_tracking'

require 'motivoo/tracker'
require 'motivoo/limited_tracker'

module Rack
  
  # Rack middleware.
  # 
  # Usage:
  #   use Rack::Motivoo
  #
  class Motivoo
    def initialize(app)
      @app = app
      @stack = [DisableTracking, BotProtection]
    end
    
    def call(env)
      with_context_for(env) do |tracker, request|
        if track_path?(request)
          ::Motivoo::Visit.track(tracker, request) do |tracker, request|
            app_response_to(request) 
          end
        else
          app_response_to(request)
        end
      end
    end
    
    protected
    
    def with_context_for(env, &block)
      ::Motivoo::Context.create(env, apply_setup(env), &block)
    end
    
    def track_path?(request)
      # FIX: No cookies passed by Chrome when it requests favicon.ico/png which results in new user data record being 
      # created for every request. AFAIK, IE keeps a separate cookie store for favicon requests. 
      # Actually, we don't care about binary files at all, so while we're at it, let's ignore them all. In production environment, 
      # most of these assets will be fetched from an asset server but it won't hurt to ignore them anyway while at the same time 
      # taking care of favicons -- THE serious offenders.
      is_binary = request.env["PATH_INFO"] =~ /\.jpg|jpeg|png|ico|gif|pdf|tif|tiff|doc|xls|docx|xlsx|css|js$/i
      !is_binary
    end
    
    def app_response_to(request)
      status, headers, body = apply_wrap.call(request.env)
      Response.new(body, status, headers)
    end
    
    def apply_wrap
      @stack.inject(@app) {|result, wrapper| wrapper.wrap(result)}
    end

    # Compose procs returned by #setup methods. If any returns false, use tracker that doesn't really track
    # anything but has a compatible interface (note: it's not a Null Object, it does have functionality).
    def apply_setup(env)
      proc do |user_data, is_existing_user|
        track_flags = @stack.map {|wrapper| wrapper.setup(env).call(user_data, is_existing_user)}
        if track_flags.any? {|track| !track}
          ::Motivoo::LimitedTracker
        else
          ::Motivoo::Tracker
        end
      end
    end
  end
end