require 'source_parser'

class SourcesController < ApplicationController
  MAXIMUM_EVENTS_TO_DISPLAY_IN_FLASH = 5

  # Import sources
  def import
    params[:source][:type_ids] = create_missing_refs(params[:source][:type_ids], Type)

    @source = Source.find_or_create_from(params[:source])
    @source.organization = Organization.find(params[:organization_id])

    if @source.save
      begin
        SourceImporter.new(@source).import!
      rescue SourceParser::NotFound => e
        @source.errors.add(:base, "No events found at remote site. Is the event identifier in the URL correct?")
      rescue SourceParser::HttpAuthenticationRequiredError => e
        @source.errors.add(:base, "Couldn't import events, remote site requires authentication.")
      rescue OpenURI::HTTPError => e
        @source.errors.add(:base, "Couldn't download events, remote site may be experiencing connectivity problems. ")
      rescue Errno::EHOSTUNREACH => e
        @source.errors.add(:base, "Couldn't connect to remote site.")
      rescue SocketError => e
        @source.errors.add(:base, "Couldn't find IP address for remote site. Is the URL correct?")
      rescue Exception => e
        @source.errors.add(:base, "Unknown error: #{e}")
      end
    end

    @events = @source.events

    respond_to do |format|
      if @source.errors.any?
        flash[:failure] = "Unable to import: #{@source.errors.full_messages.to_sentence}"
        format.html { render :action => "new" }
        format.xml  { render :xml => @source.errors, :status => :unprocessable_entity }

      elsif @events.none?
        flash[:failure] = "Unable to find any upcoming events to import from this source"
        format.html { redirect_to(events_path) }
        format.xml  { render :xml => @source, :events => @events }

      else
        s = "<p>Imported #{@events.size} entries:</p><ul>"
        @events.each_with_index do |event, i|
          if i >= MAXIMUM_EVENTS_TO_DISPLAY_IN_FLASH
            s << "<li>And #{@events.size - i} other events.</li>"
            break
          else
            s << "<li>#{help.link_to(event.title, event_url(event))}</li>"
          end
        end
        s << "</ul>"
        flash[:success] = s

        format.html { redirect_to(events_path) }
        format.xml  { render :xml => @source, :events => @events }
      end
    end
  end

  # GET /sources
  # GET /sources.xml
  def index
    @sources = Source.where('organization_id' => params[:organization_id])

    respond_to do |format|
      format.html { @sources = @sources.page(params[:page]).per(params[:per_page]) }
      format.xml  { render :xml => @sources }
    end
  end

  # GET /sources/1
  # GET /sources/1.xml
  def show
    organization_id = params[:organization_id]

    begin
      @source = Source.find(params[:id], :include => [:events, :venues])
    rescue ActiveRecord::RecordNotFound => e
      flash[:failure] = e.to_s if params[:id] != "import"
      return redirect_to(new_organization_source_path(:organization_id => organization_id))
    end

    @future_events = @source.events.future.non_duplicates.reorder('start_time asc').limit(10)
    @past_events = @source.events.past.non_duplicates.reorder('start_time desc').limit(10)

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @source }
    end
  end

  # GET /sources/new
  # GET /sources/new.xml
  def new
    @organization = Organization.find(params[:organization_id])
    @source = @organization.sources.build

    @source.url = params[:url] if params[:url].present?
    @source.topics = @organization.topics

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @source }
    end
  end

  # GET /sources/1/edit
  def edit
    @source = Source.find(params[:id])
    @organization = Organization.find(params[:organization_id])
  end

  # POST /sources
  # POST /sources.xml
  def create
    params[:source][:topic_ids] = create_missing_refs(params[:source][:topic_ids], Topic)
    params[:source][:type_ids] = create_missing_refs(params[:source][:type_ids], Type)

    @source = Source.new(params[:source])

    respond_to do |format|
      if @source.save
        flash[:notice] = 'Source was successfully created.'
        format.html { redirect_to( organization_source_path(:organization_id => @source.organization_id, :id => @source.id) ) }
        format.xml  { render :xml => @source, :status => :created, :location => @source }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @source.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /sources/1
  # PUT /sources/1.xml
  def update
    params[:source][:type_ids] = create_missing_refs(params[:source][:type_ids], Type)

    @source = Source.find(params[:id])

    respond_to do |format|
      if @source.update_attributes(params[:source])
        flash[:notice] = 'Source was successfully updated.'
        format.html { redirect_to( source_path(@source) ) }
        format.xml  { head :ok }
      else
        flash[:error] = 'Source edit didn\'t validate.'
        format.html { render :action => "edit" }
        format.xml  { render :xml => @source.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /sources/1
  # DELETE /sources/1.xml
  def destroy
    @source = Source.find(params[:id])
    @source.destroy

    respond_to do |format|
      format.html { redirect_to(organization_sources_url) }
      format.xml  { head :ok }
    end
  end

  def source_path(source)
    return self.organization_source_path source.organization, source
  end
end
