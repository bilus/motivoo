require 'spec_helper'

describe "Skipping tracking" do
  include SpecHelpers
  
  def app
    app = Rack::Builder.app do
      use Rack::Motivoo
      run lambda { |env|
        [200, {'Content-Type' => 'text/plain'}, ["Hello"]]
      }
    end
  end
  
  before(:all) do
    Motivoo.configure do |config|
      config.before_acquisition do |status, env|
        skip! if env["PATH_INFO"] == "/"
      end
    end
  end

  after(:all) do
    Motivoo.configure do |config|
      config.before_acquisition do
        # Do not skip.
      end
    end
  end
  
  it "not track visits to home" do
    at("2012-11-10 12:00") { get("/") }
    at("2012-11-10 12:00") { get("/") }
    at("2012-12-01 12:00") { get("/track_this") }
    report.acquisitions_by(:month, :visit).should == {"2012-12" => 1}
  end
end