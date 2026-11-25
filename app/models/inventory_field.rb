class InventoryField < ApplicationRecord
  TYPES = %w[single_line_text multi_line_text number document image boolean].freeze
  TEXT_TYPES = %w[single_line_text multi_line_text].freeze
  LIMIT = 3

  belongs_to :inventory, inverse_of: :inventory_fields

  before_validation :strip_title
  before_validation :normalize_tuning
  before_validation :set_position, on: :create
  validates :title, presence: true, length: { maximum: 255 }
  validates :field_type, inclusion: { in: TYPES }
  validates :min_length, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                         allow_nil: true
  validates :max_length, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                         allow_nil: true
  validates :min_value, numericality: true, allow_nil: true
  validates :max_value, numericality: true, allow_nil: true
  validates :regex_pattern, length: { maximum: 1000 }, allow_blank: true
  validate :validate_length_bounds
  validate :validate_value_bounds
  validate :validate_regex_pattern
  validate :respect_type_limit

  after_save :refresh_inventory_search

  def text_field?
    TEXT_TYPES.include?(field_type)
  end

  def number_field?
    field_type == "number"
  end

  def self.reorder!(inventory, ordered_ids)
    ids = Array(ordered_ids).filter_map { |id| Integer(id, exception: false) }
    ids &= inventory.inventory_fields.pluck(:id)
    return if ids.empty?

    cases = ids.each_with_index.map { |id, index| "WHEN #{id} THEN #{index}" }.join(" ")
    inventory.inventory_fields.where(id: ids).update_all("position = CASE id #{cases} END")
  end

  private

  def strip_title
    self.title = title.to_s.strip
  end

  def normalize_tuning
    unless text_field? || number_field?
      self.min_length = nil
      self.max_length = nil
    end
    self.regex_pattern = nil unless text_field?
    unless number_field?
      self.min_value = nil
      self.max_value = nil
    end
    self.regex_pattern = nil if regex_pattern.blank?
  end

  def validate_length_bounds
    return if min_length.nil? || max_length.nil? || min_length <= max_length

    errors.add(:max_length, :must_be_greater_than_or_equal_to_min_length)
  end

  def validate_value_bounds
    return if min_value.nil? || max_value.nil? || min_value <= max_value

    errors.add(:max_value, :must_be_greater_than_or_equal_to_min_value)
  end

  def validate_regex_pattern
    return if regex_pattern.blank? || !text_field?
    return if errors[:regex_pattern].any?

    begin
      Regexp.new(regex_pattern)
    rescue RegexpError
      errors.add(:regex_pattern, :invalid)
      return
    end

    self.class.connection.select_value(
      "SELECT REGEXP_LIKE('', #{self.class.connection.quote(regex_pattern)}, 'c')"
    )
  rescue ActiveRecord::StatementInvalid
    errors.add(:regex_pattern, :invalid_database_pattern)
  end

  def set_position
    self.position = inventory.inventory_fields.maximum(:position)&.next || 0
  end

  def respect_type_limit
    return unless TYPES.include?(field_type)

    existing = inventory.inventory_fields.where(field_type: field_type)
    existing = existing.where.not(id: id) if persisted?
    errors.add(:field_type, :limit_reached, limit: LIMIT) if existing.count >= LIMIT
  end

  def refresh_inventory_search
    inventory.refresh_search_document unless inventory.destroyed?
  end
end
