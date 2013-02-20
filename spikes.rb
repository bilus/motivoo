Motivoo.on_acquisition(:page_view) do |data|
  now = Time.now
  start = data.session["start"] || now
  clicks = (data.session["clicks"] || 0) + 1
  
  happy_visit = 
    if !data.session["retention_happy_visit"] && clicks > 5 && (Time.now - (data.session["start"] || Time.now) > 10
      retention(:happy_visit) 
      true
    end
  data.session.merge!("clicks" => clicks, "start" => start, "retention_happy_visit" => happy_visit)
end

# Ideas:

# Motivoo.serialize_into_session {|user| user.id}
# Motivoo.serialize_from_session {|id| User.find(id)}
# Store user data for 30 days (configurable).
# In reality we need a sliding 

# Remember: visit is only on first first during a session.
Motivoo.on_acquisition(:visit) do |data|
  now = Time.now
  if data.user  # Lazy load.
    visits = (data["visits") || 0) + 1  # Non-atomic, updated below.
    repeat_visitor = 
      if !data.user["retention_repeat_visitor"] && (now - (data.user["signup_at"] || now)) <= 30 * 24 * 60 * 60 # 30 days
        if visits > 3
          retention(:repeat_visitor)
          true
        end
      end
    data.user.merge!("visits" => visits, "retention_repeat_visitor" => repeat_visitor)
  end
end

Motivoo.on_activation(:review) do |data, data|
  unless data.user
    reviews = (data.user["reviews"] || 0) + 1
    frequent_reviewer =
      if !data.user["retention_frequent_reviewer"]
        if reviews > 5
          retention(:frequent_reviewer)
          true
        end
      end
    data.user.merge!("reviews" => reviews, "retention_frequent_reviewer" => frequent_reviewer)
  end
end

Motivo.on_activation(:signup) do |data|
  if data.user
    data.user["signup_at"] = Time.now
  end
end


####
# another solution based on tracking using user id as a subkey. Means 3 extra updates for month, week, day.

Motivoo.on_acquisition(:visit) do |data|
  if data.user && (current_month = data.user.current_month)  # Lazy load.
    now = Time.now
    visits = (current_month["visits") || 0) + 1  # Non-atomic, updated below.
    repeat_visitor = 
      if !current_month["retention_repeat_visitor"] && (now - (current_month["signup_at"] || now)) <= 30 * 24 * 60 * 60 # 30 days
        if visits > 3
          retention(:repeat_visitor)
          true
        end
      end
    current_month.merge!("visits" => visits, "retention_repeat_visitor" => repeat_visitor)
  end
end
