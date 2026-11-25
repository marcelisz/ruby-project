module ApplicationHelper
  MARKDOWN = Redcarpet::Markdown.new(
    Redcarpet::Render::HTML.new(filter_html: true, safe_links_only: true, hard_wrap: true),
    autolink: true, tables: true, fenced_code_blocks: true, strikethrough: true
  )
  TAG_SIZE_CLASSES = %w[fs-6 fs-5 fs-4 fs-3].freeze

  def markdown(text)
    sanitize(MARKDOWN.render(text.to_s))
  end

  def plain_markdown(text, length: 140)
    truncate(strip_tags(markdown(text)), length: length)
  end

  def icon(name, size: 16)
    content_tag(:svg, content_tag(:use, nil, href: "#icon-#{name}"),
                width: size, height: size, fill: "none",
                stroke: "currentColor", "stroke-width": 1.8,
                "stroke-linecap": "round", "stroke-linejoin": "round",
                aria: { hidden: true }, focusable: "false")
  end

  def display_name(user)
    user&.name.presence || t("common.deleted_user")
  end

  def sortable_th(label, column, current_sort:, current_direction:, sort_param: :sort,
                  direction_param: :dir)
    ascending = current_sort.to_s == column.to_s && current_direction.to_s == "asc"
    descending = current_sort.to_s == column.to_s && current_direction.to_s == "desc"
    next_direction = if current_sort.to_s != column.to_s
                       "asc"
                     elsif ascending
                       "desc"
                     end
    query = request.query_parameters.except(sort_param.to_s, direction_param.to_s)
    if next_direction
      query[sort_param.to_s] = column.to_s
      query[direction_param.to_s] = next_direction
    end
    aria_sort = ascending ? "ascending" : (descending ? "descending" : "none")
    indicator = if ascending
                  content_tag(:span, "↑", class: "ms-1", aria: { hidden: true })
                elsif descending
                  content_tag(:span, "↓", class: "ms-1", aria: { hidden: true })
                else
                  content_tag(:span, "↕", class: "ms-1 text-body-secondary", aria: { hidden: true })
                end
    href = query.any? ? "#{request.path}?#{query.to_query}" : request.path

    content_tag(
      :th,
      link_to(safe_join([label, indicator]), href,
              class: "link-body-emphasis text-decoration-none"),
      scope: "col", aria: { sort: aria_sort }
    )
  end

  def tag_size_class(count, max)
    index = max.positive? ? ((count.to_f / max) * (TAG_SIZE_CLASSES.length - 1)).round : 0
    TAG_SIZE_CLASSES[index]
  end

  def field_type_label(type)
    t("fields.types.#{type}")
  end

  def field_type_options
    InventoryField::TYPES.map { |type| [field_type_label(type), type] }
  end

  def display_stat_number(value)
    number_with_precision(value, precision: 2, strip_insignificant_zeros: true)
  end

  def display_stat_average(value)
    number_with_precision(value, precision: 0, strip_insignificant_zeros: true)
  end

  def field_value(field, value, full: false, gallery: nil)
    @field_value_presenter ||= FieldValuePresenter.new(self)
    @field_value_presenter.display(field, value, full: full, gallery: gallery)
  end

  def safe_http_url(value)
    uri = URI.parse(value.to_s)
    uri.is_a?(URI::HTTP) ? value.to_s : nil
  rescue URI::InvalidURIError
    nil
  end

  def oauth_path(provider)
    public_send("user_#{provider}_omniauth_authorize_path")
  end

  def provider_name(provider)
    t("auth.providers.#{provider}")
  end
end
