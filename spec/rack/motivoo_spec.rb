require 'spec_helper'
require 'rack/test'
require 'rack/motivoo'

describe "Rack middleware" do
  let!(:tracker) do
    tracker = mock("tracker").as_null_object
    Motivoo::Context.stub!(:create).and_yield(tracker, request)
    tracker
  end
  
  let(:app_response) { [200, { 'Content-Type' => 'text/plain' }, ['<body>hello</body>']] }
  let(:app) { lambda { |env| app_response } }
  let(:middleware) { Rack::Motivoo.new(app) }

  let!(:response) do 
    response = mock("response").as_null_object 
    Rack::Response.stub!(:new).and_return(response)
    response
  end
  
  let!(:request) do 
    request = mock("request").as_null_object
    request.stub!(:cookies).and_return({})
    Rack::Request.stub!(:new).and_return(request)
    request
  end
  
  def call(middleware, path) 
    middleware.call(Rack::MockRequest.env_for(path))
  end
  
  it "should create context" do
    Motivoo::Context.should_receive(:create).and_yield(tracker, request)
    call(middleware, "/")
  end
    
  it "should track visit" do
    tracker.should_receive(:acquisition).with(:visit)
    call(middleware, "/")
  end
  
  it "should store session cookie to mark session as tracked" do
    response.should_receive(:set_cookie)
    call(middleware, "/")
  end

  it "should not track already tracked visit" do
    tracker.should_not_receive(:acquisition)
    request.stub(:cookies).and_return(double(:[] => true))
    call(middleware, "/")
  end
end