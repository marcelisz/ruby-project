class TagsController < ApplicationController
  def show
    @tag = ActsAsTaggableOn::Tag.find(params[:id])
    @inventories = Inventory.tagged_with(@tag.name).includes(:creator, :category)
                             .order(created_at: :desc)
  end
end
