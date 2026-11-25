class FieldValuePresenter
  IMAGE_EXTENSIONS = %w[.jpg .jpeg .jpe .png .apng .gif .webp .avif .svg].freeze
  TRUNCATE_LENGTH = 100
  DOCUMENT_LABEL_LENGTH = 60
  IMAGE_FULL_WIDTH = 480
  IMAGE_THUMBNAIL_WIDTH = 72
  IMAGE_THUMBNAIL_HEIGHT = 54

  def initialize(view_context = nil)
    @view = view_context
  end

  def display(field, value, full: false, gallery: nil)
    if blank?(value)
      return @view.content_tag(:span, @view.t("common.none"), class: "text-body-secondary")
    end

    case field.field_type
    when "number"
      number = Item.normalize_number(value)
      full ? number : @view.truncate(number, length: TRUNCATE_LENGTH)
    when "boolean"
      enabled = value == true || value.to_s == "true"
      @view.content_tag(:span, enabled ? @view.t("common.yes") : @view.t("common.no"),
                        class: "badge #{enabled ? 'text-bg-success' : 'text-bg-secondary'}")
    when "image"
      image_field_value(field, value, full: full, gallery: gallery)
    when "document"
      url = @view.safe_http_url(value)
      if url && image_url?(url)
        image_field_value(field, url, full: full, gallery: gallery)
      elsif url
        @view.link_to(@view.truncate(value.to_s, length: DOCUMENT_LABEL_LENGTH), url,
                      target: "_blank", rel: "noopener")
      else
        value
      end
    when "multi_line_text"
      full ? @view.simple_format(value) : @view.truncate(value.to_s, length: TRUNCATE_LENGTH)
    else
      full ? value : @view.truncate(value.to_s, length: TRUNCATE_LENGTH)
    end
  end

  def export(field, value)
    return "" if value.nil?

    case field.field_type
    when "number"
      Item.normalize_number(value)
    when "boolean"
      ActiveModel::Type::Boolean.new.cast(value) ? I18n.t("common.yes") : I18n.t("common.no")
    else
      value.to_s
    end
  end

  def statistics(fields, values_rows)
    fields_by_key = fields.index_by { |field| field.id.to_s }
    accumulators = fields.to_h { |field| [field.id.to_s, statistic_accumulator(field)] }

    values_rows.each do |row|
      next unless row.respond_to?(:each_pair)

      row.each_pair do |field_id, value|
        field = fields_by_key[field_id.to_s]
        next unless field

        accumulate_statistic(accumulators[field.id.to_s], field, value)
      end
    end

    fields.map { |field| [field, finalize_statistic(accumulators[field.id.to_s], field)] }
  end

  private

  def statistic_accumulator(field)
    case field.field_type
    when "number" then { numbers: [] }
    when "boolean" then { true: 0, false: 0 }
    when "document", "image" then { count: 0 }
    else { values: Hash.new(0) }
    end
  end

  def accumulate_statistic(stats, field, value)
    case field.field_type
    when "number"
      number = decimal_value(value)
      stats[:numbers] << number if number
    when "boolean"
      stats[:true] += 1 if value == true
      stats[:false] += 1 if value == false
    when "document", "image"
      stats[:count] += 1 if value.to_s.strip.present?
    else
      string = value.to_s
      stats[:values][string] += 1 unless string.blank?
    end
  end

  def finalize_statistic(stats, field)
    case field.field_type
    when "number"
      numbers = stats[:numbers]
      { count: numbers.size, average: (numbers.sum / numbers.size if numbers.any?),
        min: numbers.min, max: numbers.max }
    when "boolean"
      { true: stats[:true], false: stats[:false] }
    when "document", "image"
      { count: stats[:count] }
    else
      { frequent: stats[:values].sort_by { |value, count| [-count, value] }.first(5) }
    end
  end

  def blank?(value)
    value.nil? || value.to_s.strip.empty?
  end

  def decimal_value(value)
    BigDecimal(value.to_s)
  rescue ArgumentError
    nil
  end

  def image_field_value(field, value, full:, gallery:)
    url = @view.safe_http_url(value)
    return value unless url

    image = if full
              @view.image_tag(url, alt: field.title, class: "img-fluid img-thumbnail",
                              width: IMAGE_FULL_WIDTH, loading: "lazy")
            else
              @view.image_tag(url, alt: field.title, class: "rounded border object-fit-cover",
                              width: IMAGE_THUMBNAIL_WIDTH, height: IMAGE_THUMBNAIL_HEIGHT,
                              loading: "lazy")
            end

    @view.link_to(url, class: "glightbox d-inline-block",
                       data: { type: "image", gallery: gallery }) { image }
  end

  def image_url?(url)
    uri = URI.parse(url.to_s)
    return false unless uri.is_a?(URI::HTTP)
    return true if uri.path.include?("/image/upload/")

    IMAGE_EXTENSIONS.include?(File.extname(uri.path).downcase)
  rescue URI::InvalidURIError
    false
  end
end
