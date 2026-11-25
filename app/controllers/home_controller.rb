class HomeController < ApplicationController
  def index
    @latest_inventories = Inventory.includes(:creator).order(created_at: :desc).limit(5)
    @popular_inventories = Inventory.includes(:creator).order(items_count: :desc, title: :asc).limit(5)
    @tags = ActsAsTaggableOn::Tag.where("taggings_count > 0").order(taggings_count: :desc).limit(30).to_a
    @max_tag_count = @tags.map(&:taggings_count).max.to_i
  end
end
