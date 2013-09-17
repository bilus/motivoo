require 'spec_helper'

describe "Javascript anti-bot/crawler/spider protection" do
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
  
  before(:each) do
    Motivoo.configure do |config|
      config.bot_protect_js = true
      
      config.define_cohort("referrer") do |env|
        Rack::Request.new(env).params["ref"] || "Unknown"
      end
    end
  end
  
  after(:each) do
    Motivoo::Tracker.remove_cohort!("referrer")
  end
  
  context "without call to JS" do
    let(:user) { nil }

    it "should not count visits" do
      u = user
      at("2012-12-12 15:00") { u = get("/", u) }
      at("2012-12-12 15:00") { get("/", u) }
      report.acquisitions_by(:month, :visit).should == {}
    end
  end
  
  context "without call to JS" do
    let(:user) { at("2012-12-12 15:00") { post("/motivoo/") } }

    it "should count first visits" do
      u = user
      at("2012-12-12 15:00") { u = get("/", u) }
      at("2012-12-12 15:00") { get("/", u) }
      report.acquisitions_by(:month, :first_visit).should == {"2012-12" => 1}
    end
  end

  it "should remember user's original cohorts" do
    u = nil
    at("2012-12-12 15:00") { u = get("/?ref=ABC", u) }
    at("2012-12-12 15:00") { post("/motivoo/", u) }

    report.acquisitions_by(:referrer, :first_visit).should == {"ABC" => 1}
  end
end