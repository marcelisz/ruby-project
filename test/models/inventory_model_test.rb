require "test_helper"

class InventoryModelTest < ActiveSupport::TestCase
  setup do
    @category = Category.create!(name: "Equipment")
    @owner = User.create!(name: "Owner", email: "owner@example.com")
    @inventory = Inventory.create!(
      title: "Laptops", description: "Company laptops", category: @category,
      creator: @owner, tag_list: "office, hardware"
    )
    @model = @inventory.inventory_fields.create!(title: "Model", field_type: "single_line_text")
    @price = @inventory.inventory_fields.create!(title: "Price", field_type: "number")
  end

  test "validates and enforces field type limits" do
    2.times do |index|
      assert @inventory.inventory_fields.create(
        title: "Number #{index}", field_type: "number"
      ).persisted?
    end
    extra = @inventory.inventory_fields.new(title: "One more", field_type: "number")

    refute extra.valid?
    assert extra.errors.of_kind?(:field_type, :limit_reached)
  end

  test "generates unique sequential custom ids and stores typed field values" do
    item = @inventory.items.create!(created_by: @owner, field_values: {
      @model.id.to_s => "MacBook Pro", @price.id.to_s => "2499.99"
    })
    other = @inventory.items.create!(created_by: @owner)

    assert_equal "0001", item.custom_id
    assert_equal "0002", other.custom_id
    assert_equal 1, item.custom_sequence
    assert_equal "2499.99", item.value_for(@price)
  end

  test "normalizes numeric values without a trailing decimal zero" do
    item = @inventory.items.create!(
      created_by: @owner, field_values: { @price.id.to_s => "2017.0" }
    )

    assert_equal "2017", item.value_for(@price)
    assert_equal "2499.99", Item.normalize_number("2499.990")
    assert_equal "0", Item.normalize_number("0.0")
  end

  test "validates field tuning configuration" do
    text = @inventory.inventory_fields.new(
      title: "Code", field_type: "single_line_text",
      min_length: 2, max_length: 4, regex_pattern: "^[A-Z]+$"
    )
    assert text.valid?

    text.max_length = 1
    refute text.valid?
    assert text.errors.of_kind?(:max_length, :must_be_greater_than_or_equal_to_min_length)

    text.max_length = 4
    text.regex_pattern = "["
    refute text.valid?
    assert text.errors.of_kind?(:regex_pattern, :invalid)

    number = @inventory.inventory_fields.new(
      title: "Quantity", field_type: "number",
      min_length: 1, max_length: 3, min_value: 10, max_value: 20
    )
    assert number.valid?

    number.max_value = 5
    refute number.valid?
    assert number.errors.of_kind?(:max_value, :must_be_greater_than_or_equal_to_min_value)

    image = @inventory.inventory_fields.new(
      title: "Picture", field_type: "image",
      min_length: 2, max_length: 4, min_value: 10, max_value: 20, regex_pattern: "^x$"
    )
    assert image.valid?
    assert_nil image.min_length
    assert_nil image.max_length
    assert_nil image.min_value
    assert_nil image.max_value
    assert_nil image.regex_pattern
  end

  test "database rejects invalid field tuning settings" do
    assert_raises(ActiveRecord::StatementInvalid) do
      @model.update_columns(min_length: 5, max_length: 2)
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      @model.update_columns(min_value: 10)
    end

    @price.update_columns(min_length: 1, max_length: 3)
    assert_equal [1, 3], [@price.reload.min_length, @price.max_length]
  end

  test "enforces text and number tuning when saving items" do
    code = @inventory.inventory_fields.create!(
      title: "Code", field_type: "single_line_text",
      min_length: 2, max_length: 4, regex_pattern: "^[A-Z]+$"
    )
    quantity = @inventory.inventory_fields.create!(
      title: "Quantity", field_type: "number",
      min_length: 2, max_length: 3, min_value: 0, max_value: 1000
    )

    too_short = @inventory.items.new(field_values: { code.id.to_s => "A", quantity.id.to_s => "15" })
    refute too_short.valid?
    assert too_short.errors.of_kind?(:field_values, :too_short)

    too_long = @inventory.items.new(field_values: { code.id.to_s => "ABCDE", quantity.id.to_s => "15" })
    refute too_long.valid?
    assert too_long.errors.of_kind?(:field_values, :too_long)

    invalid_format = @inventory.items.new(
      field_values: { code.id.to_s => "ab", quantity.id.to_s => "15" }
    )
    refute invalid_format.valid?
    assert invalid_format.errors.of_kind?(:field_values, :invalid_text_format)

    too_few_digits = @inventory.items.new(
      field_values: { code.id.to_s => "AB", quantity.id.to_s => "9" }
    )
    refute too_few_digits.valid?
    assert too_few_digits.errors.of_kind?(:field_values, :too_few_digits)

    too_many_digits = @inventory.items.new(
      field_values: { code.id.to_s => "AB", quantity.id.to_s => "1000" }
    )
    refute too_many_digits.valid?
    assert too_many_digits.errors.of_kind?(:field_values, :too_many_digits)

    too_small = @inventory.items.new(field_values: { code.id.to_s => "AB", quantity.id.to_s => "-1" })
    refute too_small.valid?
    assert too_small.errors.of_kind?(:field_values, :below_minimum)

    too_large = @inventory.items.new(field_values: { code.id.to_s => "AB", quantity.id.to_s => "1001" })
    refute too_large.valid?
    assert too_large.errors.of_kind?(:field_values, :above_maximum)

    valid = @inventory.items.new(field_values: { code.id.to_s => "AB", quantity.id.to_s => "20" })
    assert valid.valid?
  end

  test "database triggers reject tuned values written outside application validation" do
    code = @inventory.inventory_fields.create!(
      title: "Code", field_type: "single_line_text",
      min_length: 2, max_length: 4, regex_pattern: "^[A-Z]+$"
    )
    quantity = @inventory.inventory_fields.create!(
      title: "Quantity", field_type: "number",
      min_length: 2, max_length: 3, min_value: 0, max_value: 1000
    )
    values = { code.id.to_s => "AB", quantity.id.to_s => "15" }

    ["ABCDE", "ab"].each do |invalid_code|
      assert_raises(ActiveRecord::StatementInvalid) do
        Item.insert_all!([direct_item_attributes(values.merge(code.id.to_s => invalid_code))])
      end
    end

    ["9", "1000", "-1", "1001"].each do |invalid_quantity|
      assert_raises(ActiveRecord::StatementInvalid) do
        Item.insert_all!([direct_item_attributes(values.merge(quantity.id.to_s => invalid_quantity))])
      end
    end

    assert_difference("Item.count", 1) do
      Item.insert_all!([direct_item_attributes(values)])
    end
    item = Item.order(:id).last

    assert_raises(ActiveRecord::StatementInvalid) do
      item.update_columns(field_values: values.merge(code.id.to_s => "TOOLONG"))
    end
  end

  test "enforces custom id uniqueness within an inventory but not across inventories" do
    @inventory.update!(custom_id_format: [{ "type" => "text", "text" => "SAME" }])
    @inventory.items.create!
    duplicate = @inventory.items.new(custom_id: "SAME")

    refute duplicate.valid?
    assert duplicate.errors.of_kind?(:custom_id, :taken)
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save(validate: false) }

    other_inventory = Inventory.create!(
      title: "Other", category: @category, creator: @owner,
      custom_id_format: [{ "type" => "text", "text" => "SAME" }]
    )
    assert other_inventory.items.create!.persisted?
  end

  test "optimistic locking rejects stale inventory and item updates" do
    item = @inventory.items.create!
    stale_inventory = Inventory.find(@inventory.id)
    stale_item = Item.find(item.id)

    @inventory.update!(title: "Updated")
    assert_raises(ActiveRecord::StaleObjectError) { stale_inventory.update!(title: "Stale") }

    item.update!(custom_id: "0002")
    assert_raises(ActiveRecord::StaleObjectError) { stale_item.update!(custom_id: "0003") }
  end

  test "rejects an invalid custom id format" do
    assert_raises(ActiveRecord::RecordInvalid) do
      @inventory.update!(custom_id_format: [{ "type" => "sequence", "padding" => 99 }])
    end
  end

  test "read access rules" do
    stranger = User.create!(name: "Stranger", email: "stranger@example.com")

    refute @inventory.writable_by?(nil)
    refute @inventory.writable_by?(stranger)
    assert @inventory.writable_by?(@owner)

    @inventory.inventory_accesses.create!(user: stranger)
    assert @inventory.writable_by?(stranger)

    @inventory.update!(public: true)
    other = User.create!(name: "Other", email: "other@example.com")
    assert @inventory.writable_by?(other)
    refute @inventory.manageable_by?(stranger)
  end

  private

  def direct_item_attributes(field_values)
    {
      inventory_id: @inventory.id,
      custom_id: "DB-#{SecureRandom.hex(6)}",
      field_values: field_values,
      created_at: Time.current,
      updated_at: Time.current
    }
  end
end
