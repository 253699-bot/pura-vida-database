-- Migration 006: complete the database support required by the admin flows.
-- Target: MySQL 8.0.16+.
-- Apply exactly once after completing the applicable 001-005 legacy path;
-- migrations 004 and 005 remain conditional on their own documented preflight.
-- Do not apply this migration to a database created from the final schema.sql,
-- because that schema already contains this migration's resulting structure.
--
-- MySQL DDL causes implicit commits. This script performs all non-destructive
-- guards before the first permanent ALTER and never deletes historical rows.
-- Run the mysql client without --force so a failed guard stops the batch.

SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- ---------------------------------------------------------------------------
-- Preflight. The temporary guard aborts before permanent DDL when the expected
-- 001-005 baseline is incomplete, 006 was already/partially applied, or more
-- than one public configuration row exists. The last case requires a manual
-- merge decision; this migration deliberately does not delete either row.
-- ---------------------------------------------------------------------------

SET @pv_006_tablas_requeridas := (
  SELECT COUNT(DISTINCT UPPER(`TABLE_NAME`))
  FROM `information_schema`.`TABLES`
  WHERE `TABLE_SCHEMA` = DATABASE()
    AND UPPER(`TABLE_NAME`) IN (
      'CARRITO_ITEMS',
      'CONFIGURACION_NEGOCIO',
      'DETALLE_PEDIDO',
      'MENU_DIA',
      'NOTIFICACIONES',
      'PEDIDOS',
      'REPORTES_SEMANALES',
      'VENTAS'
    )
);

SET @pv_006_ventas_estado := (
  SELECT COUNT(*)
  FROM `information_schema`.`COLUMNS`
  WHERE `TABLE_SCHEMA` = DATABASE()
    AND UPPER(`TABLE_NAME`) = 'VENTAS'
    AND UPPER(`COLUMN_NAME`) = 'ESTADO'
);

SET @pv_006_ventas_pedido_nullable := (
  SELECT COUNT(*)
  FROM `information_schema`.`COLUMNS`
  WHERE `TABLE_SCHEMA` = DATABASE()
    AND UPPER(`TABLE_NAME`) = 'VENTAS'
    AND UPPER(`COLUMN_NAME`) = 'ID_PEDIDO'
    AND `IS_NULLABLE` = 'YES'
);

SET @pv_006_notificaciones_tipo := (
  SELECT COUNT(*)
  FROM `information_schema`.`COLUMNS`
  WHERE `TABLE_SCHEMA` = DATABASE()
    AND UPPER(`TABLE_NAME`) = 'NOTIFICACIONES'
    AND UPPER(`COLUMN_NAME`) = 'TIPO'
);

SET @pv_006_pedidos_finalizado := (
  SELECT COUNT(*)
  FROM `information_schema`.`COLUMNS`
  WHERE `TABLE_SCHEMA` = DATABASE()
    AND UPPER(`TABLE_NAME`) = 'PEDIDOS'
    AND UPPER(`COLUMN_NAME`) = 'ESTADO'
    AND LOCATE('finalizado', LOWER(`COLUMN_TYPE`)) > 0
);

SET @pv_006_fks_detalle_existentes := (
  SELECT COUNT(*)
  FROM `information_schema`.`TABLE_CONSTRAINTS`
  WHERE `CONSTRAINT_SCHEMA` = DATABASE()
    AND UPPER(`TABLE_NAME`) = 'DETALLE_PEDIDO'
    AND `CONSTRAINT_TYPE` = 'FOREIGN KEY'
    AND LOWER(`CONSTRAINT_NAME`) IN (
      'fk_detalle_pedido_id_menu',
      'fk_detalle_pedido_id_pedido'
    )
);

SET @pv_006_marcadores_existentes := (
  SELECT COUNT(*)
  FROM `information_schema`.`COLUMNS`
  WHERE `TABLE_SCHEMA` = DATABASE()
    AND (
      (UPPER(`TABLE_NAME`) = 'MENU_DIA' AND UPPER(`COLUMN_NAME`) = 'PUBLICADO')
      OR (UPPER(`TABLE_NAME`) = 'PEDIDOS' AND UPPER(`COLUMN_NAME`) IN ('CANCELADO_POR', 'CANCELADO_EN'))
      OR (UPPER(`TABLE_NAME`) = 'DETALLE_PEDIDO' AND UPPER(`COLUMN_NAME`) = 'ID_VENTA')
      OR (UPPER(`TABLE_NAME`) = 'VENTAS' AND UPPER(`COLUMN_NAME`) = 'CLAVE_IDEMPOTENCIA')
      OR (UPPER(`TABLE_NAME`) = 'CONFIGURACION_NEGOCIO' AND UPPER(`COLUMN_NAME`) = 'SINGLETON_KEY')
      OR (UPPER(`TABLE_NAME`) = 'REPORTES_SEMANALES' AND UPPER(`COLUMN_NAME`) IN ('RESUMEN_JSON', 'VERSION_FORMATO'))
    )
);

