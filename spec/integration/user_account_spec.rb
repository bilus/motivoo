require 'spec_helper'
require 'rack/motivoo'
require 'motivoo/report'

describe "Integration with user accounts" do
  include RequestHelpers

  let(:connection) { Motivoo::Connection.new }
  let(:report) { Motivoo::Report.new(connection) }
  
  def app
    Rack::Builder.app do
      use Rack::Motivoo
      map "/" do
        run lambda { |env|
          [200, {'Content-Type' => 'text/plain'}, ["Hello"]]
        }
      end
      
      map "/review" do
        run lambda { |env|
          Motivoo::Tracker.deserialize_from(env).activation(:review)
          [200, {'Content-Type' => 'text/plain'}, ["Hello"]]
        }
      end
      
      map "/login" do
        run lambda { |env|
          tracker = Motivoo::Tracker.deserialize_from(env)
          tracker.set_ext_user_id("123")
          [200, {'Content-Type' => 'text/plain'}, ["Hello"]]
        }
      end

      map "/signup" do
        run lambda { |env|
          tracker = Motivoo::Tracker.deserialize_from(env)
          tracker.set_ext_user_id("123")
          tracker.activation(:signup)
          [200, {'Content-Type' => 'text/plain'}, ["Hello"]]
        }
      end
    end
    
  end
  
  it "should count initial signup as a visit" do
    at("2012-10-10 12:00") { get("/signup") }
    report.acquisitions_by(:month, :visit).should == {"2012-10" => 1}
    report.activations_by(:month, :signup).should == {"2012-10" => 1}
  end

  it "should track user with user id in cookies" do
    user1 = nil
    
    at("2012-10-10 12:00") { user1 = get("/") }
    at("2012-10-10 13:00") { get("/signup", user1) }
    at("2012-12-15 14:00") { get("/review", user1) }

    report.activations_by(:month, :review).should == {"2012-10" => 1}
  end

  it "should track user after login even without user id in cookies" do
    user1 = nil
    
    at("2012-10-10 12:00") { user1 = get("/") }
    at("2012-10-10 13:00") { get("/signup", user1) }
    
    at("2012-12-15 14:00") { user1 = get("/login") }
    at("2012-12-15 14:00") { get("/review", user1) }

    report.activations_by(:month, :review).should == {"2012-10" => 1}
    report.relative_activations_by(:month, :review).should == {"2012-10" => 1.0}
  end
  
end