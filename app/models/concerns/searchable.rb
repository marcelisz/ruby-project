module Searchable
  extend ActiveSupport::Concern

  included do
    has_one :search_document, as: :searchable, dependent: :destroy
    after_save :refresh_search_document
  end

  def refresh_search_document
    return unless persisted?

    document = search_document || build_search_document
    document.update!(search_document_attributes)
  end

  private

  def search_document_attributes
    raise NotImplementedError, "#{self.class} must implement #search_document_attributes"
  end
end