SET @pv_006_configuraciones_existentes := (
  SELECT COUNT(*)
  FROM `CONFIGURACION_NEGOCIO`
);

SET @pv_006_detalles_sin_pedido := (
  SELECT COUNT(*)
  FROM `DETALLE_PEDIDO`
  WHERE `Id_pedido` IS NULL
);

SET @pv_006_ventas_fuente_pedido_invalidas := (
  SELECT COUNT(*)
  FROM `VENTAS`
  WHERE (`Fuente` = 'manual_fonda' AND `Id_pedido` IS NOT NULL)
     OR (`Fuente` = 'remota' AND `Id_pedido` IS NULL)
);

SELECT
  @pv_006_tablas_requeridas AS `tablas_requeridas_encontradas`,
  @pv_006_ventas_estado AS `ventas_estado_encontrado`,
  @pv_006_ventas_pedido_nullable AS `ventas_id_pedido_nullable`,
  @pv_006_notificaciones_tipo AS `notificaciones_tipo_encontrado`,
  @pv_006_pedidos_finalizado AS `pedidos_finalizado_encontrado`,
  @pv_006_fks_detalle_existentes AS `fks_detalle_encontradas`,
  @pv_006_marcadores_existentes AS `marcadores_006_existentes`,
  @pv_006_configuraciones_existentes AS `configuraciones_existentes`,
  @pv_006_detalles_sin_pedido AS `detalles_legacy_sin_pedido`,
  @pv_006_ventas_fuente_pedido_invalidas AS `ventas_fuente_pedido_invalidas`;

DROP TEMPORARY TABLE IF EXISTS `_PV_006_PREFLIGHT`;

CREATE TEMPORARY TABLE `_PV_006_PREFLIGHT` (
  `Comprobacion` VARCHAR(100) NOT NULL,
  `Valida` TINYINT NOT NULL,
  PRIMARY KEY (`Comprobacion`),
  CONSTRAINT `chk_pv_006_preflight_valida`
    CHECK (`Valida` = 1)
) ENGINE=InnoDB;

INSERT INTO `_PV_006_PREFLIGHT` (`Comprobacion`, `Valida`)
VALUES
  ('tablas requeridas de 001-005', IF(@pv_006_tablas_requeridas = 8, 1, 0)),
  ('VENTAS.Estado de 002', IF(@pv_006_ventas_estado = 1, 1, 0)),
  ('VENTAS.Id_pedido nullable de 002', IF(@pv_006_ventas_pedido_nullable = 1, 1, 0)),
  ('NOTIFICACIONES.Tipo de 004', IF(@pv_006_notificaciones_tipo = 1, 1, 0)),
  ('PEDIDOS.finalizado de 005', IF(@pv_006_pedidos_finalizado = 1, 1, 0)),
  ('FK legacy esperadas en DETALLE_PEDIDO', IF(@pv_006_fks_detalle_existentes = 2, 1, 0)),
  ('006 no aplicada previamente', IF(@pv_006_marcadores_existentes = 0, 1, 0)),
  ('CONFIGURACION_NEGOCIO tiene maximo una fila', IF(@pv_006_configuraciones_existentes <= 1, 1, 0)),
  ('detalle legacy conserva Id_pedido', IF(@pv_006_detalles_sin_pedido = 0, 1, 0)),
  ('ventas cumplen Fuente e Id_pedido', IF(@pv_006_ventas_fuente_pedido_invalidas = 0, 1, 0));

DROP TEMPORARY TABLE `_PV_006_PREFLIGHT`;

-- Existing menu rows were already public under the legacy model. Add TRUE to
-- preserve that behavior, then make FALSE the default for newly drafted rows.
ALTER TABLE `MENU_DIA`
  ADD COLUMN `Publicado` BOOLEAN NOT NULL DEFAULT TRUE
    COMMENT 'TRUE cuando la fila puede exponerse en los menus publicos.'
    AFTER `Precio_dia`,
  ADD KEY `idx_menu_dia_fecha_publicado` (`Fecha`, `Publicado`);

ALTER TABLE `MENU_DIA`
  MODIFY `Publicado` BOOLEAN NOT NULL DEFAULT FALSE
    COMMENT 'TRUE cuando la fila puede exponerse en los menus publicos.';

