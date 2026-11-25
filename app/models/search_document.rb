class SearchDocument < ApplicationRecord
  belongs_to :searchable, polymorphic: true

  validates :searchable_id, uniqueness: { scope: :searchable_type }

  def self.full_text(query)
    terms = query.to_s.scan(/[\p{L}\p{N}]+/).first(10).map { |term| term.first(60) }
    return none if terms.empty?

    boolean_query = terms.map { |term| "+#{term}*" }.join(" ")
    rank = sanitize_sql_array([
      "MATCH(search_documents.title, search_documents.body) AGAINST (? IN BOOLEAN MODE) DESC",
      boolean_query
    ])
    matches = where("MATCH(search_documents.title, search_documents.body) AGAINST (? IN BOOLEAN MODE)",
                    boolean_query).order(Arel.sql(rank)).includes(:searchable).to_a
    return matches if matches.any?

    fallback_rank = sanitize_sql_array([
      "MATCH(search_documents.title, search_documents.body) AGAINST (?) DESC",
      query.to_s
    ])
    where("MATCH(search_documents.title, search_documents.body) AGAINST (?)", query.to_s)
      .order(Arel.sql(fallback_rank)).includes(:searchable).to_a
  end
end
