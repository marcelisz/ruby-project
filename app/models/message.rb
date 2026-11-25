class Message < ApplicationRecord
  belongs_to :inventory
  belongs_to :user, optional: true

  validates :content, presence: true, length: { maximum: 5000 }

  scope :chronological, -> { order(:id) }
end
