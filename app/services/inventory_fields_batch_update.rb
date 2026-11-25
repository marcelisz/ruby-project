class InventoryFieldsBatchUpdate
  PERMITTED_ATTRIBUTES = %i[
    id _destroy title description field_type show_in_table
    min_length max_length min_value max_value regex_pattern
  ].freeze

  Result = Struct.new(:invalid_field, keyword_init: true) do
    def success?
      invalid_field.nil?
    end
  end

  def initialize(inventory, raw_entries)
    @inventory = inventory
    @raw_entries = raw_entries
  end

  def call
    invalid_field = nil
    refreshed = false
    ordered_ids = []

    InventoryField.transaction do
      destroyed, persisted = entries.partition { |entry| entry[:_destroy].to_s == "1" }

      destroyed.each do |entry|
        field = @inventory.inventory_fields.find_by(id: entry[:id])
        next unless field

        field.destroy!
        refreshed = true
      end

      persisted.each do |entry|
        attrs = entry.permit(*PERMITTED_ATTRIBUTES)
        field = if attrs[:id].present?
                  @inventory.inventory_fields.find(attrs[:id])
                else
                  @inventory.inventory_fields.new
                end
        field.assign_attributes(attrs.except(:id, :_destroy))

        unless field.save
          invalid_field = field
          raise ActiveRecord::Rollback
        end
        ordered_ids << field.id
      end

      InventoryField.reorder!(@inventory, ordered_ids) if ordered_ids.any?
      @inventory.refresh_search_document if refreshed
    end

    Result.new(invalid_field: invalid_field)
  end

  private

  def entries
    @entries ||= begin
      raw = @raw_entries
      raw = raw.values if raw.respond_to?(:values)
      list = Array(raw).select { |entry| entry.respond_to?(:permit) }
      if list.any? { |entry| entry[:position].present? }
        list.sort_by { |entry| entry[:position].to_i }
      else
        list
      end
    end
  end
end
