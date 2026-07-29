# Workspace members — the Users with access. Admin-only management: change a
# member's role or remove them. (Single-tenant: every user is a workspace member.)
class MembersController < ApplicationController
  before_action :require_admin

  def index
    @members = User.order(:email)
  end

  def update
    user = User.find(params[:id])
    if user == current_user
      redirect_to members_path, alert: "You can't change your own role."
    elsif user.update(member_params)
      redirect_to members_path, notice: "Updated #{user.email}."
    else
      redirect_to members_path, alert: user.errors.full_messages.to_sentence
    end
  end

  def destroy
    user = User.find(params[:id])
    return redirect_to members_path, alert: "You can't remove yourself." if user == current_user

    user.destroy
    redirect_to members_path, notice: "Removed #{user.email}."
  rescue ActiveRecord::InvalidForeignKey
    redirect_to members_path, alert: "#{user.email} has authored content and can't be removed."
  end

  private
    def member_params
      params.expect(user: %i[ role ])
    end
end
