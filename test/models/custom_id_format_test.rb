require "test_helper"

class CustomIdFormatTest < ActiveSupport::TestCase
  test "default format generates a padded sequence" do
    format = CustomIdFormat.new(CustomIdFormat.default)

    assert format.valid?
    assert_equal "0001", format.generate(sequence: 1)
    assert_match format.regexp, "0042"
    refute_match format.regexp, "ABC"
  end

  test "all element types can be generated and validated" do
    format = CustomIdFormat.new([
      { "type" => "text", "text" => "ÜNICODE-" },
      { "type" => "guid" },
      { "type" => "datetime", "format" => "%Y%m%d" },
      { "type" => "random6" },
      { "type" => "random9" },
      { "type" => "random20", "padding" => 7 },
      { "type" => "random32", "padding" => 10 },
      { "type" => "sequence", "padding" => 3 }
    ])

    value = format.generate(sequence: 7)

    assert format.valid?
    assert_match format.regexp, value
    assert_includes value, "ÜNICODE-"
    assert_match(/\d{3}\z/, value)
  end

  test "invalid elements are reported" do
    format = CustomIdFormat.new([
      { "type" => "text", "text" => "" },
      { "type" => "datetime", "format" => "%Q" },
      { "type" => "sequence", "padding" => 30 },
      { "type" => "unknown" }
    ])

    refute format.valid?
    assert_equal %i[blank_text invalid_datetime invalid_padding invalid_type], format.errors.map(&:first)
  end

  test "limits the number of elements" do
    format = CustomIdFormat.new(Array.new(CustomIdFormat::MAX_ELEMENTS + 1) { { "type" => "random6" } })

    refute format.valid?
    assert_equal :too_many_elements, format.errors.first.first
  end

  test "builder config exposes type defaults for the client" do
    config = CustomIdFormat.builder_config

    assert_equal CustomIdFormat::TYPES, config[:types].keys
    assert_equal [1, 7], config[:types]["random20"][:padding]
    assert_equal 6, config[:types]["random20"][:defaultPadding]
    assert_equal "%Y%m%d", config[:types]["datetime"][:defaultFormat]
    refute config[:types]["random6"].key?(:padding)
    assert_equal 20, config[:maxElements]
    assert_equal Time.current.strftime("%Y"), config[:dateValues]["Y"]
  end

  test "supports literal percent signs in dates" do
    format = CustomIdFormat.new([{ "type" => "datetime", "format" => "%%%Y" }])

    assert format.valid?
    assert_match format.regexp, format.generate
  end
end
