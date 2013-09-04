require 'spec_helper'
require 'rack/test'
require 'rack/motivoo'

describe "Rack middleware" do
  let!(:tracker) do
    tracker = double("tracker").as_null_object
    Motivoo::Context.stub(:create!).and_yield(tracker, request)
    Motivoo::Context.stub(:create).and_yield(tracker, request)
    tracker
  end
  
  let(:app_response) { [200, { 'Content-Type' => 'text/plain' }, ['<body>hello</body>']] }
  let(:app) { lambda { |env| app_response } }
  let(:middleware) { Rack::Motivoo.new(app) }

  let!(:response) do 
    response = double("response").as_null_object 
    Rack::Response.stub(:new).and_return(response)
    response
  end
  
  let!(:request) do 
    request = double("request").as_null_object
    request.stub(:cookies).and_return({})
    Rack::Request.stub(:new).and_return(request)
    request
  end
  
  def call(middleware, path, opts = {}) 
    middleware.call(Rack::MockRequest.env_for(path, opts))
  end
  
  it "should force-create context" do
    Motivoo::Context.should_receive(:create!).and_yield(tracker, request)
    call(middleware, "/")
  end
    
  it "should track visit" do
    Motivoo::Visit.should_receive(:track).with(tracker, request).and_yield(tracker, request)
    call(middleware, "/")
  end
  
  context "with anti-bot protection enabled" do
    let(:middleware) do
      Motivoo.configure do |config|
        config.bot_protect_js = true
      end
      Rack::Motivoo.new(app) 
     end
     
    it "should conditionally create context" do
      Motivoo::Context.should_receive(:create).and_yield(tracker, request)
      call(middleware, "/")
    end
    
    it "should force-create context for POST /motivoo/" do
      Motivoo::Context.should_receive(:create!).and_yield(tracker, request)
      call(middleware, "/motivoo/", method: :post)
    end
    
    it "should insert JS doing POST to /motivoo/ before the closing BODY tag" do
      *_, body = call(middleware, "/")
      body.should include("<script>")
    end
  end
end