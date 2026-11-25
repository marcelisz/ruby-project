require "test_helper"

class SearchFlowsTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  setup do
    cleanup!
    @category = Category.create!(name: "Equipment")
    @owner = User.create!(name: "Alice Owner", email: "alice@example.com")
    @inventory = Inventory.create!(
      title: "Laptops", description: "Company laptops", category: @category,
      creator: @owner, tag_list: "office, hardware"
    )
    @model = @inventory.inventory_fields.create!(
      title: "Model", field_type: "single_line_text", show_in_table: true
    )
    @item = @inventory.items.create!(
      created_by: @owner, field_values: { @model.id.to_s => "MacBook Pro" }
    )
    SearchDocument.connection.execute("OPTIMIZE TABLE search_documents")
    wait_for_search_index
  end

  teardown { cleanup! }

  test "full text indexes include inventories, items, users and tags" do
    assert_equal ["Laptops"], SearchDocument.full_text("office").map(&:title)
    assert_equal [@item.custom_id], SearchDocument.full_text("MacBook").map(&:title)
    assert_equal ["Alice Owner"], SearchDocument.full_text("alice@example.com").map(&:title)
    assert_equal ["Laptops"], SearchDocument.full_text("Model").map(&:title)
  end

  test "search results and tag pages are available to guests" do
    get search_path, params: { q: "MacBook" }
    assert_response :success
    assert_includes response.body, @item.custom_id
    assert_select "h2", text: I18n.t("search.items")

    tag = ActsAsTaggableOn::Tag.find_by!(name: "office")
    get tag_path(tag)
    assert_response :success
    assert_select "a", text: "Laptops"
  end

  private

  def wait_for_search_index
    deadline = Time.current + 5.seconds
    until SearchDocument.uncached { SearchDocument.full_text("MacBook").to_a.any? }
      flunk "full-text index did not catch up" if Time.current >= deadline

      sleep 0.05
    end
  end

  def cleanup!
    SearchDocument.delete_all
    Like.delete_all
    Message.delete_all
    Item.delete_all
    InventoryField.delete_all
    InventoryAccess.delete_all
    ActsAsTaggableOn::Tagging.delete_all
    ActsAsTaggableOn::Tag.delete_all
    Inventory.delete_all
    Category.delete_all
    Identity.delete_all
    User.delete_all
  end
end

