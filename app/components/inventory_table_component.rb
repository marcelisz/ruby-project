class InventoryTableComponent < ViewComponent::Base
  def initialize(user:, inventories:, title:, sort_prefix:, params:, query:, empty_text:,
                 show_creator:, manage_actions: false, add_inventory: false, section_class: "card")
    @user = user
    @inventories = inventories
    @title = title
    @sort_prefix = sort_prefix
    @params = params
    @query = query
    @empty_text = empty_text
    @show_creator = show_creator
    @manage_actions = manage_actions
    @add_inventory = add_inventory
    @section_class = section_class
  end

  attr_reader :user, :inventories, :title, :query, :empty_text

  def sort_param
    :"#{@sort_prefix}_sort"
  end

  def direction_param
    :"#{@sort_prefix}_dir"
  end

  def query_param
    :"#{@sort_prefix}_q"
  end

  def current_sort
    @params[sort_param]
  end

  def current_direction
    @params[direction_param]
  end

  def show_creator?
    @show_creator
  end

  def manage_actions?
    @manage_actions
  end

  def add_inventory?
    @add_inventory
  end

  def header_class
    add_inventory? ? "card-header d-flex flex-wrap justify-content-between align-items-center gap-3" : "card-header"
  end

  def section_class
    @section_class
  end
end
