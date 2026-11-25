class InventoriesController < ApplicationController
  SORTS = {
    "title" => "inventories.title", "category" => "categories.name",
    "creator" => "users.name", "items_count" => "inventories.items_count",
    "created_at" => "inventories.created_at"
  }.freeze
  ITEM_SORTS = %w[custom_id likes_count].freeze
  XLSX_MIME = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

  before_action :authenticate_user!, only: %i[new create]
  before_action :load_inventory, only: %i[show edit update destroy stats export export_csv export_xlsx]
  before_action :require_inventory_manager!,
                only: %i[edit update destroy stats export export_csv export_xlsx]

  def index
    @sort = SORTS.key?(params[:sort]) ? params[:sort] : nil
    @direction = params[:dir] == "desc" ? "desc" : "asc"
    @inventory_count = Inventory.count

    @inventories = Inventory.includes(:creator, :category).left_joins(:category, :creator)
    @inventories = @inventories.order(Arel.sql("#{SORTS[@sort]} #{@direction}")) if @sort
    @inventories = @inventories.order(created_at: :desc, id: :desc)
  end

  def show
    @can_write = @inventory.writable_by?(current_user)
    @fields = @inventory.inventory_fields.to_a
    @table_fields = @fields.select(&:show_in_table)

    @item_sort = item_sort_value
    @item_direction = params[:dir] == "desc" ? "desc" : "asc"
    items = @inventory.items
    items = items.order(Arel.sql("#{item_sort_sql} #{@item_direction}")) if @item_sort
    items = items.order(created_at: :desc, id: :desc)
    @items = items.to_a
  end

  def new
    @inventory = Inventory.new
    load_categories
  end

  def create
    @inventory = current_user.inventories.new(inventory_params)
    if @inventory.save
      redirect_to inventory_path(@inventory), notice: t("flash.inventory_created")
    else
      load_categories
      render :new, status: :unprocessable_content
    end
  end

  def edit
    load_categories
  end

  def update
    load_categories
    @inventory.assign_attributes(inventory_params)

    respond_to do |format|
      if @inventory.save
        format.html { redirect_to edit_inventory_path(@inventory), notice: t("flash.inventory_updated") }
        format.json { render json: { lock_version: @inventory.lock_version } }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: { errors: @inventory.errors.full_messages }, status: :unprocessable_content }
      end
    end
  rescue ActiveRecord::StaleObjectError
    respond_to do |format|
      format.html do
        flash.now[:alert] = t("flash.conflict")
        render :edit, status: :conflict
      end
      format.json { render json: { error: t("flash.conflict") }, status: :conflict }
    end
  end

  def destroy
    @inventory.destroy!
    redirect_to inventories_path, notice: t("flash.inventory_deleted")
  end

  def stats
    @item_data = @inventory.items.pluck(:field_values, :likes_count)
    @total_likes = @item_data.sum { |_, likes_count| likes_count }
    value_presenter = FieldValuePresenter.new
    field_values = @item_data.map(&:first)
    @statistics = value_presenter.statistics(@inventory.inventory_fields.to_a, field_values)
  end

  def export
  end

  def export_csv
    exporter = InventoryExporter.new(@inventory)
    send_data "\uFEFF#{exporter.csv}",
              filename: exporter.filename("csv"),
              type: "text/csv; charset=utf-8",
              disposition: "attachment"
  end

  def export_xlsx
    exporter = InventoryExporter.new(@inventory)
    send_data exporter.xlsx,
              filename: exporter.filename("xlsx"),
              type: XLSX_MIME,
              disposition: "attachment"
  end

  private

  def load_inventory
    @inventory = Inventory.includes(:creator, :category).find(params[:id])
  end

  def load_categories
    @categories = Category.order(:name)
  end

  def inventory_params
    params.require(:inventory).permit(
      :title, :description, :category_id, :image_url, :lock_version,
      tag_list: []
    )
  end

  def item_sort_value
    sort = params[:sort].to_s
    return sort if ITEM_SORTS.include?(sort)
    return sort if sort.match?(/\Afield_\d+\z/) && @table_fields.any? { |field| sort == "field_#{field.id}" }

    nil
  end

  def item_sort_sql
    case @item_sort
    when "custom_id" then "items.custom_id"
    when "likes_count" then "items.likes_count"
    else
      field = @table_fields.find { |candidate| @item_sort == "field_#{candidate.id}" }
      extracted = "JSON_UNQUOTE(JSON_EXTRACT(items.field_values, '$.\"#{field.id}\"'))"
      case field.field_type
      when "number" then "CAST(#{extracted} AS DECIMAL(30,10))"
      when "boolean" then "CASE WHEN #{extracted} = 'true' THEN 1 ELSE 0 END"
      else extracted
      end
    end
  end
end
