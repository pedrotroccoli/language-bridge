class InvitationsController < ApplicationController
  allow_unauthenticated only: %i[ show accept ]

  before_action :require_admin, only: %i[ index new create destroy ]
  before_action :set_invitation, only: %i[ destroy ]
  before_action :set_claimable_invitation, only: %i[ show accept ]

  def index
    @invitations = Invitation.pending.order(created_at: :desc)
  end

  def new
    @invitation = Invitation.new(role: "translator")
  end

  def create
    @invitation = Invitation.new(invitation_params.merge(inviter: current_user))

    if @invitation.save
      InvitationMailer.with(invitation: @invitation).invite.deliver_later
      redirect_to invitations_path, notice: "Invitation sent to #{@invitation.email}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @invitation.destroy!
    redirect_to invitations_path, notice: "Invitation revoked."
  end

  def show
  end

  def accept
    user = @invitation.accept!
    sign_in_as(user)
    redirect_to root_path, notice: "Welcome, #{user.email}!"
  end

  private
    def invitation_params
      params.expect(invitation: %i[email role])
    end

    def set_invitation
      @invitation = Invitation.find(params[:id])
    end

    def set_claimable_invitation
      @invitation = Invitation.find_by(token: params[:token])
      redirect_to(sign_in_path, alert: "Invitation invalid or expired.") and return unless @invitation&.claimable?
    end
end
