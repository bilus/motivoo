module Motivoo
  # Starts tracking an 
  def add_legacy_user(opts)
    connection = Connection.instance
    user_data = UserData.add_legacy_user(opts, connection)
    tracker = Tracker.new(user_data, connection)
    first_visit_at = opts[:first_visit_at]
    tracker.acquisition(:visit, allow_repeated: true, on_date: first_visit_at.to_date)
    tracker.acquisition(:first_visit, on_date: first_visit_at.to_date)                                        
    yield(tracker, user_data) if block_given?
  end
end