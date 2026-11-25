class MessagesController < ApplicationController
  include InventoryScoped

  before_action :authenticate_user!, only: :create
  before_action :load_inventory

  def index
    @messages = @inventory.messages.includes(:user).chronological
    @last_message_id = @messages.maximum(:id).to_i
  end

  def create
    message = @inventory.messages.new(content: params.dig(:message, :content), user: current_user)
    if message.save
      redirect_to chat_inventory_path(@inventory), notice: t("flash.message_created")
    else
      redirect_to chat_inventory_path(@inventory), alert: message.errors.full_messages.to_sentence
    end
  end

  def feed
    last_id = params[:after].to_i
    new_messages = @inventory.messages.includes(:user).where("id > ?", last_id).chronological.to_a
    html = render_to_string(partial: "messages/posts", formats: [:html], locals: { messages: new_messages })
    response.headers["Cache-Control"] = "no-store"
    render json: { html: html, last_id: new_messages.last&.id || last_id }
  end
end
