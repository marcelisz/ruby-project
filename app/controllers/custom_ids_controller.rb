class CustomIdsController < ApplicationController
  include InventoryScoped

  before_action :authenticate_user!
  before_action :load_inventory
  before_action :require_inventory_manager!

  def show
    @next_sequence = @inventory.next_custom_sequence
  end

  def update
    elements = JSON.parse(params.dig(:inventory, :custom_id_format).to_s)
    @inventory.assign_attributes(
      custom_id_format: elements,
      lock_version: params.dig(:inventory, :lock_version)
    )
    if @inventory.save
      redirect_to custom_id_inventory_path(@inventory), notice: t("flash.custom_id_updated")
    else
      @next_sequence = @inventory.next_custom_sequence
      render :show, status: :unprocessable_content
    end
  rescue JSON::ParserError, TypeError
    @inventory.errors.add(:custom_id_format, :invalid)
    @next_sequence = @inventory.next_custom_sequence
    render :show, status: :unprocessable_content
  rescue ActiveRecord::StaleObjectError
    flash.now[:alert] = t("flash.conflict")
    @next_sequence = @inventory.next_custom_sequence
    render :show, status: :conflict
  end
end
