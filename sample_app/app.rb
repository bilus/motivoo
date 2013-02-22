require 'sinatra'
require 'rack/motivoo'
require 'motivoo/tracker'
require 'motivoo/report'

connection = Motivoo::Connection.new

users = {
  "bilus" => "1",
  "zwieciu" => "2"
}

use Rack::Motivoo

get "/" do
  haml :index
end

get "/signup/:user" do
  tracker = Motivoo::Tracker.deserialize_from(request.env)
  tracker.set_ext_user_id(users[params[:user]])
  tracker.activation(:signup)
  haml :signup
end

get "/login/:user" do
  tracker = Motivoo::Tracker.deserialize_from(request.env)
  @ext_user_id = users[params[:user]]
  tracker.set_ext_user_id(@ext_user_id)
  haml :login
end

get "/buy" do
  Motivoo::Tracker.deserialize_from(request.env).activation(:buy)
  haml :buy
end

get "/report" do
  @report = Motivoo::Report.new(connection)
  haml :report
end

__END__

@@layout
%html
  %body
    .navbar
      %ul
        %li
          %a{href: "/"} Home
        %li
          %a{href: "/signup"} Signup
        %li
          %a{href: "/login"} Login
        %li
          %a{href: "/buy"} Buy
        %li
          %a{href: "/report"} Report
    .body
      = yield
      
@@ index
Home page

@@ signup
Signup successful!

@@login
Login successful (#{@ext_user_id})!

@@buy
Thank you for your purchase.

@@report
%h3 Visits
= haml(:_sub_report, locals: {entries: @report.acquisitions_by(:month, :visit)}, layout: false)
%h3 First visits
= haml(:_sub_report, locals: {entries: @report.acquisitions_by(:month, :first_visit)}, layout: false)
%h3 Signups
= haml(:_sub_report, locals: {entries: @report.activations_by(:month, :signup)}, layout: false)
%h3 Purchases
= haml(:_sub_report, locals: {entries: @report.activations_by(:month, :buy)}, layout: false)
          
@@_sub_report
%table
  - locals[:entries].to_a.sort {|l, r| l.first <=> r.first}.each do |(k, v)|
    %tr
      %td= k
      %td= v
    