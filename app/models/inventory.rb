class Inventory < ApplicationRecord
  include Searchable

  acts_as_taggable_on :tags

  belongs_to :creator, class_name: "User", inverse_of: :inventories
  belongs_to :category
  has_many :inventory_fields, -> { order(:position) }, dependent: :destroy, inverse_of: :inventory
  has_many :items, dependent: :destroy
  has_many :inventory_accesses, dependent: :destroy
  has_many :access_users, through: :inventory_accesses, source: :user
  has_many :messages, dependent: :destroy

  after_initialize { self.custom_id_format = CustomIdFormat.default if custom_id_format.blank? }
  before_validation :strip_title
  validates :title, presence: true, length: { maximum: 255 }
  validates :image_url, format: { with: %r{\Ahttps?://\S+\z}i }, allow_blank: true
  validate :validate_custom_id_format

  def manageable_by?(user)
    user.present? && (user.admin? || creator_id == user.id)
  end

  def writable_by?(user)
    return false unless user
    return true if manageable_by?(user) || public?

    inventory_accesses.any? { |access| access.user_id == user.id }
  end

  def next_custom_sequence
    items.maximum(:custom_sequence).to_i + 1
  end

  def custom_id_formatter
    CustomIdFormat.new(custom_id_format)
  end

  private

  def search_document_attributes
    field_text = inventory_fields.reload.map { |field| [field.title, field.description].compact.join(" ") }
    {
      title: title,
      body: [description, category&.name, tag_list.join(" "), field_text.join(" ")].compact.join(" "),
      subtitle: category&.name
    }
  end

  def strip_title
    self.title = title.to_s.strip
  end

  def validate_custom_id_format
    custom_id_formatter.errors.each do |message, options|
      errors.add(:custom_id_format, message, **options)
    end
  end
end
