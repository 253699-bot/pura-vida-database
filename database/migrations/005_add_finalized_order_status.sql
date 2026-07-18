-- Migration 005: add the final operational state for accepted orders.
-- Apply after the sales migrations. This script is not executed automatically.

ALTER TABLE `PEDIDOS`
  MODIFY `Estado`
    ENUM('pendiente', 'aceptado', 'finalizado', 'rechazado', 'cancelado')
    NOT NULL DEFAULT 'pendiente'
    COMMENT 'Flujo operativo del pedido; aceptado y finalizado deben conservar una venta efectiva en VENTAS.',
  COMMENT='Solicitudes operativas; los pedidos aceptados pueden finalizarse y conservan su venta efectiva en VENTAS.';

-- Static/post-migration verification queries. They do not mutate data.
SELECT `COLUMN_TYPE`, `COLUMN_DEFAULT`, `IS_NULLABLE`
FROM `information_schema`.`COLUMNS`
WHERE `TABLE_SCHEMA` = DATABASE()
  AND `TABLE_NAME` = 'PEDIDOS'
  AND `COLUMN_NAME` = 'Estado';

SELECT `Estado`, COUNT(*) AS `total`
FROM `PEDIDOS`
GROUP BY `Estado`
ORDER BY `Estado`;

SELECT COUNT(*) AS `pedidos_finalizados_sin_venta`
FROM `PEDIDOS` AS `p`
LEFT JOIN `VENTAS` AS `v`
  ON `v`.`Id_pedido` = `p`.`Id_pedido`
WHERE `p`.`Estado` = 'finalizado'
  AND `v`.`Id_venta` IS NULL;
