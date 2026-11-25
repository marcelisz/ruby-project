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
