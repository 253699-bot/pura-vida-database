-- Migration 001: add VENTAS and move Fuente out of PEDIDOS.
-- Target: MySQL 8 / MariaDB 10.x.
-- Run this against an existing PuraVida database after making a backup.
-- DDL statements in MySQL/MariaDB cause implicit commits, so this script favors
-- idempotent checks over a single transaction.

SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- 1) Create VENTAS if it is not present yet.
CREATE TABLE IF NOT EXISTS `VENTAS` (
  `Id_venta` INT NOT NULL AUTO_INCREMENT,
  `Id_pedido` INT NOT NULL,
  `Fuente` ENUM('manual_fonda', 'remota') NOT NULL
    COMMENT 'manual_fonda = venta presencial capturada por encargada; remota = pedido realizado desde la app.',
  `Fecha` DATE NOT NULL,
  `Hora` TIME NOT NULL,
  `Total` DECIMAL(10,2) NOT NULL,
  `Registrado_por` INT NULL COMMENT 'Usuario encargada que registro o confirmo la venta.',
  `Observaciones` TEXT NULL,
  `Creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id_venta`),
  UNIQUE KEY `idx_ventas_id_pedido` (`Id_pedido`),
  KEY `idx_ventas_fecha` (`Fecha`),
  KEY `idx_ventas_fuente_fecha` (`Fuente`, `Fecha`),
  KEY `idx_ventas_registrado_por` (`Registrado_por`),
  CONSTRAINT `fk_ventas_id_pedido`
    FOREIGN KEY (`Id_pedido`) REFERENCES `PEDIDOS` (`Id_pedido`)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT `fk_ventas_registrado_por`
    FOREIGN KEY (`Registrado_por`) REFERENCES `USUARIOS` (`Id_usuario`)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
  CONSTRAINT `chk_ventas_total`
    CHECK (`Total` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Ventas efectivas generadas por pedidos aceptados; distingue fuente manual en fonda o remota sin duplicar el detalle del pedido.';

-- 2) Copy historical accepted pedidos into VENTAS before removing PEDIDOS.Fuente.
--    The dynamic statement keeps the migration re-runnable if the old column
--    was already removed in a previous attempt.
SET @pedidos_tiene_fuente := (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND UPPER(TABLE_NAME) = 'PEDIDOS'
    AND UPPER(COLUMN_NAME) = 'FUENTE'
);

SET @sql_migrar_ventas := IF(
  @pedidos_tiene_fuente > 0,
  'INSERT INTO `VENTAS` (
     `Id_pedido`,
     `Fuente`,
     `Fecha`,
     `Hora`,
     `Total`,
     `Registrado_por`,
     `Observaciones`,
     `Creado_en`
   )
   SELECT
     `p`.`Id_pedido`,
     CASE `p`.`Fuente`
       WHEN ''pedido_app'' THEN ''remota''
       WHEN ''venta_manual'' THEN ''manual_fonda''
     END AS `Fuente`,
     `p`.`Fecha`,
     `p`.`Hora`,
     `p`.`Total`,
     `p`.`Respondido_por`,
     `p`.`Observaciones`,
     `p`.`Creado_en`
   FROM `PEDIDOS` AS `p`
   WHERE `p`.`Estado` = ''aceptado''
     AND `p`.`Fuente` IN (''pedido_app'', ''venta_manual'')
     AND NOT EXISTS (
       SELECT 1
       FROM `VENTAS` AS `v`
       WHERE `v`.`Id_pedido` = `p`.`Id_pedido`
     )',
  'SELECT ''PEDIDOS.Fuente no existe; se omite la migracion de datos historicos.'' AS info'
);

PREPARE stmt FROM @sql_migrar_ventas;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 3) Remove the former consolidated sales view. Sales queries must read
--    directly from VENTAS with JOINs to PEDIDOS and DETALLE_PEDIDO as needed.
DROP VIEW IF EXISTS `VW_VENTAS_CONSOLIDADAS`;

-- 4) Drop old PEDIDOS.Fuente dependencies only when they exist.
--    MariaDB 10.4 uses DROP CONSTRAINT for CHECK constraints; MySQL 8 uses
--    DROP CHECK. The dynamic branch chooses the local syntax.
SET @es_mariadb := LOCATE('MariaDB', VERSION()) > 0;
SET @drop_check_clause := IF(@es_mariadb, 'DROP CONSTRAINT', 'DROP CHECK');

