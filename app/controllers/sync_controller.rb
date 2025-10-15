class SyncController < ApplicationController
  def create
    # Enqueue the sync job in the background
    CoolifySyncJob.perform_later

    render json: { 
      success: true, 
      message: "Sync job queued successfully. Check the logs or job dashboard for progress." 
    }, status: :accepted
  end
end

