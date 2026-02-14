class SavedLinksController < ApplicationController
  def index
    @saved_links = current_user.saved_links.newest_first
  end

  def create
    @saved_link = current_user.saved_links.build(saved_link_params)
    if @saved_link.save
      redirect_to saved_links_path, notice: "Link saved!"
    else
      redirect_to saved_links_path, alert: @saved_link.errors.full_messages.join(", ")
    end
  end

  def process_all
    pending_links = current_user.saved_links.pending
    pending_links.each { |link| ProcessSavedLinkJob.perform_later(link.id) }
    redirect_to saved_links_path, notice: "Processing started for #{pending_links.count} links"
  end

  def destroy
    @saved_link = current_user.saved_links.find(params[:id])
    @saved_link.destroy
    redirect_to saved_links_path, notice: "Link removed."
  end

  private

  def saved_link_params
    params.expect(saved_link: [:url, :note])
  end
end