ALTER TABLE `PEDIDOS`
  ADD COLUMN `Cancelado_por` INT NULL
    COMMENT 'Usuario encargada que cancelo un pedido previamente aceptado.'
    AFTER `Respondido_en`,
  ADD COLUMN `Cancelado_en` TIMESTAMP NULL DEFAULT NULL
    AFTER `Cancelado_por`,
  ADD KEY `idx_pedidos_cancelado_por` (`Cancelado_por`),
  ADD CONSTRAINT `fk_pedidos_cancelado_por`
    FOREIGN KEY (`Cancelado_por`) REFERENCES `USUARIOS` (`Id_usuario`)
    ON UPDATE CASCADE
    ON DELETE SET NULL;

ALTER TABLE `VENTAS`
  ADD COLUMN `Clave_idempotencia`
    VARCHAR(100) CHARACTER SET ascii COLLATE ascii_bin NULL
    COMMENT 'Clave por encargada para reintentar una venta manual sin duplicarla.'
    AFTER `Estado`,
  ADD UNIQUE KEY `uk_ventas_registrado_por_clave_idempotencia`
    (`Registrado_por`, `Clave_idempotencia`),
  ADD CONSTRAINT `chk_ventas_clave_idempotencia_fuente`
    CHECK (`Clave_idempotencia` IS NULL OR `Fuente` = 'manual_fonda');

-- Id_pedido, Id_venta and Id_menu participate in CHECK constraints. Their FKs
-- therefore use RESTRICT actions, avoiding MySQL's CHECK/referential-action
-- incompatibility and protecting the historical parent rows.
-- The unique key also provides the supporting index for the Id_venta FK.
-- 1. Eliminar primero las llaves foráneas existentes
ALTER TABLE `DETALLE_PEDIDO`
  DROP FOREIGN KEY `fk_detalle_pedido_id_pedido`,
  DROP FOREIGN KEY `fk_detalle_pedido_id_menu`;

-- 2. Modificar la estructura de la tabla
ALTER TABLE `DETALLE_PEDIDO`
  MODIFY `Id_pedido` INT NULL,
  ADD COLUMN `Id_venta` INT NULL AFTER `Id_pedido`,
  ADD UNIQUE KEY `uk_detalle_pedido_venta_menu` (`Id_venta`, `Id_menu`);

-- 3. Crear nuevamente las relaciones y validaciones
ALTER TABLE `DETALLE_PEDIDO`
  ADD CONSTRAINT `fk_detalle_pedido_id_pedido`
    FOREIGN KEY (`Id_pedido`)
    REFERENCES `PEDIDOS` (`Id_pedido`)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  ADD CONSTRAINT `fk_detalle_pedido_id_venta`
    FOREIGN KEY (`Id_venta`)
    REFERENCES `VENTAS` (`Id_venta`)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  ADD CONSTRAINT `fk_detalle_pedido_id_menu`
    FOREIGN KEY (`Id_menu`)
    REFERENCES `MENU_DIA` (`Id_menu`)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  ADD CONSTRAINT `chk_detalle_un_solo_padre`
    CHECK (
      (`Id_pedido` IS NOT NULL AND `Id_venta` IS NULL)
      OR
      (`Id_pedido` IS NULL AND `Id_venta` IS NOT NULL)
    ),

  ADD CONSTRAINT `chk_detalle_venta_manual_menu`
    CHECK (`Id_venta` IS NULL OR `Id_menu` IS NOT NULL);
-- A CHECK cannot inspect VENTAS.Fuente. The application transaction must use
-- Id_venta only for manual_fonda and Id_pedido for remote order details.

ALTER TABLE `CONFIGURACION_NEGOCIO`
  ADD COLUMN `Singleton_key` TINYINT NOT NULL DEFAULT 1
    COMMENT 'Clave constante que garantiza una unica configuracion publica.'
    AFTER `Id_config`,
  ADD UNIQUE KEY `uk_configuracion_negocio_singleton` (`Singleton_key`),
  ADD CONSTRAINT `chk_configuracion_negocio_singleton`
    CHECK (`Singleton_key` = 1);

INSERT INTO `CONFIGURACION_NEGOCIO` (`Singleton_key`)
SELECT 1
WHERE NOT EXISTS (
  SELECT 1
  FROM `CONFIGURACION_NEGOCIO`
);

ALTER TABLE `REPORTES_SEMANALES`
  ADD COLUMN `Resumen_json` JSON NULL
    COMMENT 'Snapshot estructurado usado para regenerar o auditar el reporte.'
    AFTER `Ruta_archivo`,
  ADD COLUMN `Version_formato` INT NOT NULL DEFAULT 1
    COMMENT 'Version del contrato almacenado en Resumen_json.'
    AFTER `Resumen_json`,
  ADD CONSTRAINT `chk_reportes_semanales_version_formato`
    CHECK (`Version_formato` > 0);

