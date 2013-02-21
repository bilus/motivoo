require 'spec_helper'

describe "Visit vs. first visit" do
  include SpecHelpers
  
  def app
    Rack::Builder.app do
      use Rack::Motivoo
      map "/" do
        run lambda { |env|
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
  
  it "should count visits" do
    user = nil
    at("2012-12-12 15:00") { user = get("/") }
    at("2012-12-12 15:00") { get("/", user) }
    report.acquisitions_by(:month, :visit).should == {"2012-12" => 1}
  end

  it "should count first visits" do
    user = nil
    at("2012-12-12 15:00") { user = get("/") }
    at("2012-12-12 15:00") { get("/", user) }
    report.acquisitions_by(:month, :first_visit).should == {"2012-12" => 1}
  end
  
  it "should count repeat visits for the same user" do
    user = nil
    at("2012-10-12 15:00") { user = get("/") }
    at("2012-10-12 15:00") { get("/", user) }
    at("2012-10-12 15:00") { get("/signup", user) }
    
    at("2012-12-12 15:00") { user = get("/login") }
    at("2012-12-12 15:00") { get("/", user) }
    report.acquisitions_by(:month, :visit).should == {"2012-10" => 2}
  end
  
  it "should only count the first visit once per user" do
    user = nil
    at("2012-10-12 15:00") { user = get("/") }
    at("2012-10-12 15:00") { get("/", user) }
    at("2012-10-12 15:00") { get("/signup", user) }
    
    at("2012-12-12 15:00") { user = get("/login") }
    at("2012-12-12 15:00") { get("/", user) }
    report.acquisitions_by(:month, :firstvisit).should == {"2012-10" => 1}
  end
end