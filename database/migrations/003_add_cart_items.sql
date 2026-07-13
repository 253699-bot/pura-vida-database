-- Migration 003: create temporary cart items for authenticated users.
-- Target: MySQL 8.0.16+.
-- Apply after the existing schema and migration 002. Do not run automatically.

SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- Cart items are temporary pre-order data. They are physically deleted by the
-- application and are intentionally not part of PEDIDOS, VENTAS or reporting.
CREATE TABLE `CARRITO_ITEMS` (
  `Id_carrito_item` INT NOT NULL AUTO_INCREMENT,
  `Id_usuario` INT NOT NULL,
  `Id_platillo` INT NOT NULL,
  `Cantidad` INT NOT NULL,
  `Precio_unitario` DECIMAL(8,2) NOT NULL
    COMMENT 'Snapshot del Precio_base al agregar el platillo al carrito.',
  `Creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `Actualizado_en` TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id_carrito_item`),
  UNIQUE KEY `uk_carrito_items_usuario_platillo` (`Id_usuario`, `Id_platillo`),
  KEY `idx_carrito_items_usuario` (`Id_usuario`),
  KEY `idx_carrito_items_platillo` (`Id_platillo`),
  CONSTRAINT `fk_carrito_items_usuario`
    FOREIGN KEY (`Id_usuario`) REFERENCES `USUARIOS` (`Id_usuario`)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT `fk_carrito_items_platillo`
    FOREIGN KEY (`Id_platillo`) REFERENCES `PLATILLOS` (`Id_platillo`)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT `chk_carrito_items_cantidad`
    CHECK (`Cantidad` > 0),
  CONSTRAINT `chk_carrito_items_precio_unitario`
    CHECK (`Precio_unitario` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Items temporales previos a la confirmacion de un pedido; pueden eliminarse fisicamente.';
