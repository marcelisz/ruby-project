module InventoryScoped
  extend ActiveSupport::Concern

  private

  def load_inventory
    @inventory = Inventory.find(params[:inventory_id] || params[:id])
  end
end
