category_names = %w[Equipment Furniture Book Other]
missing_names = category_names - Category.where(name: category_names).pluck(:name)
Category.insert_all(missing_names.map { |name| { name: name } }) if missing_names.any?
