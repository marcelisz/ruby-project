class InventoryAccessesController < ApplicationController
  include InventoryScoped

  before_action :authenticate_user!
  before_action :load_inventory
  before_action :require_inventory_manager!

  def index
    @sort = params[:sort] == "email" ? "email" : "name"
    @accesses = @inventory.inventory_accesses.includes(:user).joins(:user)
                         .order("users.#{@sort} ASC")
  end

  def update
    @inventory.assign_attributes(access_params)
    if @inventory.save
      redirect_to access_inventory_path(@inventory), notice: t("flash.access_updated")
    else
      redirect_to access_inventory_path(@inventory), alert: @inventory.errors.full_messages.to_sentence
    end
  rescue ActiveRecord::StaleObjectError
    redirect_to access_inventory_path(@inventory), alert: t("flash.conflict")
  end

  def create
    user = User.find_by(id: params[:user_id])
    if user.nil?
      redirect_to access_inventory_path(@inventory), alert: t("flash.user_not_found")
      return
    end

    access = @inventory.inventory_accesses.find_or_initialize_by(user: user)
    if access.save
      redirect_to access_inventory_path(@inventory), notice: t("flash.access_added")
    else
      redirect_to access_inventory_path(@inventory), alert: t("flash.already_has_access")
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to access_inventory_path(@inventory), alert: t("flash.already_has_access")
  end

  def destroy
    access = @inventory.inventory_accesses.find_by(user_id: params[:user_id])
    access&.destroy
    redirect_to access_inventory_path(@inventory), notice: t("flash.access_removed")
  end

  private

  def access_params
    params.require(:inventory).permit(:public, :lock_version)
  end
end
