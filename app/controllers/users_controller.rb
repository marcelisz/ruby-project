class UsersController < ApplicationController
  OWNED_SORTS = {
    "title" => "inventories.title", "category" => "categories.name",
    "items_count" => "inventories.items_count", "updated_at" => "inventories.updated_at"
  }.freeze
  SHARED_SORTS = OWNED_SORTS.merge("creator" => "users.name").freeze

  def show
    @user = User.find(params[:id])
    @own_profile = current_user == @user
    @owned_inventories = table_scope(@user.inventories, "owned", OWNED_SORTS)
    @shared_inventories = table_scope(@user.shared_inventories, "shared", SHARED_SORTS)
  end

  private

  def table_scope(scope, prefix, sorts)
    scope = scope.includes(:category, :creator).left_joins(:category, :creator)
    filter = params[:"#{prefix}_q"].to_s.strip
    if filter.present?
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(filter)}%"
      scope = scope.where("inventories.title LIKE :q OR inventories.description LIKE :q", q: pattern)
    end

    sort = sorts[params[:"#{prefix}_sort"]]
    direction = params[:"#{prefix}_dir"] == "desc" ? "desc" : "asc"
    scope = scope.order(Arel.sql("#{sort} #{direction}")) if sort
    scope.order(updated_at: :desc)
  end
end
