class InvitationsController < ApplicationController
  allow_unauthenticated only: %i[ show accept ]

  before_action :require_admin, only: %i[ index new create destroy resend ]
  before_action :set_invitation, only: %i[ destroy resend ]
  before_action :set_claimable_invitation, only: %i[ show accept ]

  def index
    @invitations = Invitation.visible.order(created_at: :desc)
    @invitation = Invitation.new(role: "translator")
  end

  def new
    @invitation = Invitation.new(role: "translator")
  end

  def create
    @invitation = Invitation.new(invitation_params.merge(inviter: current_user))

    # Any unaccepted invite (pending OR expired) holds the partial unique index
    # `index_invitations_on_email ... WHERE accepted_at IS NULL`. Re-inviting it
    # resends and refreshes the expiry instead of crashing on a duplicate insert.
    if (existing = Invitation.unaccepted.find_by(email: @invitation.email))
      existing.resend!
      InvitationMailer.with(invitation: existing).invite.deliver_later
      redirect_to invitations_path, notice: "Invitation re-sent to #{existing.email}." and return
    end

    if @invitation.save
      InvitationMailer.with(invitation: @invitation).invite.deliver_later
      redirect_to invitations_path, notice: "Invitation sent to #{@invitation.email}."
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    # Race: a pending invite for this email was created between the check and save.
    @invitation.errors.add(:email, "already has a pending invitation")
    render :new, status: :unprocessable_entity
  end

  def destroy
    @invitation.destroy!
    redirect_to invitations_path, notice: "Invitation revoked."
  end

  def resend
    if @invitation.accepted?
      redirect_to invitations_path, alert: "That invitation was already accepted."
    else
      @invitation.resend!
      InvitationMailer.with(invitation: @invitation).invite.deliver_later
      redirect_to invitations_path, notice: "Invitation re-sent to #{@invitation.email}."
    end
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
