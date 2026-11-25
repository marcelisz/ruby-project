class ItemsController < ApplicationController
  include InventoryScoped

  before_action :authenticate_user!, only: %i[new create update bulk_destroy]
  before_action :load_inventory
  before_action :require_inventory_writer!, only: %i[new create update bulk_destroy]
  before_action :load_item, only: %i[show update]

  def new
    @item = @inventory.items.new
    load_fields
  end

  def create
    @item = @inventory.items.new(item_params.merge(created_by: current_user))
    if @item.save
      redirect_to inventory_item_path(@inventory, @item), notice: t("flash.item_created")
    else
      load_fields
      render :new, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    @item.errors.add(:custom_id, :taken)
    load_fields
    render :new, status: :unprocessable_content
  end

  def show
    @can_write = @inventory.writable_by?(current_user)
    @editing = params[:edit].present? && @can_write
    @liked = current_user ? Like.exists?(user_id: current_user.id, item_id: @item.id) : false
    load_fields
  end

  def update
    @editing = true
    @can_write = true
    @liked = Like.exists?(user_id: current_user.id, item_id: @item.id)
    @item.assign_attributes(item_params)
    if @item.save
      redirect_to inventory_item_path(@inventory, @item), notice: t("flash.item_updated")
    else
      load_fields
      render :show, status: :unprocessable_content
    end
  rescue ActiveRecord::StaleObjectError
    flash.now[:alert] = t("flash.conflict")
    load_fields
    render :show, status: :conflict
  rescue ActiveRecord::RecordNotUnique
    @item.errors.add(:custom_id, :taken)
    load_fields
    render :show, status: :unprocessable_content
  end

  def bulk_destroy
    selected_ids = Array(params[:item_ids]).filter_map { |id| Integer(id, exception: false) }
    ids = @inventory.items.where(id: selected_ids).pluck(:id)
    if ids.empty?
      redirect_to inventory_path(@inventory), alert: t("flash.no_items_selected")
      return
    end

    Item.transaction do
      SearchDocument.where(searchable_type: "Item", searchable_id: ids).delete_all
      @inventory.items.where(id: ids).delete_all
      @inventory.update_column(:items_count, @inventory.items.count)
    end
    redirect_to inventory_path(@inventory), notice: t("flash.items_deleted", count: ids.size)
  end

  private

  def load_item
    @item = @inventory.items.find(params[:id])
  end

  def load_fields
    @fields = @inventory.inventory_fields.to_a
  end

  def item_params
    params.require(:item).permit(:custom_id, :lock_version, field_values: {})
  end
end
