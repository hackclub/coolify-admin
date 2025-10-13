class CoolifyTeamsController < ApplicationController
  def new
    @coolify_team = CoolifyTeam.new
  end

  def create
    @coolify_team = CoolifyTeam.new(coolify_team_params)

    if @coolify_team.save
      redirect_to root_path, notice: "Team '#{@coolify_team.name}' was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @coolify_team = CoolifyTeam.find(params[:id])
    team_name = @coolify_team.name
    @coolify_team.destroy
    redirect_to root_path, notice: "Team '#{team_name}' was successfully deleted."
  end

  private

  def coolify_team_params
    params.require(:coolify_team).permit(:name, :base_url, :token, :verify_tls, :api_path_prefix)
  end
end

