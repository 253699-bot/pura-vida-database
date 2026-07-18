-- Migration 004: complete the existing NOTIFICACIONES table for the internal
-- notifications MVP. This migration is intended for databases created from a
-- previous schema version, where NOTIFICACIONES already exists without Tipo.

ALTER TABLE `NOTIFICACIONES`
  ADD COLUMN `Tipo` VARCHAR(50) NULL AFTER `Id_pedido`;

-- Preserve existing rows before making Tipo mandatory. Legacy notifications do
-- not expose enough information to infer a more specific business event.
UPDATE `NOTIFICACIONES`
SET `Tipo` = 'sistema'
WHERE `Tipo` IS NULL;

ALTER TABLE `NOTIFICACIONES`
  MODIFY `Tipo` VARCHAR(50) NOT NULL,
  ADD KEY `idx_notificaciones_usuario_fecha`
    (`Id_usuario`, `Creado_en`, `Id_notificacion`);

-- Static/post-migration verification queries. They do not mutate data.
SELECT COUNT(*) AS notificaciones_sin_tipo
FROM `NOTIFICACIONES`
WHERE `Tipo` IS NULL OR TRIM(`Tipo`) = '';

SELECT `Id_usuario`, `Estado`, COUNT(*) AS total
FROM `NOTIFICACIONES`
GROUP BY `Id_usuario`, `Estado`;
