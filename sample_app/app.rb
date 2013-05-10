# An example app using Motivoo. 
# ..ugly I know.

require 'sinatra'
require 'motivoo'

enable :inline_templates

# Fake users along with their ids.
#
users = {
  "tom" => "1",
  "jerry" => "2",
  "john" => "3"
}

Motivoo.configure do |config|
  config.mongo_host = "localhost"
  
  config.define_cohort("app_version") do
    "v1.0"
  end
  
  config.define_cohort("time_to_buy") do
    nil
  end
  
  config.define_cohort("time_to_contact") do
    nil
  end
  
  config.before_activation do |status, env, tracker, user|
    case status
    when :buy
      time_since_first_visit = Time.now - user.first_visit_at
      ttb = 
        if time_since_first_visit < 60
          "< 1 minute"
        elsif time_since_first_visit < 180
          "< 3 minutes"
        else
          ">= 3 minutes"
        end
        
      user.assign_to("time_to_buy", ttb)
    when :contact
      time_since_first_visit = Time.now - user.first_visit_at
      ttc = 
        if time_since_first_visit < 60
          "< 1 minute"
        elsif time_since_first_visit < 180
          "< 3 minutes"
        else
          ">= 3 minutes"
        end
      user.assign_to("time_to_contact", ttc)
    end
  end

  TWO_MINUTES = 2 * 60
  FIVE_MINUTES = 5 * 60
  
  config.on_repeat_visit do |tracker, user|
    puts "on_repeat_visit #{user.inspect}"
    time_since_first_visit = Time.now - user.first_visit_at
    if time_since_first_visit > TWO_MINUTES
      puts "retention :back_after_two_minutes"
      tracker.retention(:back_after_two_minutes)
    end
    if time_since_first_visit > FIVE_MINUTES
      puts "retention :back_after_five_minutes"
      tracker.retention(:back_after_five_minutes)
    end
  end
end

use Rack::Motivoo

get "/" do
  haml :index
end

get "/signup/:user" do
  tracker = Motivoo::Tracker.deserialize_from(request.env)
  @ext_user_id = users[params[:user]]
  tracker.set_ext_user_id(@ext_user_id)
  tracker.activation(:signup)
  haml :signup
end

get "/login/:user" do
  tracker = Motivoo::Tracker.deserialize_from(request.env)
  @ext_user_id = users[params[:user]]
  tracker.set_ext_user_id(@ext_user_id)
  tracker.activation(:login)
  haml :login
end

get "/buy" do
  Motivoo::Tracker.deserialize_from(request.env).activation(:buy)
  haml :buy
end

get "/report" do
  @report = Motivoo::Report.new(Motivoo::Connection.instance)
  haml :report
end

get "/contact/:user" do
  tracker = Motivoo::Tracker.deserialize_from(request.env)
  tracker.act_as!(users[params[:user]])
  tracker.activation(:contact)
  haml :contact
end

__END__

@@layout
%html
  %body
    .navbar
      %ul
        %li
          %a{href: "/"} Home
      %ul
        %li
          %a{href: "/signup/jerry"} Signup as Jerry
        %li
          %a{href: "/login/jerry"} Login as Jerry
        %li
          %a{href: "/signup/tom"} Signup as Tom
        %li
          %a{href: "/login/tom"} Login as Tom
        %li
          %a{href: "/signup/john"} Signup as John
        %li
          %a{href: "/login/john"} Login as John
      %ul
        %li
          %a{href: "/contact/jerry"} Contact Jerry
        %li
          %a{href: "/contact/tom"} Contact Tom
        %li
          %a{href: "/contact/john"} Contact John
      %ul
        %li
          %a{href: "/buy"} Buy
      %ul
        %li
          %strong
            %a{href: "/report"} Report
    .body
      = yield
      
@@index
Home page

@@signup
Signup successful (#{@ext_user_id})!

@@login
Login successful (#{@ext_user_id})!

@@buy
Thank you for your purchase.

@@contact
User has been contacted!

@@report
= haml(:_report_for_category, locals: {title: "By day", category: :day}, layout: false)
/= haml(:_report_for_category, locals: {title: "By week", category: :week}, layout: false)
/= haml(:_report_for_category, locals: {title: "By month", category: :month}, layout: false)
/= haml(:_report_for_category, locals: {title: "By app version", category: :app_version}, layout: false)


= haml(:_report_for_time_to_buy, locals: {title: "By time to buy", category: :time_to_buy}, layout: false)
= haml(:_report_for_time_to_contact, locals: {title: "By time to get contacted", category: :time_to_contact}, layout: false)
    
    
    
@@_report_for_time_to_buy
%h1= locals[:title]

%h2 The funnel 
- buys = @report.activations_by(locals[:category], :buy)
%h3 Purchases
= haml(:_report_for_status, locals: {entries: @report.activations_by(locals[:category], :buy)})

%h3 # Signups
= haml(:_report_for_status, locals: {entries: @report.activations_by(locals[:category], :signup)})
%h3 % Signups
= haml(:_report_for_status, locals: {entries: @report.relative_activations_by(locals[:category], :signup, buys)})
    
@@_report_for_time_to_contact
%h1= locals[:title]

%h2 The funnel 
- contacts = @report.activations_by(locals[:category], :contact)
%h3 Contacts
= haml(:_report_for_status, locals: {entries: @report.activations_by(locals[:category], :contact)})

%h3 # Signups
= haml(:_report_for_status, locals: {entries: @report.activations_by(locals[:category], :signup)})
%h3 % Signups
= haml(:_report_for_status, locals: {entries: @report.relative_activations_by(locals[:category], :signup, contacts)})
    
    
@@_report_for_category
%h1= locals[:title]

%h2 The funnel 
- first_visits = @report.acquisitions_by(locals[:category], :first_visit)
%h3 First visits
= haml(:_report_for_status, locals: {entries: @report.acquisitions_by(locals[:category], :first_visit)}, layout: false)
%h3 Activation - contact
= haml(:_report_for_status, locals: {entries: @report.relative_activations_by(locals[:category], :contact, first_visits)})
%h3 Activation - signup
= haml(:_report_for_status, locals: {entries: @report.relative_activations_by(locals[:category], :signup, first_visits)})
%h3 Activation - purchase
= haml(:_report_for_status, locals: {entries: @report.relative_activations_by(locals[:category], :buy, first_visits)})
%h3 Retention - back after 2 minutes
= haml(:_report_for_status, locals: {entries: @report.relative_retentions_by(locals[:category], :back_after_two_minutes, first_visits)})
%h3 Retention - back after 5 minutes
= haml(:_report_for_status, locals: {entries: @report.relative_retentions_by(locals[:category], :back_after_five_minutes, first_visits)})

%h2 In absolute values
%h3 Visits
= haml(:_report_for_status, locals: {entries: @report.acquisitions_by(locals[:category], :visit)}, layout: false)
%h3 First visits
= haml(:_report_for_status, locals: {entries: @report.acquisitions_by(locals[:category], :first_visit)}, layout: false)
%h3 Signups
= haml(:_report_for_status, locals: {entries: @report.activations_by(locals[:category], :signup)}, layout: false)
%h3 Purchases
= haml(:_report_for_status, locals: {entries: @report.activations_by(locals[:category], :buy)}, layout: false)

          
@@_report_for_status
%table
  - locals[:entries].to_a.sort {|l, r| l.first <=> r.first}.each do |(k, v)|
    %tr
      %td= k
      %td= v
    
