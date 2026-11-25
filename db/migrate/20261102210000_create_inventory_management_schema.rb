class CreateInventoryManagementSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.string :name, null: false, collation: "utf8mb4_bin"
      t.integer :taggings_count, default: 0
      t.timestamps
    end
    add_index :tags, :name, unique: true

    create_table :taggings do |t|
      t.references :tag, null: false, foreign_key: { to_table: :tags, on_delete: :cascade }
      t.references :taggable, polymorphic: true, null: false
      t.references :tagger, polymorphic: true
      t.string :context, limit: 128
      t.string :tenant, limit: 128
      t.datetime :created_at
    end
    add_index :taggings, %i[taggable_id taggable_type context], name: "taggings_taggable_context_idx"
    add_index :taggings, %i[taggable_id taggable_type tagger_id context], name: "taggings_idy"
    add_index :taggings, %i[tag_id taggable_id taggable_type context tagger_id tagger_type],
              unique: true, name: "taggings_idx"

    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.boolean :admin, null: false, default: false
      t.datetime :blocked_at
      t.string :language, null: false, default: "en"
      t.string :theme, null: false, default: "light"
      t.datetime :remember_created_at
      t.integer :sign_in_count, null: false, default: 0
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string :current_sign_in_ip
      t.string :last_sign_in_ip
      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :name

    create_table :identities do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :provider, null: false
      t.string :uid, null: false
      t.timestamps
    end
    add_index :identities, %i[provider uid], unique: true

    create_table :categories do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :categories, :name, unique: true

    create_table :inventories do |t|
      t.string :title, null: false
      t.longtext :description
      t.references :category, null: false, foreign_key: { on_delete: :restrict }
      t.references :creator, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.string :image_url, limit: 2048
      t.boolean :public, null: false, default: false
      t.json :custom_id_format, null: false
      t.integer :items_count, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :inventories, :title
    add_index :inventories, :created_at
    add_index :inventories, :items_count

    create_table :inventory_fields do |t|
      t.references :inventory, null: false, foreign_key: { on_delete: :cascade }
      t.string :title, null: false
      t.text :description
      t.string :field_type, null: false
      t.boolean :show_in_table, null: false, default: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :inventory_fields, %i[inventory_id position]

    create_table :inventory_accesses do |t|
      t.references :inventory, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :inventory_accesses, %i[inventory_id user_id], unique: true

    create_table :items do |t|
      t.references :inventory, null: false, foreign_key: { on_delete: :cascade }
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :custom_id, null: false
      t.integer :custom_sequence
      t.json :field_values, null: false
      t.integer :likes_count, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :items, %i[inventory_id custom_id], unique: true
    add_index :items, %i[inventory_id created_at]
    add_index :items, :custom_sequence

    create_table :messages do |t|
      t.references :inventory, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.text :content, null: false
      t.timestamps
    end
    add_index :messages, %i[inventory_id created_at]

    create_table :likes do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :item, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :likes, %i[user_id item_id], unique: true

    create_table :search_documents do |t|
      t.string :searchable_type, null: false
      t.bigint :searchable_id, null: false
      t.string :title, null: false
      t.longtext :body
      t.string :subtitle
      t.timestamps
    end
    add_index :search_documents, %i[searchable_type searchable_id], unique: true
    add_index :search_documents, %i[title body], type: :fulltext,
                                                name: "index_search_documents_on_title_and_body"
  end
end
