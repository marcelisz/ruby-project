require "csv"
require "caxlsx"

class InventoryExporter
  def initialize(inventory)
    @inventory = inventory
    @fields = inventory.inventory_fields.order(:position, :id).to_a
    @value_presenter = FieldValuePresenter.new
  end

  def headers
    [
      I18n.t("export.headers.custom_id"),
      *@fields.map(&:title),
      I18n.t("export.headers.created_by"),
      I18n.t("export.headers.created_at"),
      I18n.t("export.headers.likes")
    ]
  end

  def rows
    @inventory.items.includes(:created_by).order(:created_at, :id).map do |item|
      [
        item.custom_id,
        *@fields.map { |field| @value_presenter.export(field, item.value_for(field)) },
        item.created_by&.name.presence || I18n.t("common.deleted_user"),
        I18n.l(item.created_at, format: :short),
        item.likes_count
      ]
    end
  end

  def csv
    CSV.generate do |output|
      output << headers
      rows.each { |row| output << row }
    end
  end

  def xlsx
    package = Axlsx::Package.new
    workbook = package.workbook
    header_style = workbook.styles.add_style(
      b: true, bg_color: "E9ECEF", alignment: { wrap_text: true }
    )

    workbook.add_worksheet(name: I18n.t("export.sheet_name")) do |sheet|
      sheet.add_row(headers, style: header_style)
      rows.each { |row| sheet.add_row(row) }
      sheet.column_widths(22, *Array.new(@fields.length, 24), 22, 20, 10)
    end

    package.to_stream.read
  end

  def filename(extension)
    title = @inventory.title.to_s.parameterize.presence || "inventory"
    "#{title}-#{@inventory.id}-#{Time.zone.today.iso8601}.#{extension}"
  end
end
