# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_04_140000) do
  create_table "categories", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "identities", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "uid"], name: "index_identities_on_provider_and_uid", unique: true
    t.index ["user_id"], name: "index_identities_on_user_id"
  end

  create_table "inventories", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "title", null: false
    t.text "description", size: :long
    t.bigint "category_id", null: false
    t.bigint "creator_id", null: false
    t.string "image_url", limit: 2048
    t.boolean "public", default: false, null: false
    t.json "custom_id_format", null: false
    t.integer "items_count", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_inventories_on_category_id"
    t.index ["created_at"], name: "index_inventories_on_created_at"
    t.index ["creator_id"], name: "index_inventories_on_creator_id"
    t.index ["items_count"], name: "index_inventories_on_items_count"
    t.index ["title"], name: "index_inventories_on_title"
  end

  create_table "inventory_accesses", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "inventory_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["inventory_id", "user_id"], name: "index_inventory_accesses_on_inventory_id_and_user_id", unique: true
    t.index ["inventory_id"], name: "index_inventory_accesses_on_inventory_id"
    t.index ["user_id"], name: "index_inventory_accesses_on_user_id"
  end

  create_table "inventory_fields", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "inventory_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "field_type", null: false
    t.boolean "show_in_table", default: false, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "min_length"
    t.integer "max_length"
    t.decimal "min_value", precision: 65, scale: 10
    t.decimal "max_value", precision: 65, scale: 10
    t.string "regex_pattern", limit: 1000
    t.index ["inventory_id", "position"], name: "index_inventory_fields_on_inventory_id_and_position"
    t.index ["inventory_id"], name: "index_inventory_fields_on_inventory_id"
    t.check_constraint "((`field_type` in (_utf8mb4'single_line_text',_utf8mb4'multi_line_text',_utf8mb4'number')) or ((`min_length` is null) and (`max_length` is null))) and ((`field_type` in (_utf8mb4'single_line_text',_utf8mb4'multi_line_text')) or (`regex_pattern` is null)) and ((`field_type` = _utf8mb4'number') or ((`min_value` is null) and (`max_value` is null))) and ((`min_length` is null) or (`min_length` >= 0)) and ((`max_length` is null) or (`max_length` >= 0)) and ((`min_length` is null) or (`max_length` is null) or (`min_length` <= `max_length`)) and ((`min_value` is null) or (`max_value` is null) or (`min_value` <= `max_value`))", name: "chk_inventory_fields_tuning"
  end

  create_table "items", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "inventory_id", null: false
    t.bigint "created_by_id"
    t.string "custom_id", null: false
    t.integer "custom_sequence"
    t.json "field_values", null: false
    t.integer "likes_count", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_items_on_created_by_id"
    t.index ["custom_sequence"], name: "index_items_on_custom_sequence"
    t.index ["inventory_id", "created_at"], name: "index_items_on_inventory_id_and_created_at"
    t.index ["inventory_id", "custom_id"], name: "index_items_on_inventory_id_and_custom_id", unique: true
    t.index ["inventory_id"], name: "index_items_on_inventory_id"
  end

  create_table "likes", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "item_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_likes_on_item_id"
    t.index ["user_id", "item_id"], name: "index_likes_on_user_id_and_item_id", unique: true
    t.index ["user_id"], name: "index_likes_on_user_id"
  end

  create_table "messages", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "inventory_id", null: false
    t.bigint "user_id"
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["inventory_id", "created_at"], name: "index_messages_on_inventory_id_and_created_at"
    t.index ["inventory_id"], name: "index_messages_on_inventory_id"
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "search_documents", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "searchable_type", null: false
    t.bigint "searchable_id", null: false
    t.string "title", null: false
    t.text "body", size: :long
    t.string "subtitle"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["searchable_type", "searchable_id"], name: "index_search_documents_on_searchable_type_and_searchable_id", unique: true
    t.index ["title", "body"], name: "index_search_documents_on_title_and_body", type: :fulltext
  end

  create_table "taggings", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "tag_id", null: false
    t.string "taggable_type", null: false
    t.bigint "taggable_id", null: false
    t.string "tagger_type"
    t.bigint "tagger_id"
    t.string "context", limit: 128
    t.string "tenant", limit: 128
    t.datetime "created_at"
    t.index ["tag_id", "taggable_id", "taggable_type", "context", "tagger_id", "tagger_type"], name: "taggings_idx", unique: true
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["taggable_id", "taggable_type", "context"], name: "taggings_taggable_context_idx"
    t.index ["taggable_id", "taggable_type", "tagger_id", "context"], name: "taggings_idy"
    t.index ["taggable_type", "taggable_id"], name: "index_taggings_on_taggable"
    t.index ["tagger_type", "tagger_id"], name: "index_taggings_on_tagger"
  end

  create_table "tags", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false, collation: "utf8mb4_bin"
    t.integer "taggings_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.boolean "admin", default: false, null: false
    t.datetime "blocked_at"
    t.string "language", default: "en", null: false
    t.string "theme", default: "light", null: false
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["name"], name: "index_users_on_name"
  end

  add_foreign_key "identities", "users", on_delete: :cascade
  add_foreign_key "inventories", "categories"
  add_foreign_key "inventories", "users", column: "creator_id", on_delete: :cascade
  add_foreign_key "inventory_accesses", "inventories", on_delete: :cascade
  add_foreign_key "inventory_accesses", "users", on_delete: :cascade
  add_foreign_key "inventory_fields", "inventories", on_delete: :cascade
  add_foreign_key "items", "inventories", on_delete: :cascade
  add_foreign_key "items", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "likes", "items", on_delete: :cascade
  add_foreign_key "likes", "users", on_delete: :cascade
  add_foreign_key "messages", "inventories", on_delete: :cascade
  add_foreign_key "messages", "users", on_delete: :nullify
  add_foreign_key "taggings", "tags", on_delete: :cascade
  execute(<<-SQL)
