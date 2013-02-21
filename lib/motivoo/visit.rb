module Motivoo
  class Visit
    VISIT_TRACKED_COOKIE_KEY = "motivoo.vt"

    def self.track(tracker, request)
      response = nil
      begin
        response = yield(tracker, request)
      ensure
        tracker.acquisition(:first_visit)
        # We're tracking visit here because the current user might have been overriden by the app (authentication).
        unless request.cookies[VISIT_TRACKED_COOKIE_KEY]
          tracker.acquisition(:visit, allow_repeated: true)
          response.set_cookie(VISIT_TRACKED_COOKIE_KEY, true)
        end
      end
      response
    end
  end
end