class AutocompleteController < ApplicationController
  include InventoryScoped

  before_action :authenticate_user!
  before_action :load_inventory, only: :users
  before_action :require_inventory_manager!, only: :users

  def tags
    render json: ActsAsTaggableOn::Tag
      .where("name LIKE ?", "#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s)}%")
      .order(:name).limit(10)
      .pluck(:name)
      .map { |name| { value: name, text: name } }
  end

  def users
    pattern = "#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s)}%"
    users = User.where("name LIKE :q OR email LIKE :q", q: pattern).order(:name).limit(10)
    render json: users.map { |user| { value: user.id, text: "#{user.name} (#{user.email})" } }
  end
end