SET @sql_drop_chk_cliente := IF(
  (
    SELECT COUNT(*)
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE()
      AND UPPER(TABLE_NAME) = 'PEDIDOS'
      AND UPPER(CONSTRAINT_NAME) = 'CHK_PEDIDOS_CLIENTE_POR_FUENTE'
  ) > 0,
  CONCAT('ALTER TABLE `PEDIDOS` ', @drop_check_clause, ' `chk_pedidos_cliente_por_fuente`'),
  'SELECT ''chk_pedidos_cliente_por_fuente no existe; se omite.'' AS info'
);

PREPARE stmt FROM @sql_drop_chk_cliente;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql_drop_chk_manual := IF(
  (
    SELECT COUNT(*)
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE()
      AND UPPER(TABLE_NAME) = 'PEDIDOS'
      AND UPPER(CONSTRAINT_NAME) = 'CHK_PEDIDOS_VENTA_MANUAL_ACEPTADA'
  ) > 0,
  CONCAT('ALTER TABLE `PEDIDOS` ', @drop_check_clause, ' `chk_pedidos_venta_manual_aceptada`'),
  'SELECT ''chk_pedidos_venta_manual_aceptada no existe; se omite.'' AS info'
);

PREPARE stmt FROM @sql_drop_chk_manual;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql_drop_idx_fuente := IF(
  (
    SELECT COUNT(*)
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND UPPER(TABLE_NAME) = 'PEDIDOS'
      AND INDEX_NAME = 'idx_pedidos_fuente_estado_fecha'
  ) > 0,
  'DROP INDEX `idx_pedidos_fuente_estado_fecha` ON `PEDIDOS`',
  'SELECT ''idx_pedidos_fuente_estado_fecha no existe; se omite.'' AS info'
);

PREPARE stmt FROM @sql_drop_idx_fuente;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 5) Remove PEDIDOS.Fuente after the data copy and dependency cleanup.
SET @sql_drop_col_fuente := IF(
  @pedidos_tiene_fuente > 0,
  'ALTER TABLE `PEDIDOS` DROP COLUMN `Fuente`',
  'SELECT ''PEDIDOS.Fuente ya no existe; se omite DROP COLUMN.'' AS info'
);

PREPARE stmt FROM @sql_drop_col_fuente;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 6) Refresh comments that described sales as derived from PEDIDOS.Fuente or
--    PEDIDOS accepted rows. These statements do not alter stored business data.
ALTER TABLE `PEDIDOS`
  MODIFY `Estado` ENUM('pendiente', 'aceptado', 'rechazado', 'cancelado') NOT NULL DEFAULT 'pendiente'
    COMMENT 'Flujo operativo del pedido; Estado aceptado debe generar una venta efectiva en VENTAS.',
  MODIFY `Observaciones` TEXT NULL COMMENT 'Notas operativas del pedido.',
  COMMENT='Solicitudes operativas del sistema; los pedidos aceptados generan una venta efectiva en VENTAS.';

ALTER TABLE `METRICAS_PLATILLO_DIA`
  COMMENT='Metricas derivadas de PEDIDOS, VENTAS y DETALLE_PEDIDO; Cantidad_vendida y Total_generado deben calcularse desde VENTAS unidas al detalle del pedido.';

ALTER TABLE `METRICAS_HORA_PICO`
  COMMENT='Metricas de demanda por franja horaria calculadas desde VENTAS.';

ALTER TABLE `REPORTES_SEMANALES`
  MODIFY `Total_pedidos_app` INT NOT NULL DEFAULT 0
    COMMENT 'Ventas remotas con Fuente=remota dentro de la semana.',
  MODIFY `Total_ingresos` DECIMAL(10,2) NOT NULL DEFAULT 0.00
    COMMENT 'Ingresos calculados desde VENTAS.',
  COMMENT='Snapshot de reportes PDF; sus importes y conteos se calculan desde VENTAS, PEDIDOS y DETALLE_PEDIDO segun corresponda.';

-- 7) Post-migration checks. The last count should be 0 when every accepted
--    pedido could be migrated or already had a VENTAS row.
SELECT COUNT(*) AS pedidos_aceptados
FROM `PEDIDOS`
WHERE `Estado` = 'aceptado';

SELECT COUNT(*) AS ventas_de_pedidos_aceptados
FROM `VENTAS` AS `v`
INNER JOIN `PEDIDOS` AS `p`
  ON `p`.`Id_pedido` = `v`.`Id_pedido`
WHERE `p`.`Estado` = 'aceptado';

SELECT COUNT(*) AS pedidos_aceptados_sin_venta
FROM `PEDIDOS` AS `p`
LEFT JOIN `VENTAS` AS `v`
  ON `v`.`Id_pedido` = `p`.`Id_pedido`
WHERE `p`.`Estado` = 'aceptado'
  AND `v`.`Id_pedido` IS NULL;
