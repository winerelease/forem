class ChatChannelMembershipsController < ApplicationController
  after_action :verify_authorized

  def find_by_chat_channel_id
    @membership = ChatChannelMembership.where(chat_channel_id: params[:chat_channel_id], user_id: current_user.id).first!
    authorize @membership
    render json: @membership.to_json(
      only: %i[id status viewable_by chat_channel_id last_opened_at],
      methods: %i[channel_text channel_last_message_at channel_status channel_username
                  channel_type channel_text channel_name channel_image channel_modified_slug channel_messages_count],
    )
  end

  def edit
    @membership = ChatChannelMembership.find(params[:id])
    @channel = @membership.chat_channel
    authorize @membership
  end

  def create
    membership_params = params[:chat_channel_membership]
    @chat_channel = ChatChannel.find(membership_params[:chat_channel_id])
    authorize @chat_channel, :update?
    membership_params[:invitation_usernames].split(",").each do |username_str|
      ChatChannelMembership.create!(
        user_id: User.find_by(username: username_str.delete(" ").delete("@")).id,
        chat_channel_id: @chat_channel.id,
        status: "pending",
      )
    end
    redirect_to "/chat_channel_memberships/#{@chat_channel.chat_channel_memberships.where(user_id: current_user).first&.id}/edit"
  end

  def remove_invitation
    @chat_channel = ChatChannel.find(params[:chat_channel_id])
    authorize @chat_channel, :update?
    ChatChannelMembership.where(chat_channel_id: @chat_channel.id, id: params[:invitation_id], status: "pending").first&.destroy
    redirect_to "/chat_channel_memberships/#{@chat_channel.chat_channel_memberships.where(user_id: current_user).first&.id}/edit"
  end

  def update
    @chat_channel_membership = ChatChannelMembership.find(params[:id])
    authorize @chat_channel_membership
    @chat_channel_membership.update(permitted_params)
    redirect_to "/chat_channel_memberships/#{@chat_channel_membership.id}/edit"
  end

  def invite
    @chat_channel_membership = ChatChannelMembership.find(params[:id])
    authorize @chat_channel_membership
    if permitted_params[:user_action] == "accept"
      @chat_channel_membership.update(status: "active")
      @chat_channel_membership.index!
    else
      @chat_channel_membership.update(status: "rejected")
    end
    @chat_channels_memberships = current_user.
      chat_channel_memberships.includes(:chat_channel).
      where(status: "pending").
      order("chat_channel_memberships.updated_at DESC")
    render "chat_channels/index.json"
  end

  def destroy
    @chat_channel_membership = ChatChannel.find(params[:id]).
      chat_channel_memberships.where(user_id: current_user.id).first
    authorize @chat_channel_membership
    @chat_channel_membership.update(status: "left_channel")
    @chat_channel_membership.remove_from_index!
    @chat_channels_memberships = []
    render json: { result: "left channel" }, status: :created
  end

  def permitted_params
    params.require(:chat_channel_membership).permit(:user_action, :show_global_badge_notification)
  end
end
