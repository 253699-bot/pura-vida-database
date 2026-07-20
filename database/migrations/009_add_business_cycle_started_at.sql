-- Migration 009: track the start timestamp of the current open business cycle.
-- Non-destructive: preserves ESTADO_DIA and PEDIDOS history and does not modify previous migrations.

SET NAMES utf8mb4;
SET time_zone = '+00:00';

SET @pv_009_estado_ciclo_exists := (
  SELECT COUNT(*)
  FROM `INFORMATION_SCHEMA`.`COLUMNS`
  WHERE `TABLE_SCHEMA` = DATABASE()
    AND UPPER(`TABLE_NAME`) = 'ESTADO_DIA'
    AND UPPER(`COLUMN_NAME`) = 'CICLO_INICIADO_EN'
);

SET @pv_009_add_column_sql := IF(
  @pv_009_estado_ciclo_exists = 0,
  'ALTER TABLE `ESTADO_DIA` ADD COLUMN `Ciclo_iniciado_en` TIMESTAMP NULL DEFAULT NULL COMMENT ''Inicio del ciclo operativo abierto actual; se actualiza al abrir la fonda.'' AFTER `Actualizado_en`',
  'SELECT ''ESTADO_DIA.Ciclo_iniciado_en ya existe; se omite ALTER TABLE.'' AS info'
);

PREPARE pv_009_add_column_stmt FROM @pv_009_add_column_sql;
EXECUTE pv_009_add_column_stmt;
DEALLOCATE PREPARE pv_009_add_column_stmt;

UPDATE `ESTADO_DIA`
SET `Ciclo_iniciado_en` = COALESCE(`Actualizado_en`, `Creado_en`)
WHERE `Abierto` = TRUE
  AND `Ciclo_iniciado_en` IS NULL;

SET @pv_009_ciclo_index_exists := (
  SELECT COUNT(*)
  FROM `INFORMATION_SCHEMA`.`STATISTICS`
  WHERE `TABLE_SCHEMA` = DATABASE()
    AND UPPER(`TABLE_NAME`) = 'ESTADO_DIA'
    AND `INDEX_NAME` = 'idx_estado_dia_ciclo_iniciado_en'
);

SET @pv_009_create_index_sql := IF(
  @pv_009_ciclo_index_exists = 0,
  'CREATE INDEX `idx_estado_dia_ciclo_iniciado_en` ON `ESTADO_DIA` (`Ciclo_iniciado_en`)',
  'SELECT ''ESTADO_DIA.idx_estado_dia_ciclo_iniciado_en ya existe; se omite CREATE INDEX.'' AS info'
);

PREPARE pv_009_create_index_stmt FROM @pv_009_create_index_sql;
EXECUTE pv_009_create_index_stmt;
DEALLOCATE PREPARE pv_009_create_index_stmt;

SELECT
  `COLUMN_NAME`,
  `DATA_TYPE`,
  `IS_NULLABLE`
FROM `INFORMATION_SCHEMA`.`COLUMNS`
WHERE `TABLE_SCHEMA` = DATABASE()
  AND UPPER(`TABLE_NAME`) = 'ESTADO_DIA'
  AND UPPER(`COLUMN_NAME`) = 'CICLO_INICIADO_EN';