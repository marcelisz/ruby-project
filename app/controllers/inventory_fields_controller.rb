class InventoryFieldsController < ApplicationController
  include InventoryScoped

  before_action :authenticate_user!
  before_action :load_inventory
  before_action :require_inventory_manager!

  def index
    @new_field = InventoryField.new
    load_fields
  end

  def update_all
    result = InventoryFieldsBatchUpdate.new(@inventory, params[:inventory_fields]).call
    return redirect_to inventory_fields_path(@inventory), notice: t("flash.fields_updated") if result.success?

    @field = result.invalid_field
    @new_field = InventoryField.new
    load_fields
    render :index, status: :unprocessable_content
  end

  private

  def load_fields
    @fields = @inventory.inventory_fields.order(:position).to_a
  end
end
