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
    end
  end
  
  context "without creating motivoo context" do
    let(:user) { nil }

    it "should not count visits" do
      u = user
      at("2012-12-12 15:00") { u = get("/", u) }
      at("2012-12-12 15:00") { get("/", u) }
      report.acquisitions_by(:month, :visit).should == {}
    end
  end
  
  context "after motivoo context is created" do
    let(:user) { at("2012-12-12 15:00") { post("/motivoo/") } }

    it "should count first visits" do
      u = user
      at("2012-12-12 15:00") { u = get("/", u) }
      at("2012-12-12 15:00") { get("/", u) }
      report.acquisitions_by(:month, :first_visit).should == {"2012-12" => 1}
    end
  end
end