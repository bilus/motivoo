module Motivoo
  class Visit
    VISIT_TRACKED_COOKIE_KEY = "motivoo.vt"

    def self.track(tracker, request)
      response = nil
      begin
        response = yield(tracker, request)
      ensure
        unless request.cookies[VISIT_TRACKED_COOKIE_KEY]
          tracker.acquisition(:visit)
          response.set_cookie(VISIT_TRACKED_COOKIE_KEY, true)
        end
      end
      response
    end
  end
end