class SyncController < ApplicationController
  def create
    result = CoolifySyncService.sync_all

    render json: result, status: result[:success] ? :ok : :unprocessable_entity
  end
end

