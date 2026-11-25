class Item < ApplicationRecord
  include Searchable

  belongs_to :inventory, counter_cache: true
  belongs_to :created_by, class_name: "User", optional: true
  has_many :likes, dependent: :destroy

  before_validation :assign_custom_id, on: :create
  before_validation :normalize_field_values
  after_initialize { self.field_values ||= {} }
  validates :custom_id, presence: true, length: { maximum: 255 },
                        uniqueness: { scope: :inventory_id }
  validate :custom_id_matches_format
  validate :validate_field_values_against_tuning

  def self.normalize_number(value)
    BigDecimal(value.to_s).to_s("F").sub(/\.0+\z/, "")
  rescue ArgumentError, TypeError
    value.to_s
  end

  def value_for(field)
    field_values[field.id.to_s]
  end

  private

  def search_document_attributes
    {
      title: custom_id,
      body: inventory.inventory_fields.filter_map { |field| value_for(field) }.join(" "),
      subtitle: nil
    }
  end

  def assign_custom_id
    formatter = inventory.custom_id_formatter
    if formatter.elements.any? { |element| element["type"] == "sequence" }
      self.custom_sequence = inventory.next_custom_sequence
    end
    self.custom_id = formatter.generate(sequence: custom_sequence) if custom_id.blank?
  end

  def normalize_field_values
    source = field_values.respond_to?(:to_h) ? field_values.to_h.stringify_keys : {}
    normalized = {}

    inventory.inventory_fields.each do |field|
      key = field.id.to_s
      next unless source.key?(key)

      value = source[key]
      case field.field_type
      when "number"
        next if value.blank?

        number = BigDecimal(value.to_s)
        normalized[key] = self.class.normalize_number(number)
      when "boolean"
        normalized[key] = ActiveModel::Type::Boolean.new.cast(value) || false
      else
        normalized[key] = value.to_s
      end
    rescue ArgumentError
      errors.add(:field_values, :invalid_number, field: field.title)
      normalized[key] = value.to_s
    end

    self.field_values = normalized
  end

  def custom_id_matches_format
    formatter = inventory.custom_id_formatter
    unless formatter.valid?
      errors.add(:custom_id, :inventory_format_invalid)
      return
    end

    errors.add(:custom_id, :invalid_format) unless formatter.regexp.match?(custom_id.to_s)
  end

  def validate_field_values_against_tuning
    inventory.inventory_fields.each do |field|
      value = value_for(field)
      next if value.nil? || value.to_s.empty?

      if field.text_field?
        validate_text_value(field, value.to_s)
      elsif field.number_field?
        validate_number_value(field, value.to_s)
      end
    end
  end

  def validate_text_value(field, value)
    length = value.length
    if field.min_length && length < field.min_length
      errors.add(:field_values, :too_short, field: field.title, limit: field.min_length)
    end
    if field.max_length && length > field.max_length
      errors.add(:field_values, :too_long, field: field.title, limit: field.max_length)
    end
    return if field.regex_pattern.blank?

    unless Regexp.new(field.regex_pattern).match?(value)
      errors.add(:field_values, :invalid_text_format, field: field.title)
    end
  rescue RegexpError
    nil
  end

  def validate_number_value(field, value)
    number = BigDecimal(value)
    digit_count = value.delete("+-.").length
    if field.min_length && digit_count < field.min_length
      errors.add(:field_values, :too_few_digits, field: field.title, limit: field.min_length)
    end
    if field.max_length && digit_count > field.max_length
      errors.add(:field_values, :too_many_digits, field: field.title, limit: field.max_length)
    end
    if field.min_value && number < field.min_value
      errors.add(:field_values, :below_minimum, field: field.title,
                 limit: self.class.normalize_number(field.min_value))
    end
    if field.max_value && number > field.max_value
      errors.add(:field_values, :above_maximum, field: field.title,
                 limit: self.class.normalize_number(field.max_value))
    end
  rescue ArgumentError
    nil
  end
end