CREATE TRIGGER items_validate_field_values_before_insert BEFORE INSERT ON `items`
FOR EACH ROW
BEGIN
    IF EXISTS (
      SELECT 1
      FROM JSON_TABLE(JSON_KEYS(NEW.field_values), '$[*]'
        COLUMNS(field_key VARCHAR(64) PATH '$')) AS field_keys
      INNER JOIN inventory_fields AS inv_fields
        ON inv_fields.id = CAST(field_keys.field_key AS UNSIGNED)
       AND inv_fields.inventory_id = NEW.inventory_id
      WHERE CHAR_LENGTH(JSON_UNQUOTE(JSON_EXTRACT(NEW.field_values, CONCAT('$."', field_keys.field_key, '"')))) > 0
        AND (
          (
            inv_fields.field_type IN ('single_line_text', 'multi_line_text')
            AND (
              (inv_fields.min_length IS NOT NULL
                AND CHAR_LENGTH(JSON_UNQUOTE(JSON_EXTRACT(NEW.field_values, CONCAT('$."', field_keys.field_key, '"')))) < inv_fields.min_length)
              OR
              (inv_fields.max_length IS NOT NULL
                AND CHAR_LENGTH(JSON_UNQUOTE(JSON_EXTRACT(NEW.field_values, CONCAT('$."', field_keys.field_key, '"')))) > inv_fields.max_length)
              OR
              (inv_fields.regex_pattern IS NOT NULL
                AND inv_fields.regex_pattern <> ''
                AND NOT REGEXP_LIKE(JSON_UNQUOTE(JSON_EXTRACT(NEW.field_values, CONCAT('$."', field_keys.field_key, '"'))), inv_fields.regex_pattern, 'c'))
            )
          )
          OR
          (
            inv_fields.field_type = 'number'
            AND (
              NOT REGEXP_LIKE(JSON_UNQUOTE(JSON_EXTRACT(NEW.field_values, CONCAT('$."', field_keys.field_key, '"'))), '^[+-]?[0-9]+([.][0-9]+)?$', 'c')
              OR
              (inv_fields.min_length IS NOT NULL
                AND CHAR_LENGTH(REPLACE(REPLACE(REPLACE(JSON_UNQUOTE(JSON_EXTRACT(NEW.field_values, CONCAT('$."', field_keys.field_key, '"'))), '-', ''), '+', ''), '.', '')) < inv_fields.min_length)
              OR
              (inv_fields.max_length IS NOT NULL
                AND CHAR_LENGTH(REPLACE(REPLACE(REPLACE(JSON_UNQUOTE(JSON_EXTRACT(NEW.field_values, CONCAT('$."', field_keys.field_key, '"'))), '-', ''), '+', ''), '.', '')) > inv_fields.max_length)
              OR
              (inv_fields.min_value IS NOT NULL
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(NEW.field_values, CONCAT('$."', field_keys.field_key, '"'))) AS DECIMAL(65,10)) < inv_fields.min_value)
              OR
              (inv_fields.max_value IS NOT NULL
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(NEW.field_values, CONCAT('$."', field_keys.field_key, '"'))) AS DECIMAL(65,10)) > inv_fields.max_value)
            )
          )
        )
    ) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Custom field values violate inventory field constraints';
    END IF;
