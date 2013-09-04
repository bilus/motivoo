module Motivoo
  
  # Encapsulates visit tracking. Used by Rack::Motivoo middleware.
  #
  class Visit
    VISIT_TRACKED_COOKIE_KEY = "_mvt"

    # Track each visit plus the first visit of the current user.
    #
    def self.track(tracker, request)
      response = yield(tracker, request)
      
      if response.status.to_i == 200
        tracker.acquisition(:first_visit)
        # We're tracking visit here because the current user might have been overriden by the app (authentication).
        unless request.cookies[VISIT_TRACKED_COOKIE_KEY] == tracker.user_id
          tracker.acquisition(:visit, allow_repeated: true)
          response.set_cookie(VISIT_TRACKED_COOKIE_KEY, value: tracker.user_id, path: "/")
        end
      end
      response
    end
  end
end