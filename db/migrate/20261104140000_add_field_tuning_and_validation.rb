class AddFieldTuningAndValidation < ActiveRecord::Migration[8.1]
  def up
    add_column :inventory_fields, :min_length, :integer
    add_column :inventory_fields, :max_length, :integer
    add_column :inventory_fields, :min_value, :decimal, precision: 65, scale: 10
    add_column :inventory_fields, :max_value, :decimal, precision: 65, scale: 10
    add_column :inventory_fields, :regex_pattern, :string, limit: 1000

    add_check_constraint :inventory_fields, <<~SQL.squish, name: "chk_inventory_fields_tuning"
      (field_type IN ('single_line_text', 'multi_line_text', 'number')
        OR (min_length IS NULL AND max_length IS NULL))
      AND (field_type IN ('single_line_text', 'multi_line_text') OR regex_pattern IS NULL)
      AND (field_type = 'number' OR (min_value IS NULL AND max_value IS NULL))
      AND (min_length IS NULL OR min_length >= 0)
      AND (max_length IS NULL OR max_length >= 0)
      AND (min_length IS NULL OR max_length IS NULL OR min_length <= max_length)
      AND (min_value IS NULL OR max_value IS NULL OR min_value <= max_value)
    SQL

    create_trigger("items_validate_field_values_before_insert", compatibility: 1).on(:items).before(:insert) do
      File.read(Rails.root.join("db/sql/items_field_validation.sql"))
    end

    create_trigger("items_validate_field_values_before_update", compatibility: 1).on(:items).before(:update) do
      <<~SQL
        IF NOT (NEW.field_values <=> OLD.field_values)
           OR NOT (NEW.inventory_id <=> OLD.inventory_id) THEN
          #{File.read(Rails.root.join("db/sql/items_field_validation.sql"))}
        END IF;
      SQL
    end
  end

  def down
    drop_trigger("items_validate_field_values_before_update", :items)
    drop_trigger("items_validate_field_values_before_insert", :items)
    remove_check_constraint :inventory_fields, name: "chk_inventory_fields_tuning"
    remove_column :inventory_fields, :regex_pattern
    remove_column :inventory_fields, :max_value
    remove_column :inventory_fields, :min_value
    remove_column :inventory_fields, :max_length
    remove_column :inventory_fields, :min_length
  end
end