END
  SQL

  execute(<<-SQL)
CREATE TRIGGER items_validate_field_values_before_update BEFORE UPDATE ON `items`
FOR EACH ROW
BEGIN
    IF NOT (NEW.field_values <=> OLD.field_values)
       OR NOT (NEW.inventory_id <=> OLD.inventory_id) THEN
      IF EXISTS (
      SELECT 1
      FROM JSON_TABLE(JSON_KEYS(NEW.field_values), '$[*]'
        COLUMNS(field_key VARCHAR(64) PATH '$')) AS field_keys
      INNER JOIN inventory_fields AS inv_fields
        ON inv_fields.id = CAST(field_keys.field_key AS UNSIGNED)
       AND inv_fields.inventory_id = NEW.inventory_id
      WHERE CHAR_LENGTH(JSON_UNQUOTE(JSON_EXTRACT(NEW.field_values, CONCAT('$."', field_keys.field_key, '"')))) > 0
        AND (
          (
            inv_fields.field_type IN ('single_line_text', 'multi_line_text')
            AND (
              (inv_fields.min_length IS NOT NULL
                AND CHAR_LENGTH(JSON_UNQUOTE(JSON_EXTRACT(NEW.field_values, CONCAT('$."', field_keys.field_key, '"')))) < inv_fields.min_length)
              OR
              (inv_fields.max_length IS NOT NULL
                AND CHAR_LENGTH(JSON_UNQUOTE(JSON_EXTRACT(NEW.field_values, CONCAT('$."', field_keys.field_key, '"')))) > inv_fields.max_length)
              OR
              (inv_fields.regex_pattern IS NOT NULL
                AND inv_fields.regex_pattern <> ''
                AND NOT REGEXP_LIKE(JSON_UNQUOTE(JSON_EXTRACT(NEW.field_values, CONCAT('$."', field_keys.field_key, '"'))), inv_fields.regex_pattern, 'c'))
            )
          )
          OR
          (
            inv_fields.field_type = 'number'
            AND (
              NOT REGEXP_LIKE(JSON_UNQUOTE(JSON_EXTRACT(NEW.field_values, CONCAT('$."', field_keys.field_key, '"'))), '^[+-]?[0-9]+([.][0-9]+)?$', 'c')
              OR
              (inv_fields.min_length IS NOT NULL
                AND CHAR_LENGTH(REPLACE(REPLACE(REPLACE(JSON_UNQUOTE(JSON_EXTRACT(NEW.field_values, CONCAT('$."', field_keys.field_key, '"'))), '-', ''), '+', ''), '.', '')) < inv_fields.min_length)
              OR
              (inv_fields.max_length IS NOT NULL
                AND CHAR_LENGTH(REPLACE(REPLACE(REPLACE(JSON_UNQUOTE(JSON_EXTRACT(NEW.field_values, CONCAT('$."', field_keys.field_key, '"'))), '-', ''), '+', ''), '.', '')) > inv_fields.max_length)
              OR
              (inv_fields.min_value IS NOT NULL
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(NEW.field_values, CONCAT('$."', field_keys.field_key, '"'))) AS DECIMAL(65,10)) < inv_fields.min_value)
              OR
              (inv_fields.max_value IS NOT NULL
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(NEW.field_values, CONCAT('$."', field_keys.field_key, '"'))) AS DECIMAL(65,10)) > inv_fields.max_value)
            )
          )
        )
    ) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Custom field values violate inventory field constraints';
    END IF;
    
    END IF;
END
  SQL

end
