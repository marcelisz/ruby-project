class LikesController < ApplicationController
  include InventoryScoped

  before_action :authenticate_user!
  before_action :load_inventory

  def create
    item = @inventory.items.find(params[:item_id])
    like = current_user.likes.new(item: item)
    if like.save
      redirect_to inventory_item_path(@inventory, item), notice: t("flash.liked")
    else
      redirect_to inventory_item_path(@inventory, item), alert: t("flash.already_liked")
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to inventory_item_path(@inventory, item), alert: t("flash.already_liked")
  end
end
