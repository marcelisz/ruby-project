class CustomIdFormat
  GUID_EXAMPLE = "00000000-0000-4000-8000-000000000000".freeze
  GUID_PATTERN = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}".freeze

  TYPE_DEFINITIONS = {
    "text" => { kind: "text" },
    "random20" => {
      kind: "random", max: 2**20, max_digits: 7, padding: 1..7,
      default_padding: 6, example: "123456"
    },
    "random32" => {
      kind: "random", max: 2**32, max_digits: 10, padding: 1..10,
      default_padding: 9, example: "123456789"
    },
    "random6" => {
      kind: "random", max: 10**6, max_digits: 6, example: "123456"
    },
    "random9" => {
      kind: "random", max: 10**9, max_digits: 9, example: "123456789"
    },
    "guid" => { kind: "guid", example: GUID_EXAMPLE, pattern: GUID_PATTERN },
    "datetime" => { kind: "datetime" },
    "sequence" => { kind: "sequence", padding: 1..10, default_padding: 4 }
  }.freeze

  TYPES = TYPE_DEFINITIONS.keys.freeze
  DATE_DIRECTIVES = %w[Y y m d H M S].freeze
  DATE_PATTERNS = {
    "Y" => "\\d{4}", "y" => "\\d{2}", "m" => "\\d{2}", "d" => "\\d{2}",
    "H" => "\\d{2}", "M" => "\\d{2}", "S" => "\\d{2}", "%" => "%"
  }.freeze
  MAX_ELEMENTS = 20
  DEFAULT_DATETIME_FORMAT = "%Y%m%d"
  DEFAULT = [
    { "type" => "sequence", "padding" => TYPE_DEFINITIONS.fetch("sequence")[:default_padding] }
  ].freeze

  def self.default
    DEFAULT.deep_dup
  end

  def self.builder_config
    {
      types: TYPE_DEFINITIONS.to_h { |type, definition| [type, builder_type(definition)] },
      dateValues: date_values,
      maxElements: MAX_ELEMENTS
    }
  end

  def self.builder_type(definition)
    {
      kind: definition[:kind],
      max: definition[:max],
      digits: definition[:max_digits],
      padding: definition[:padding] && [definition[:padding].min, definition[:padding].max],
      defaultPadding: definition[:default_padding],
      defaultFormat: definition[:kind] == "datetime" ? DEFAULT_DATETIME_FORMAT : nil,
      sample: definition[:example]
    }.compact
  end

  def self.date_values
    now = Time.current
    DATE_DIRECTIVES.to_h { |directive| [directive, now.strftime("%#{directive}")] }
  end

  private_class_method :builder_type, :date_values

  def initialize(elements)
    @elements = Array(elements).map { |element| element.respond_to?(:to_h) ? element.to_h.stringify_keys : {} }
  end

  attr_reader :elements

  def errors
    return [[:blank, {}]] if elements.empty?
    return [[:too_many_elements, { max: MAX_ELEMENTS }]] if elements.size > MAX_ELEMENTS

    elements.each_with_index.flat_map { |element, index| element_errors(element, index) }
  end

  def valid?
    errors.empty?
  end

  def generate(sequence: nil)
    elements.map { |element| generate_element(element, sequence) }.join
  end

  def regexp
    Regexp.new("\\A#{elements.map { |element| element_pattern(element) }.join}\\z", Regexp::IGNORECASE)
  end

  def example(sequence: 1)
    elements.map { |element| example_element(element, sequence) }.join
  end

  private

  def element_errors(element, index)
    definition = TYPE_DEFINITIONS[element["type"].to_s]
    return [[:invalid_type, { index: index + 1 }]] unless definition

    error =
      case definition[:kind]
      when "text"
        :blank_text if element["text"].to_s.strip.empty?
      when "datetime"
        :invalid_datetime unless datetime_format_valid?(element["format"].to_s)
      else
        range = definition[:padding]
        if range && !range.cover?(padding(element))
          [:invalid_padding, { min: range.min, max: range.max }]
        end
      end

    return [] unless error

    [error.is_a?(Array) ? [error[0], error[1].merge(index: index + 1)] : [error, { index: index + 1 }]]
  end

  def example_element(element, sequence)
    definition = TYPE_DEFINITIONS[element["type"]]
    return unless definition

    case definition[:kind]
    when "text" then element["text"].to_s
    when "random" then definition[:example].rjust(random_width(element, definition), "0")
    when "guid" then definition[:example]
    when "datetime" then Time.current.strftime(element["format"].to_s)
    when "sequence" then sequence.to_s.rjust(padding(element), "0")
    end
  end

  def generate_element(element, sequence)
    definition = TYPE_DEFINITIONS[element["type"]]
    return unless definition

    case definition[:kind]
    when "text" then element["text"].to_s
    when "random"
      SecureRandom.random_number(definition[:max]).to_s.rjust(random_width(element, definition), "0")
    when "guid" then SecureRandom.uuid
    when "datetime" then Time.current.strftime(element["format"].to_s)
    when "sequence" then sequence.to_i.to_s.rjust(padding(element), "0")
    end
  end

  def element_pattern(element)
    definition = TYPE_DEFINITIONS[element["type"]]
    return unless definition

    case definition[:kind]
    when "text" then Regexp.escape(element["text"].to_s)
    when "random"
      width = random_width(element, definition)
      max_digits = definition[:max_digits]
      width == max_digits ? "\\d{#{width}}" : "\\d{#{width},#{max_digits}}"
    when "guid" then definition[:pattern]
    when "datetime" then datetime_pattern(element["format"].to_s)
    when "sequence" then "\\d{#{padding(element)},}"
    end
  end

  def random_width(element, definition)
    definition[:padding] ? padding(element) : definition[:max_digits]
  end

  def datetime_pattern(format)
    index = 0
    pattern = +""
    while index < format.length
      char = format[index]
      if char == "%"
        directive = format[index + 1]
        pattern << (directive == "%" ? "%" : DATE_PATTERNS.fetch(directive))
        index += 2
      else
        pattern << Regexp.escape(char)
        index += 1
      end
    end
    pattern
  end

  def datetime_format_valid?(format)
    return false if format.empty? || format.end_with?("%")

    directives = format.scan(/%(.)/).flatten
    (directives - DATE_DIRECTIVES - ["%"]).empty?
  end

  def padding(element)
    definition = TYPE_DEFINITIONS[element["type"]]
    Integer(element["padding"] || definition&.fetch(:default_padding, 0) || 0)
  rescue ArgumentError, TypeError
    0
  end
end
