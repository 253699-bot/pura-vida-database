-- Migration 002: allow independent manual sales and prepare logical cancellation.
-- Target: MySQL 8.0.16+.
-- Apply after migration 001, or to a database created from the current schema.
-- Review the preflight result and make a backup before execution.

SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- Preflight: this count must be 0. Existing manual_fonda rows linked to a
-- pedido require an explicit data decision before this migration can proceed.
SELECT COUNT(*) AS ventas_incompatibles_fuente_pedido
FROM `VENTAS`
WHERE (`Fuente` = 'manual_fonda' AND `Id_pedido` IS NOT NULL)
   OR (`Fuente` = 'remota' AND `Id_pedido` IS NULL);

-- MySQL 8 applies this InnoDB ALTER atomically. The pedido FK is recreated in
-- the same statement after making Id_pedido nullable for manual sales.
ALTER TABLE `VENTAS`
  DROP FOREIGN KEY `fk_ventas_id_pedido`,
  MODIFY `Id_pedido` INT NULL
    COMMENT 'NULL para venta manual_fonda; obligatorio para venta remota.',
  RENAME INDEX `idx_ventas_id_pedido` TO `uq_ventas_id_pedido`,
  ADD COLUMN `Estado` ENUM('activa', 'anulada') NOT NULL DEFAULT 'activa'
    COMMENT 'Estado logico de la venta; las anuladas se excluyen de reportes activos.'
    AFTER `Fuente`,
  ADD COLUMN `Motivo_anulacion` TEXT NULL
    AFTER `Observaciones`,
  ADD COLUMN `Anulada_en` TIMESTAMP NULL DEFAULT NULL
    AFTER `Motivo_anulacion`,
  ADD COLUMN `Id_usuario_anulo` INT NULL
    COMMENT 'Usuario encargada que realizo la anulacion logica.'
    AFTER `Anulada_en`,
  ADD KEY `idx_ventas_estado_fecha` (`Estado`, `Fecha`),
  ADD KEY `idx_ventas_usuario_anulo` (`Id_usuario_anulo`),
  ADD CONSTRAINT `fk_ventas_pedido`
    FOREIGN KEY (`Id_pedido`) REFERENCES `PEDIDOS` (`Id_pedido`)
    -- MySQL no permite que un CHECK use una columna con accion CASCADE.
    -- Los identificadores de pedido son inmutables, por lo que RESTRICT es adecuado.
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,
  ADD CONSTRAINT `fk_ventas_usuario_anulo`
    FOREIGN KEY (`Id_usuario_anulo`) REFERENCES `USUARIOS` (`Id_usuario`)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
  ADD CONSTRAINT `chk_ventas_fuente_id_pedido`
    CHECK (
      (`Fuente` = 'manual_fonda' AND `Id_pedido` IS NULL)
      OR
      (`Fuente` = 'remota' AND `Id_pedido` IS NOT NULL)
    ),
  ADD CONSTRAINT `chk_ventas_anulacion`
    CHECK (
      (
        `Estado` = 'activa'
        AND `Motivo_anulacion` IS NULL
        AND `Anulada_en` IS NULL
      )
      OR
      (
        `Estado` = 'anulada'
        AND NULLIF(TRIM(`Motivo_anulacion`), '') IS NOT NULL
        AND `Anulada_en` IS NOT NULL
      )
    );

-- Id_usuario_anulo se valida mediante FK y backend. No forma parte del CHECK
-- porque MySQL impide combinarlo con la accion ON DELETE SET NULL de su FK.

-- uq_ventas_id_pedido remains unique. MySQL permits multiple NULL values in a
-- unique index, so manual sales can coexist while each pedido has at most one
-- remote sale. Backend logic must additionally verify that the pedido exists
-- in estado aceptado before creating Fuente = 'remota'.

-- Post-migration verification; both counts should be 0.
SELECT COUNT(*) AS ventas_fuente_pedido_invalidas
FROM `VENTAS`
WHERE (`Fuente` = 'manual_fonda' AND `Id_pedido` IS NOT NULL)
   OR (`Fuente` = 'remota' AND `Id_pedido` IS NULL);

SELECT COUNT(*) AS ventas_anuladas_sin_datos
FROM `VENTAS`
WHERE `Estado` = 'anulada'
  AND (
    NULLIF(TRIM(`Motivo_anulacion`), '') IS NULL
    OR `Anulada_en` IS NULL
  );
