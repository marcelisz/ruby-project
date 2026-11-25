class User < ApplicationRecord
  include Searchable

  devise :omniauthable, :rememberable, :trackable

  LANGUAGES = %w[en pl].freeze
  THEMES = %w[light dark].freeze

  has_many :identities, dependent: :destroy
  has_many :inventories, foreign_key: :creator_id, inverse_of: :creator, dependent: :destroy
  has_many :inventory_accesses, dependent: :destroy
  has_many :shared_inventories, through: :inventory_accesses, source: :inventory
  has_many :likes, dependent: :destroy

  before_validation :normalize_fields
  validates :name, presence: true, length: { maximum: 100 }
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :language, inclusion: { in: LANGUAGES }
  validates :theme, inclusion: { in: THEMES }

  def blocked?
    blocked_at.present?
  end

  def active_for_authentication?
    super && !blocked?
  end

  def inactive_message
    :blocked
  end

  def role_name
    admin? ? I18n.t("roles.admin") : I18n.t("roles.user")
  end

  private

  def search_document_attributes
    {
      title: name,
      body: [name, email, email.gsub(/[@.]/, " ")].compact.join(" "),
      subtitle: nil
    }
  end

  def normalize_fields
    self.name = name.to_s.strip
    self.email = email.to_s.strip.downcase
  end
end
