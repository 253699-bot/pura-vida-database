-- Migration 007: add nullable image key/url for dish photographs.
-- Non-destructive: preserves all existing PLATILLOS rows and does not modify migration 006.

SET @pv_007_platillos_imagen_exists := (
  SELECT COUNT(*)
  FROM `INFORMATION_SCHEMA`.`COLUMNS`
  WHERE `TABLE_SCHEMA` = DATABASE()
    AND UPPER(`TABLE_NAME`) = 'PLATILLOS'
    AND UPPER(`COLUMN_NAME`) = 'IMAGEN_URL'
);

SET @pv_007_sql := IF(
  @pv_007_platillos_imagen_exists = 0,
  'ALTER TABLE `PLATILLOS` ADD COLUMN `Imagen_url` TEXT NULL COMMENT ''Clave publica/segura de la imagen del platillo almacenada fuera de la base de datos.'' AFTER `Precio_base`',
  'SELECT ''PLATILLOS.Imagen_url ya existe; se omite ALTER TABLE.'' AS info'
);

PREPARE pv_007_stmt FROM @pv_007_sql;
EXECUTE pv_007_stmt;
DEALLOCATE PREPARE pv_007_stmt;

SELECT
  `COLUMN_NAME`,
  `DATA_TYPE`,
  `IS_NULLABLE`
FROM `INFORMATION_SCHEMA`.`COLUMNS`
WHERE `TABLE_SCHEMA` = DATABASE()
  AND UPPER(`TABLE_NAME`) = 'PLATILLOS'
  AND UPPER(`COLUMN_NAME`) = 'IMAGEN_URL';