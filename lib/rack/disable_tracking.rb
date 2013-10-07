module Rack
  class DisableTracking
    def self.wrap(app)
      Middleware.new(app)
    end
    
    def self.setup(env)
      Middleware.setup(env)
    end
    
    class Middleware
      def initialize(app)
        @app = app
      end
    
      def self.setup(env)
        proc do |user_data|
          if user_data["disable_tracking"]
            false
          elsif disable_tracking?(env)
            user_data["disable_tracking"] = true
            false
          else
            true
          end
        end
      end
    
      def call(env)
        @app.call(env)
      end
    
      private
    
      def self.disable_tracking?(env)
        ::Motivoo.configuration.disable_tracking?(env)
      end
    end
  end
end