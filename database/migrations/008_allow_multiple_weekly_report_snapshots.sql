-- Migration 008: allow multiple immutable weekly report snapshots for the same week.
-- Non-destructive: preserves existing REPORTES_SEMANALES rows and does not modify migration 006.

SET NAMES utf8mb4;
SET time_zone = '+00:00';

SET @pv_008_unique_week_index_exists := (
  SELECT COUNT(*)
  FROM `INFORMATION_SCHEMA`.`STATISTICS`
  WHERE `TABLE_SCHEMA` = DATABASE()
    AND UPPER(`TABLE_NAME`) = 'REPORTES_SEMANALES'
    AND `INDEX_NAME` = 'uk_reportes_semanales_semana'
    AND `NON_UNIQUE` = 0
);

SET @pv_008_drop_unique_sql := IF(
  @pv_008_unique_week_index_exists > 0,
  'ALTER TABLE `REPORTES_SEMANALES` DROP INDEX `uk_reportes_semanales_semana`',
  'SELECT ''REPORTES_SEMANALES.uk_reportes_semanales_semana no existe como índice único; se omite DROP INDEX.'' AS info'
);

PREPARE pv_008_drop_unique_stmt FROM @pv_008_drop_unique_sql;
EXECUTE pv_008_drop_unique_stmt;
DEALLOCATE PREPARE pv_008_drop_unique_stmt;

SET @pv_008_week_generated_index_exists := (
  SELECT COUNT(*)
  FROM `INFORMATION_SCHEMA`.`STATISTICS`
  WHERE `TABLE_SCHEMA` = DATABASE()
    AND UPPER(`TABLE_NAME`) = 'REPORTES_SEMANALES'
    AND `INDEX_NAME` = 'idx_reportes_semanales_semana_generado'
);

SET @pv_008_create_index_sql := IF(
  @pv_008_week_generated_index_exists = 0,
  'CREATE INDEX `idx_reportes_semanales_semana_generado` ON `REPORTES_SEMANALES` (`Semana_inicio`, `Semana_fin`, `Generado_en`, `Id_reporte`)',
  'SELECT ''REPORTES_SEMANALES.idx_reportes_semanales_semana_generado ya existe; se omite CREATE INDEX.'' AS info'
);

PREPARE pv_008_create_index_stmt FROM @pv_008_create_index_sql;
EXECUTE pv_008_create_index_stmt;
DEALLOCATE PREPARE pv_008_create_index_stmt;

SELECT
  `INDEX_NAME`,
  `NON_UNIQUE`,
  `SEQ_IN_INDEX`,
  `COLUMN_NAME`
FROM `INFORMATION_SCHEMA`.`STATISTICS`
WHERE `TABLE_SCHEMA` = DATABASE()
  AND UPPER(`TABLE_NAME`) = 'REPORTES_SEMANALES'
  AND `INDEX_NAME` IN ('uk_reportes_semanales_semana', 'idx_reportes_semanales_semana_generado')
ORDER BY `INDEX_NAME`, `SEQ_IN_INDEX`;