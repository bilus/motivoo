module Motivoo
  
  # Encapsulates visit tracking. Used by Rack::Motivoo middleware.
  #
  class Visit
    VISIT_TRACKED_COOKIE_KEY = "_mvt"

    # Tracks visit and the first visit of the current user.
    def self.track(tracker, request)
      response = nil
      begin
        response = yield(tracker, request)
      ensure
        tracker.acquisition(:first_visit)
        # We're tracking visit here because the current user might have been overriden by the app (authentication).
        unless request.cookies[VISIT_TRACKED_COOKIE_KEY]
          tracker.acquisition(:visit, allow_repeated: true)
          response.set_cookie(VISIT_TRACKED_COOKIE_KEY, value: true, path: "/")
        end
      end
      response
    end
  end
end