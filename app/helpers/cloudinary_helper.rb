module CloudinaryHelper
  WIDGET_URL = "https://upload-widget.cloudinary.com/global/all.js".freeze
  TRANSPARENT_PIXEL = "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==".freeze

  def cloudinary_configured?
    Rails.configuration.x.cloudinary_cloud_name.present? &&
      Rails.configuration.x.cloudinary_upload_preset.present?
  end

  def cloudinary_widget_script
    return unless cloudinary_configured?

    content_for(:scripts) { javascript_include_tag WIDGET_URL }
  end

  def cloudinary_upload_button(input_id:, preview_id:)
    return unless cloudinary_configured?

    content_tag(
      :button,
      safe_join([icon("upload"), " ", t("inventories.upload_image")]),
      type: "button", class: "btn btn-outline-secondary",
      data: {
        cloudinary_upload: true,
        cloud_name: Rails.configuration.x.cloudinary_cloud_name,
        upload_preset: Rails.configuration.x.cloudinary_upload_preset,
        input_id: input_id,
        preview_id: preview_id,
        widget_error: t("inventories.upload_unavailable")
      }
    )
  end
end