-- ---------------------------------------------------------------------------
-- Postflight. Counts documented as invalid must be 0. Legacy canceled orders
-- may legitimately report missing cancellation audit because 006 does not
-- invent historical actor/timestamp values.
-- ---------------------------------------------------------------------------

SELECT `TABLE_NAME`, `COLUMN_NAME`, `COLUMN_TYPE`, `IS_NULLABLE`, `COLUMN_DEFAULT`
FROM `information_schema`.`COLUMNS`
WHERE `TABLE_SCHEMA` = DATABASE()
  AND (
    (UPPER(`TABLE_NAME`) = 'MENU_DIA' AND UPPER(`COLUMN_NAME`) = 'PUBLICADO')
    OR (UPPER(`TABLE_NAME`) = 'PEDIDOS' AND UPPER(`COLUMN_NAME`) IN ('CANCELADO_POR', 'CANCELADO_EN'))
    OR (UPPER(`TABLE_NAME`) = 'DETALLE_PEDIDO' AND UPPER(`COLUMN_NAME`) IN ('ID_PEDIDO', 'ID_VENTA'))
    OR (UPPER(`TABLE_NAME`) = 'VENTAS' AND UPPER(`COLUMN_NAME`) = 'CLAVE_IDEMPOTENCIA')
    OR (UPPER(`TABLE_NAME`) = 'CONFIGURACION_NEGOCIO' AND UPPER(`COLUMN_NAME`) = 'SINGLETON_KEY')
    OR (UPPER(`TABLE_NAME`) = 'REPORTES_SEMANALES' AND UPPER(`COLUMN_NAME`) IN ('RESUMEN_JSON', 'VERSION_FORMATO'))
  )
ORDER BY `TABLE_NAME`, `ORDINAL_POSITION`;

SELECT `CONSTRAINT_NAME`, `UPDATE_RULE`, `DELETE_RULE`
FROM `information_schema`.`REFERENTIAL_CONSTRAINTS`
WHERE `CONSTRAINT_SCHEMA` = DATABASE()
  AND UPPER(`TABLE_NAME`) = 'DETALLE_PEDIDO'
  AND LOWER(`CONSTRAINT_NAME`) IN (
    'fk_detalle_pedido_id_menu',
    'fk_detalle_pedido_id_pedido',
    'fk_detalle_pedido_id_venta'
  )
ORDER BY `CONSTRAINT_NAME`;

SELECT COUNT(*) AS `configuraciones_finales`
FROM `CONFIGURACION_NEGOCIO`;

SELECT COUNT(*) AS `configuraciones_singleton_invalidas`
FROM `CONFIGURACION_NEGOCIO`
WHERE `Singleton_key` <> 1;

SELECT COUNT(*) AS `detalles_con_padre_invalido`
FROM `DETALLE_PEDIDO`
WHERE NOT (
  (`Id_pedido` IS NOT NULL AND `Id_venta` IS NULL)
  OR
  (`Id_pedido` IS NULL AND `Id_venta` IS NOT NULL)
);

SELECT COUNT(*) AS `detalles_manuales_sin_menu`
FROM `DETALLE_PEDIDO`
WHERE `Id_venta` IS NOT NULL
  AND `Id_menu` IS NULL;

SELECT COUNT(*) AS `detalles_id_venta_en_ventas_no_manuales`
FROM `DETALLE_PEDIDO` AS `d`
INNER JOIN `VENTAS` AS `v`
  ON `v`.`Id_venta` = `d`.`Id_venta`
WHERE `v`.`Fuente` <> 'manual_fonda';

SELECT COUNT(*) AS `claves_idempotencia_en_ventas_no_manuales`
FROM `VENTAS`
WHERE `Clave_idempotencia` IS NOT NULL
  AND `Fuente` <> 'manual_fonda';

SELECT COUNT(*) AS `claves_idempotencia_duplicadas`
FROM (
  SELECT `Registrado_por`, `Clave_idempotencia`
  FROM `VENTAS`
  WHERE `Clave_idempotencia` IS NOT NULL
  GROUP BY `Registrado_por`, `Clave_idempotencia`
  HAVING COUNT(*) > 1
) AS `duplicadas`;

SELECT COUNT(*) AS `versiones_reporte_invalidas`
FROM `REPORTES_SEMANALES`
WHERE `Version_formato` <= 0;

SELECT `Publicado`, COUNT(*) AS `filas_menu`
FROM `MENU_DIA`
GROUP BY `Publicado`
ORDER BY `Publicado`;

SELECT COUNT(*) AS `pedidos_cancelados_legacy_sin_auditoria`
FROM `PEDIDOS`
WHERE `Estado` = 'cancelado'
  AND (`Cancelado_por` IS NULL OR `Cancelado_en` IS NULL);
