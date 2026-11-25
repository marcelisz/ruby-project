require "test_helper"
require "csv"
require "zip"

class InventoryFlowsTest < ActionDispatch::IntegrationTest
  setup do
    @category = Category.create!(name: "Equipment")
    @owner = User.create!(name: "Owner", email: "owner@example.com")
    @writer = User.create!(name: "Writer", email: "writer@example.com")
    @stranger = User.create!(name: "Stranger", email: "stranger@example.com")
    @admin = User.create!(name: "Admin", email: "admin@example.com", admin: true)
    @inventory = Inventory.create!(
      title: "Laptops", description: "Company **laptops**", category: @category,
      creator: @owner, tag_list: "office, hardware"
    )
    @inventory.inventory_accesses.create!(user: @writer)
    @model = @inventory.inventory_fields.create!(
      title: "Model", description: "Laptop model", field_type: "single_line_text", show_in_table: true
    )
    @price = @inventory.inventory_fields.create!(
      title: "Price", field_type: "number", show_in_table: true
    )
    @item = @inventory.items.create!(
      created_by: @owner, field_values: { @model.id.to_s => "MacBook Pro", @price.id.to_s => "2499.99" }
    )
  end

  test "login page uses the auth layout and only OAuth providers" do
    get new_user_session_path

    assert_response :success
    assert_select "nav.navbar", count: 0
    assert_select "input[type=password]", count: 0
    assert_select "form[action=?]", user_google_oauth2_omniauth_authorize_path
    assert_select "form[action=?]", user_facebook_omniauth_authorize_path
    assert_select "form[action=?]", user_github_omniauth_authorize_path
  end

  test "guests can browse but cannot change data" do
    get inventory_path(@inventory)
    assert_response :success
    assert_select "#select-all-items", count: 0
    assert_select "a.nav-link", text: I18n.t("tabs.settings"), count: 0
    assert_select "a.nav-link", text: I18n.t("tabs.export"), count: 0
    assert_select "a", text: I18n.t("items.add"), count: 0

    get inventory_item_path(@inventory, @item)
    assert_response :success

    get new_inventory_item_path(@inventory)
    assert_redirected_to new_user_session_path

    post inventory_item_like_path(@inventory, @item)
    assert_redirected_to new_user_session_path

    get edit_inventory_path(@inventory)
    assert_redirected_to inventory_path(@inventory)
  end

  test "owner can see all tabs while a writer sees only items and chat" do
    sign_in @owner
    get inventory_path(@inventory)
    assert_response :success
    assert_select "a.nav-link", text: I18n.t("tabs.settings")
    assert_select "a.nav-link", text: I18n.t("tabs.fields")
    assert_select "a.nav-link", text: I18n.t("tabs.export")

    sign_out @owner
    sign_in @writer
    get inventory_path(@inventory)
    assert_response :success
    assert_select "a.nav-link", text: I18n.t("tabs.items")
    assert_select "a.nav-link", text: I18n.t("tabs.chat")
    assert_select "a.nav-link", text: I18n.t("tabs.settings"), count: 0
    assert_select "a.nav-link", text: I18n.t("tabs.export"), count: 0
    assert_select "#select-all-items"
  end

  test "all owner-only pages render" do
    sign_in @owner
    [edit_inventory_path(@inventory), stats_inventory_path(@inventory),
     export_inventory_path(@inventory), custom_id_inventory_path(@inventory),
     inventory_fields_path(@inventory), access_inventory_path(@inventory)].each do |path|
      get path
      assert_response :success, "Expected #{path} to render"
    end
  end

  test "export is restricted to inventory managers" do
    sign_in @writer
    [export_inventory_path(@inventory), export_csv_inventory_path(@inventory),
     export_xlsx_inventory_path(@inventory)].each do |path|
      get path
      assert_redirected_to inventory_path(@inventory)
    end

    sign_out @writer
    sign_in @admin
    get export_inventory_path(@inventory)
    assert_response :success
    assert_select "a.nav-link", text: I18n.t("tabs.export")
  end

  test "owner can export all inventory contents as CSV and XLSX" do
    notes = @inventory.inventory_fields.create!(
      title: "Notes", field_type: "single_line_text", show_in_table: false
    )
    @item.update!(field_values: @item.field_values.merge(notes.id.to_s => "Kept in export"))
    sign_in @owner

    get export_inventory_path(@inventory)
    assert_response :success
    assert_select "a[href=?]", export_xlsx_inventory_path(@inventory)
    assert_select "a[href=?]", export_csv_inventory_path(@inventory)
    assert_select "a.nav-link.active", text: I18n.t("tabs.export")

    get export_csv_inventory_path(@inventory)
    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"])

    body = response.body.dup.force_encoding("UTF-8").delete_prefix("\uFEFF")
    csv = CSV.parse(body, headers: true)
    expected_headers = [
      I18n.t("export.headers.custom_id"), "Model", "Price", "Notes",
      I18n.t("export.headers.created_by"), I18n.t("export.headers.created_at"),
      I18n.t("export.headers.likes")
    ]
    assert_equal expected_headers, csv.headers

    row = csv.first
    assert_equal @item.custom_id, row[I18n.t("export.headers.custom_id")]
    assert_equal "MacBook Pro", row["Model"]
    assert_equal "2499.99", row["Price"]
    assert_equal "Kept in export", row["Notes"]
    assert_equal @owner.name, row[I18n.t("export.headers.created_by")]
    assert_equal "0", row[I18n.t("export.headers.likes")]
    assert_match(/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}\z/, row[I18n.t("export.headers.created_at")])

    get export_xlsx_inventory_path(@inventory)
    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                 response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"])
    assert_equal "PK", response.body.byteslice(0, 2)

    xml = nil
    Zip::File.open_buffer(response.body) do |zip|
      xml = zip.entries.select { |entry| entry.name.end_with?(".xml") }
               .map { |entry| entry.get_input_stream.read }.join
    end
    assert_includes xml, "MacBook Pro"
    assert_includes xml, "Kept in export"
    assert_includes xml, I18n.t("export.headers.custom_id")
  end

  test "owner can update inventory details and stale versions are rejected" do
    sign_in @owner
    get edit_inventory_path(@inventory)
    assert_response :success
    assert_select "form[data-autosave='true']"
    assert_select "input[name='inventory[lock_version]']"

    lock_version = @inventory.lock_version
    patch inventory_path(@inventory), params: {
      inventory: { title: "Updated laptops", description: "Updated", category_id: @category.id, lock_version: lock_version }
    }
    assert_redirected_to edit_inventory_path(@inventory)
    assert_equal "Updated laptops", @inventory.reload.title

    stale_version = @inventory.lock_version
    @inventory.update!(title: "Another update")
    patch inventory_path(@inventory), params: {
      inventory: { title: "Stale", category_id: @category.id, lock_version: stale_version }
    }
    assert_response :conflict
  end

  test "autosave endpoint returns the next lock version" do
    sign_in @owner
    patch inventory_path(@inventory), params: {
      inventory: { title: "Autosaved", category_id: @category.id, lock_version: @inventory.lock_version }
    }, headers: { "Accept" => "application/json" }

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal @inventory.reload.lock_version, payload["lock_version"]
    assert_equal "Autosaved", @inventory.title
  end

  test "writer can add an item and the system generates its custom id" do
    sign_in @writer
    get new_inventory_item_path(@inventory)
    assert_response :success

    assert_difference("Item.count", 1) do
      post inventory_items_path(@inventory), params: {
        item: { custom_id: "", field_values: { @model.id.to_s => "ThinkPad", @price.id.to_s => "1000" } }
      }
    end
    item = Item.order(:id).last
    assert_redirected_to inventory_item_path(@inventory, item)
    assert_equal "0002", item.custom_id
    assert_equal "ThinkPad", item.value_for(@model)
    assert_equal @writer, item.created_by
    assert item.created_at.present?

    get inventory_item_path(@inventory, item, edit: 1)
    assert_response :success
    assert_select "form"
  end

  test "item table omits audit columns while the item page keeps them" do
    sign_in @owner
    get inventory_path(@inventory)
    assert_response :success

    headers = css_select("table thead th").map { |header| header.text.squish }
    assert headers.any? { |header| header.start_with?(I18n.t("items.custom_id")) }
    assert headers.any? { |header| header.start_with?(I18n.t("items.likes")) }
    refute headers.any? { |header| header.include?(I18n.t("items.created_by")) }
    refute headers.any? { |header| header.include?(I18n.t("items.created_at")) }

    get inventory_item_path(@inventory, @item)
    assert_response :success
    assert_select "dt", text: I18n.t("items.created_by")
    assert_select "dt", text: I18n.t("items.created_at")
    assert_includes response.body, @owner.name
  end

  test "number field values are displayed without a trailing dot zero" do
    item = @inventory.items.create!(
      created_by: @owner, field_values: { @price.id.to_s => "2017.0" }
    )
    assert_equal "2017", item.value_for(@price)

    sign_in @owner
    get inventory_path(@inventory)
    assert_response :success
    assert_no_match(/2017\.0/, response.body)
    assert_includes response.body, "2017"

    get inventory_item_path(@inventory, item)
    assert_response :success
    assert_no_match(/2017\.0/, response.body)

    get inventory_item_path(@inventory, item, edit: 1)
    assert_response :success
    assert_select "input[type='number'][value='2017']"
  end

  test "image fields render thumbnails and full images with lightbox links" do
    image_url = "https://example.com/photo.jpg"
    document_image_url = "https://example.com/diagram.png"
    pdf_url = "https://example.com/manual.pdf"
    image_field = @inventory.inventory_fields.create!(
      title: "Photo", field_type: "image", show_in_table: true
    )
    document_image_field = @inventory.inventory_fields.create!(
      title: "Diagram", field_type: "document", show_in_table: true
    )
    document_field = @inventory.inventory_fields.create!(
      title: "Manual", field_type: "document", show_in_table: true
    )
    item = @inventory.items.create!(
      created_by: @owner,
      field_values: {
        image_field.id.to_s => image_url,
        document_image_field.id.to_s => document_image_url,
        document_field.id.to_s => pdf_url
      }
    )
    sign_in @owner

    get inventory_path(@inventory)
    assert_response :success
    assert_select "table tbody a.glightbox[href='#{image_url}'][data-type='image'] img[src='#{image_url}'][width='72'][height='54']", count: 1
    assert_select "table tbody a.glightbox[href='#{document_image_url}'] img[width='72']", count: 1
    assert_select "table tbody a[href='#{pdf_url}'][target='_blank']", count: 1

    get inventory_item_path(@inventory, item)
    assert_response :success
    assert_select "dd a.glightbox[href='#{image_url}'] img[src='#{image_url}'][width='480']", count: 1
    assert_select "dd a.glightbox[href='#{document_image_url}'] img[width='480']", count: 1

    get inventory_item_path(@inventory, item, edit: 1)
    assert_response :success
    assert_select "input[type='url'][name='item[field_values][#{image_field.id}]'][value='#{image_url}']"
    assert_select "img[id='item_field_#{image_field.id}_preview'][src='#{image_url}']"

    get stats_inventory_path(@inventory)
    assert_response :success
    assert_select "p", text: I18n.t("stats.images_provided", count: 1), count: 1
  end

  test "number field averages are rounded to whole numbers" do
    @inventory.items.create!(
      created_by: @owner, field_values: { @price.id.to_s => "2015.4" }
    )
    sign_in @owner

    get stats_inventory_path(@inventory)
    assert_response :success

    price_card = css_select(".card").find do |card|
      card.at_css(".card-header h3")&.text&.strip == "Price"
    end
    assert price_card, "Expected the Price statistics card"

    average_label = price_card.css("dt").find do |label|
      label.text.strip == I18n.t("stats.average")
    end
    assert average_label, "Expected an average row"

    assert_match(/\A2,?258\z/, average_label.next_element.text.strip)
  end

  test "boolean statistics count both values" do
    field = @inventory.inventory_fields.create!(title: "Active", field_type: "boolean")
    @inventory.items.create!(created_by: @owner, field_values: { field.id.to_s => true })
    @inventory.items.create!(created_by: @owner, field_values: { field.id.to_s => false })
    sign_in @owner

    get stats_inventory_path(@inventory)
    assert_response :success

    active_card = css_select(".card").find do |card|
      card.at_css(".card-header h3")&.text&.strip == "Active"
    end
    assert active_card, "Expected the Active statistics card"
    assert_equal "Yes: 1", active_card.at_css(".card-body .badge.text-bg-success").text.strip
    assert_equal "No: 1", active_card.at_css(".card-body .badge.text-bg-secondary").text.strip
  end

  test "bulk deletion removes selected items" do
    extra = @inventory.items.create!(created_by: @owner)
    sign_in @writer

    delete bulk_destroy_inventory_items_path(@inventory), params: { item_ids: [@item.id, extra.id] }
    assert_redirected_to inventory_path(@inventory)
    assert_not Item.exists?(@item.id)
    assert_not Item.exists?(extra.id)
    assert_equal 0, @inventory.reload.items_count
  end

  test "public inventories allow any authenticated user to add items" do
    @inventory.update!(public: true)
    sign_in @stranger

    assert_difference("Item.count", 1) do
      post inventory_items_path(@inventory), params: {
        item: { custom_id: "", field_values: { @model.id.to_s => "Public laptop" } }
      }
    end
    assert_redirected_to inventory_item_path(@inventory, Item.last)
    assert @inventory.writable_by?(@stranger)
  end

  test "likes are unique per user and item" do
    sign_in @stranger
    assert_difference("Like.count", 1) do
      post inventory_item_like_path(@inventory, @item)
    end
    assert_redirected_to inventory_item_path(@inventory, @item)
    assert_equal 1, @item.reload.likes_count

    assert_no_difference("Like.count") do
      post inventory_item_like_path(@inventory, @item)
    end
    assert_equal 1, @item.reload.likes_count
  end

  test "chat renders markdown and exposes a polling feed" do
    sign_in @writer
    post chat_inventory_path(@inventory), params: { message: { content: "**bold** and _safe_" } }
    assert_redirected_to chat_inventory_path(@inventory)

    get chat_inventory_path(@inventory)
    assert_response :success
    assert_select "strong", text: "bold"
    assert_select "em", text: "safe"

    last_id = @inventory.messages.maximum(:id)
    message = @inventory.messages.create!(user: @owner, content: "Fresh message")
    get chat_feed_inventory_path(@inventory), params: { after: last_id }, as: :json
    assert_response :success
    assert_match(/no-store/, response.headers["Cache-Control"])
    payload = JSON.parse(response.body)
    assert_equal message.id, payload["last_id"]
    assert_includes payload["html"], "Fresh message"
  end

  test "chat strips scripts from markdown" do
    @inventory.messages.create!(user: @owner, content: "<script>alert('x')</script>")

    get chat_inventory_path(@inventory)
    assert_response :success
    assert_no_match(/<script>alert/, response.body)
  end

  test "item custom id format is validated against the current format" do
    sign_in @owner
    patch custom_id_inventory_path(@inventory), params: {
      inventory: {
        custom_id_format: [{ type: "text", text: "E-" }, { type: "sequence", padding: 2 }].to_json,
        lock_version: @inventory.lock_version
      }
    }
    assert_redirected_to custom_id_inventory_path(@inventory)
    assert_equal "0001", @item.reload.custom_id

    post inventory_items_path(@inventory), params: {
      item: { custom_id: "", field_values: {} }
    }
    new_item = Item.order(:id).last
    assert_equal "E-02", new_item.custom_id

    patch inventory_item_path(@inventory, new_item), params: {
      item: { custom_id: "not-matching", field_values: {}, lock_version: new_item.lock_version }
    }
    assert_response :unprocessable_content
    assert_equal "E-02", new_item.reload.custom_id
  end

  test "fields can be reordered and enforce per-type limits" do
    assert_difference("InventoryField.count", 3) do
      3.times do |index|
        @inventory.inventory_fields.create!(title: "Flag #{index}", field_type: "boolean")
      end
    end
    extra = @inventory.inventory_fields.new(title: "Flag 3", field_type: "boolean")
    assert_not extra.valid?
    assert_equal 3, @inventory.inventory_fields.where(field_type: "boolean").count

    InventoryField.reorder!(@inventory, [@price.id, @model.id])
    assert_equal [0, 1], [@price.reload.position, @model.reload.position]
  end

  test "owner can configure field tuning and item validation" do
    sign_in @owner
    field = @inventory.inventory_fields.create!(
      title: "Serial", field_type: "single_line_text", show_in_table: true,
      min_length: 3, max_length: 6, regex_pattern: "^[A-Z0-9]+$"
    )

    assert_equal 3, field.min_length
    assert_equal 6, field.max_length
    assert_equal "^[A-Z0-9]+$", field.regex_pattern

    @price.update!(min_length: 1, max_length: 3, min_value: 0, max_value: 1000)

    get inventory_fields_path(@inventory)
    assert_response :success
    assert_select "input#inventory_field_#{field.id}_min_length[value='3']"
    assert_select "input#inventory_field_#{field.id}_max_length[value='6']"
    assert_select "input#inventory_field_#{field.id}_regex_pattern"
    assert_select "input#inventory_field_#{@price.id}_min_value[type='number']"
    assert_select "label[for='inventory_field_#{@price.id}_min_length']", text: /Minimum digits/

    text_form = css_select("form").find do |form|
      form.at_css("input#inventory_field_#{field.id}_min_length")
    end
    text_input_ids = text_form.css("input").map { |input| input["id"] }
    assert_operator text_input_ids.index("inventory_field_#{field.id}_max_length"),
                    :<, text_input_ids.index("inventory_field_#{field.id}_regex_pattern")

    number_form = css_select("form").find do |form|
      form.at_css("input#inventory_field_#{@price.id}_min_value")
    end
    number_input_ids = number_form.css("input").map { |input| input["id"] }
    assert_operator number_input_ids.index("inventory_field_#{@price.id}_max_value"),
                    :<, number_input_ids.index("inventory_field_#{@price.id}_min_length")
    assert_operator number_input_ids.index("inventory_field_#{@price.id}_min_length"),
                    :<, number_input_ids.index("inventory_field_#{@price.id}_max_length")

    get new_inventory_item_path(@inventory)
    assert_response :success
    assert_select "input#item_field_#{field.id}[minlength='3'][maxlength='6']"

    assert_no_difference("Item.count") do
      post inventory_items_path(@inventory), params: {
        item: { custom_id: "", field_values: { field.id.to_s => "ab" } }
      }
    end
    assert_response :unprocessable_content
    assert_includes response.body, "shorter than"
    assert_includes response.body, "required format"
  end

  test "field edits are saved in one batch and new fields can be added" do
    sign_in @owner
    get inventory_fields_path(@inventory)
    assert_response :success
    assert_select "form[action$='/fields/update_all'] input[type=submit]", count: 1
    assert_select "article[data-field-card] input[type=submit]", count: 0
    assert_select "form[data-add-field-form] input[type=submit]", count: 0
    assert_select "form[data-add-field-form] button[data-add-field]"
    assert_select "template[data-field-template]"

    patch update_all_inventory_fields_path(@inventory), params: {
      inventory_fields: {
        "0" => {
          id: @price.id, title: "Cost", field_type: "number", show_in_table: "1",
          min_length: "1", max_length: "3", min_value: "0", max_value: "1000", _destroy: "0"
        },
        "1" => {
          title: "Serial", field_type: "single_line_text", show_in_table: "0",
          min_length: "2", max_length: "8", _destroy: "0"
        },
        "2" => { id: @model.id, _destroy: "1" }
      }
    }

    assert_redirected_to inventory_fields_path(@inventory)
    assert_equal I18n.t("flash.fields_updated"), flash[:notice]
    assert_equal "Cost", @price.reload.title
    assert_equal [1, 3], [@price.min_length, @price.max_length]
    assert_not InventoryField.exists?(@model.id)
    serial = @inventory.inventory_fields.find_by!(title: "Serial")
    assert_equal [0, 1], [@price.position, serial.position]
  end

  test "batch field save deletes before adding when at a type limit" do
    2.times do |index|
      @inventory.inventory_fields.create!(
        title: "Extra #{index}", field_type: "single_line_text", position: index + 1
      )
    end
    doomed = @inventory.inventory_fields.find_by!(title: "Extra 0")

    sign_in @owner
    patch update_all_inventory_fields_path(@inventory), params: {
      inventory_fields: {
        "0" => { title: "Replacement", field_type: "single_line_text", _destroy: "0" },
        "1" => { id: doomed.id, _destroy: "1" }
      }
    }

    assert_redirected_to inventory_fields_path(@inventory)
    assert_not InventoryField.exists?(doomed.id)
    assert @inventory.inventory_fields.exists?(title: "Replacement")
    assert_equal 3, @inventory.inventory_fields.where(field_type: "single_line_text").count
  end

  test "batch field save rolls back invalid updates" do
    sign_in @owner
    patch update_all_inventory_fields_path(@inventory), params: {
      inventory_fields: {
        "0" => { id: @price.id, title: "", field_type: "number", _destroy: "0" }
      }
    }

    assert_response :unprocessable_content
    assert_select "form[action$='/fields/update_all']"
    assert_equal "Price", @price.reload.title
  end

  test "access management and public switch are manager-only" do
    sign_in @owner
    get user_autocomplete_inventory_path(@inventory), params: { q: "owner" }, as: :json
    assert_response :success
    assert_equal ["Owner"], JSON.parse(response.body).map { |option| option["text"].split(" (").first }

    assert_difference("InventoryAccess.count", 1) do
      post access_inventory_path(@inventory), params: { user_id: @stranger.id }
    end
    assert @inventory.access_users.reload.include?(@stranger)

    patch access_inventory_path(@inventory), params: {
      inventory: { public: "1", lock_version: @inventory.lock_version }
    }
    assert @inventory.reload.public?

    delete remove_access_inventory_path(@inventory, @stranger)
    assert_not @inventory.access_users.reload.include?(@stranger)

    sign_out @owner
    sign_in @writer
    get access_inventory_path(@inventory)
    assert_redirected_to inventory_path(@inventory)
  end

  test "tag pages expose matching inventories" do
    tag = ActsAsTaggableOn::Tag.find_by!(name: "office")
    get tag_path(tag)
    assert_response :success
    assert_select "a", text: "Laptops"
  end

  test "admin can block, unblock and delete users" do
    sign_in @admin
    get admin_path
    assert_response :success

    patch block_admin_user_path(@stranger)
    assert @stranger.reload.blocked?

    patch unblock_admin_user_path(@stranger)
    refute @stranger.reload.blocked?

    assert_difference("User.count", -1) do
      delete admin_user_path(@stranger)
    end
    assert_redirected_to admin_path
  end

  test "deleting a user destroys the inventories they own" do
    other = User.create!(name: "Temp", email: "temp@example.com")
    inventory = Inventory.create!(title: "Temporary", category: @category, creator: other)
    item = inventory.items.create!
    sign_in @admin

    assert_difference(["Inventory.count", "Item.count"], -1) do
      delete admin_user_path(other)
    end
    assert_not Inventory.exists?(inventory.id)
    assert_not Item.exists?(item.id)
  end

  test "admin can remove their own admin role" do
    sign_in @admin
    get admin_path
    assert_response :success

    patch toggle_admin_admin_user_path(@admin)
    assert_redirected_to user_path(@admin)
    assert_not @admin.reload.admin?

    get admin_path
    assert_redirected_to root_path
  end

  test "non-admin users cannot access the admin page" do
    sign_in @owner
    get admin_path
    assert_redirected_to root_path
  end

  test "profile pages distinguish owned and shared inventories" do
    sign_in @writer
    get user_path(@writer)
    assert_response :success
    assert_select "a", text: "Laptops"
    assert_select "a", text: I18n.t("inventories.add")

    get user_path(@owner)
    assert_response :success
    assert_select "a", text: I18n.t("common.edit"), count: 0
  end

  test "language and theme preferences are persisted for a signed-in user" do
    sign_in @owner
    patch language_preference_path(locale: "pl"), headers: { "HTTP_REFERER" => "http://localhost/" }
    assert_equal "pl", @owner.reload.language

    get root_path
    assert_response :success
    assert_includes response.body, I18n.t("home.latest", locale: :pl)

    patch theme_preference_path(theme: "dark"), headers: { "HTTP_REFERER" => "http://localhost/" }
    assert_equal "dark", @owner.reload.theme
    get root_path
    assert_select "html[data-bs-theme='dark']"
  end

  test "guest preferences are persisted in cookies" do
    patch language_preference_path(locale: "pl"), headers: { "HTTP_REFERER" => "http://localhost/" }
    patch theme_preference_path(theme: "dark"), headers: { "HTTP_REFERER" => "http://localhost/" }
    get root_path

    assert_response :success
    assert_select "html[data-bs-theme='dark']"
    assert_includes response.body, I18n.t("home.latest", locale: :pl)
  end

  test "inventory index sorting toggles through ascending, descending and default" do
    Inventory.create!(title: "Alpha", category: @category, creator: @owner)
    Inventory.create!(title: "Zulu", category: @category, creator: @owner)

    get inventories_path(sort: "title", dir: "asc")
    assert_response :success
    assert_operator response.body.index("Alpha"), :<, response.body.index("Zulu")

    get inventories_path(sort: "title", dir: "desc")
    assert_response :success
    assert_operator response.body.index("Zulu"), :<, response.body.index("Alpha")

    get inventories_path
    assert_response :success
    assert_select "a[href='/inventories?dir=asc&sort=title']"
  end

  test "item tables can be sorted by custom fields" do
    @inventory.items.create!(
      created_by: @owner,
      field_values: { @model.id.to_s => "ThinkPad", @price.id.to_s => "1000" }
    )

    get inventory_path(@inventory, sort: "field_#{@price.id}", dir: "asc")
    assert_response :success
    assert_operator response.body.index("0002"), :<, response.body.index("0001")

    get inventory_path(@inventory, sort: "custom_id", dir: "desc")
    assert_response :success
    assert_operator response.body.index("0002"), :<, response.body.index("0001")
  end

  test "all public pages render in Polish" do
    @inventory.update!(public: true)
    sign_in @owner
    @owner.update_columns(language: "pl")

    [root_path, inventories_path, inventory_path(@inventory), edit_inventory_path(@inventory),
     stats_inventory_path(@inventory), export_inventory_path(@inventory),
     custom_id_inventory_path(@inventory), inventory_fields_path(@inventory),
     access_inventory_path(@inventory), chat_inventory_path(@inventory),
     inventory_item_path(@inventory, @item), user_path(@owner),
     search_path(q: "Laptops")].each do |path|
      get path
      assert_response :success, "Expected #{path} to render in Polish"
    end
    assert_includes response.body, I18n.t("search.title", locale: :pl)
  end
end
