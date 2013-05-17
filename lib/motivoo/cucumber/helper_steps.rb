require 'motivoo/report'

Given(/^cohort category "(.*?)" with just one cohort "(.*?)"$/) do |category, cohort|
  Motivoo.configure do |config|
    config.define_cohort(category) { cohort }
  end
  @test_cohort_categories << category
end

Then(/^there should be exactly (\d+) ([\w]+) event "(.*?)" in "(.*?)" cohort of "(.*?)" category$/) do |num_events, event_type, event_name, cohort, cohort_category|
  report = Motivoo::Report.new(Motivoo::Connection.instance)
  report.send("#{event_type}s_by".to_sym, cohort_category, event_name.to_sym)[cohort].should == num_events.to_i
end