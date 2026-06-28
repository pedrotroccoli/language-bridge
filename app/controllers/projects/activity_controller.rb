class Projects::ActivityController < ApplicationController
  include ProjectScoped

  def show
    @events = @project.recent_events
  end
end
