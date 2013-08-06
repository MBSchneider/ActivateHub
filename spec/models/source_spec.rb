require 'spec_helper'

describe Source, "in general" do
  subject(:source) { Factory.build(:source) }

  before(:each) do
    @event = mock_model(Event,
      :title => "Title",
      :description => "Description",
      :url => "http://my.url/",
      :start_time => Time.now + 1.day,
      :end_time => nil,
      :venue => nil,
      :duplicate_of_id => nil)
  end

  it { should be_valid }

  it "should create events for source from URL" do
    @event.should_receive(:save!)

    source = build(:source, :url => "http://my.url/")
    source.should_receive(:to_events).and_return([@event])
    source.create_events!.should eq [@event]
  end

  it "should fail to create events for invalid sources" do
    source = Source.new(:url => '\not valid/')
    lambda{ source.to_events }.should raise_error(ActiveRecord::RecordInvalid, /Url has invalid format/i)
  end

  context "scopes" do
    it ":enabled should return only enabled sources" do
      create_list(:source, 2, :enabled => true)
      create_list(:source, 3, :enabled => false)
      Source.enabled.count.should eq 2
    end

    it ":disabled should return only disabled sources" do
      create_list(:source, 2, :enabled => true)
      create_list(:source, 3, :enabled => false)
      Source.disabled.count.should eq 3
    end
  end

  describe "#enabled" do
    it "should be enabled by default" do
      Source.new.enabled.should be_true
    end
  end
end

describe Source, "when associated with an organization" do
  before(:each) do

    @topics =  [Topic.new(:name => 'fun'), Topic.new(:name => 'loving')]
    @types = [Type.new(:name => 'random'), Type.new(:name => 'tests')]

    @organization = mock_model(Organization,
      :name => "Test Org Title",
      :topics => @topics)

    @event = mock_model(Event,
      :title => "Title",
      :description => "Description",
      :url => "http://my.url/",
      :start_time => Time.now + 1.day,
      :end_time => nil,
      :venue => nil,
      :duplicate_of_id => nil,
      :save! => true
      )
      #)
  end

 it "should set types, topics, & organization on imported events (within create_events)" do

  # Setup a source with some topics
  source = build(:source, :url => "http://my.url/", :organization => @organization, :types => @types, :topics => @topics)

  # stub to_events to return mocked event
  source.should_receive(:to_events).and_return([@event])

  # setup expectations that the output event has types, topics, and organization set
  output_event = @event.dup
  output_event.should_receive(:types=).with(@types)
  output_event.should_receive(:topics=).with(@topics)
  output_event.should_receive(:organization=).with(@organization)

  # Go! (Run the code and verify the above expectations)
  source.create_events!.should == [output_event]
  end
end

describe Source, "when reading name" do
  before(:each) do
    @title = "title"
    @url = "http://my.url/"
  end

  before(:each) do
    @source = Source.new
  end

  it "should return nil if no title is available" do
    @source.name.should be_nil
  end

  it "should use title if available" do
    @source.title = @title
    @source.name.should eq @title
  end

  it "should use URL if available" do
    @source.url = @url
    @source.name.should eq @url
  end

  it "should prefer to use title over URL if both are available" do
    @source.title = @title
    @source.url = @url

    @source.name.should eq @title
  end
end

describe Source, "when parsing URLs" do
  before(:each) do
    @http_url = 'http://upcoming.yahoo.com/event/390164/'
    @ical_url = 'webcal://upcoming.yahoo.com/event/390164/'
    @base_url = 'upcoming.yahoo.com/event/390164/'
  end

  before(:each) do
    @source = Source.new
  end

  it "should not modify supported url schemes" do
    @source.url = @http_url

    @source.url.should eq @http_url
  end

  it "should substitute http for unsupported url schemes" do
    @source.url = @ical_url

    @source.url.should eq @http_url
  end

  it "should add the http prefix to urls without one" do
    @source.url = @base_url

    @source.url.should eq @http_url
  end

  it "should strip leading and trailing whitespace from URL" do
    source = Source.new
    source.url = "     #{@http_url}     "
    source.url.should eq @http_url
  end

  it "should be invalid if given invalid URL" do
    source = Source.new
    source.url = '\O.o/'
    source.url.should be_nil
    source.should_not be_valid
  end
end

describe Source, "find_or_create_from" do
  before do
    @url = "http://foo.bar"
  end

  it "should return new, unsaved record if given no arguments" do
    source = Source.find_or_create_from()

    source.should be_a_new_record
  end

  it "should return an existing or newly-created record" do
    record = Source.new(:url => @url)
    Source.should_receive(:find_or_create_by_url).and_return(record)

    result = Source.find_or_create_from(:url => @url)
    record.should eq result
  end

  it "should set re-import flag if given" do
    record = Source.new(:url => @url)
    record.should_receive(:save)
    Source.should_receive(:find_or_create_by_url).and_return(record)

    result = Source.find_or_create_from(:url => @url, :reimport => true)
    result.reimport.should be_true
  end
end
