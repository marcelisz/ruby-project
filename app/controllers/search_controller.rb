class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.squish
    return redirect_to(root_path) if @query.blank?

    @documents = SearchDocument.full_text(@query)
    grouped = @documents.group_by(&:searchable_type)
    @inventories = grouped.fetch("Inventory", []).map(&:searchable)
    @items = grouped.fetch("Item", [])
    @users = grouped.fetch("User", [])
    @item_contexts = Inventory.where(id: @items.map { |document| document.searchable.inventory_id })
                              .pluck(:id, :title).to_h
    ActiveRecord::Associations::Preloader.new(
      records: @inventories, associations: %i[creator category]
    ).call
  end
end
