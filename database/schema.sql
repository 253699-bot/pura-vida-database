-- PuraVida - esquema inicial MySQL 8
-- PEDIDOS conserva el flujo operativo; VENTAS representa las ventas efectivas generadas por pedidos finalizados o ventas manuales.
-- No se persiste una tabla o vista consolidada adicional; las ventas se consultan desde VENTAS
-- con JOIN hacia PEDIDOS y DETALLE_PEDIDO cuando corresponda.

SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE TABLE IF NOT EXISTS `USUARIOS` (
  `Id_usuario` INT NOT NULL AUTO_INCREMENT,
  `Nombre` VARCHAR(150) NOT NULL,
  `Correo` VARCHAR(255) NOT NULL,
  `Telefono` VARCHAR(20) NULL,
  `Password_hash` TEXT NOT NULL,
  `Rol` ENUM('cliente', 'encargada') NOT NULL,
  `Icono_perfil` TEXT NULL,
  `Notificaciones_act` BOOLEAN NOT NULL DEFAULT TRUE,
  `Activo` BOOLEAN NOT NULL DEFAULT TRUE,
  `Creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `Actualizado_en` TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id_usuario`),
  UNIQUE KEY `uk_usuarios_correo` (`Correo`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Usuarios autenticables del sistema; Rol distingue clientes y encargada.';

CREATE TABLE IF NOT EXISTS `CONFIGURACION_NEGOCIO` (
  `Id_config` INT NOT NULL AUTO_INCREMENT,
  `Singleton_key` TINYINT NOT NULL DEFAULT 1
    COMMENT 'Garantiza una sola fuente publica de configuracion.',
  `Nombre_fonda` VARCHAR(150) NOT NULL DEFAULT 'PuraVida',
  `Logo_url` TEXT NULL,
  `Direccion` TEXT NULL,
  `Horarios` TEXT NULL,
  `Telefono` VARCHAR(20) NULL,
  `Correo` VARCHAR(255) NULL,
  `Actualizado_por` INT NULL COMMENT 'Usuario que modifico la configuracion por ultima vez.',
  `Actualizado_en` TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id_config`),
  UNIQUE KEY `uk_configuracion_negocio_singleton` (`Singleton_key`),
  CONSTRAINT `fk_configuracion_negocio_actualizado_por`
    FOREIGN KEY (`Actualizado_por`) REFERENCES `USUARIOS` (`Id_usuario`)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
  CONSTRAINT `chk_configuracion_negocio_singleton`
    CHECK (`Singleton_key` = 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Fuente publica unica y editable de la fonda.';

INSERT INTO `CONFIGURACION_NEGOCIO` (`Singleton_key`, `Nombre_fonda`)
SELECT 1, 'PuraVida'
WHERE NOT EXISTS (SELECT 1 FROM `CONFIGURACION_NEGOCIO`);

CREATE TABLE IF NOT EXISTS `ESTADO_DIA` (
  `Id_estado` INT NOT NULL AUTO_INCREMENT,
  `Fecha` DATE NOT NULL,
  `Abierto` BOOLEAN NOT NULL,
  `Motivo_cierre` TEXT NULL,
  `Registrado_por` INT NOT NULL,
  `Creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `Actualizado_en` TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `Ciclo_iniciado_en` TIMESTAMP NULL DEFAULT NULL
    COMMENT 'Inicio del ciclo operativo abierto actual; se actualiza al abrir la fonda.',
  PRIMARY KEY (`Id_estado`),
  UNIQUE KEY `uk_estado_dia_fecha` (`Fecha`),
  KEY `idx_estado_dia_ciclo_iniciado_en` (`Ciclo_iniciado_en`),
  CONSTRAINT `fk_estado_dia_registrado_por`
    FOREIGN KEY (`Registrado_por`) REFERENCES `USUARIOS` (`Id_usuario`)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT `chk_estado_dia_motivo_cierre`
    CHECK (`Abierto` = TRUE OR `Motivo_cierre` IS NOT NULL)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Estado operativo diario de la fonda.';

CREATE TABLE IF NOT EXISTS `PLATILLOS` (
  `Id_platillo` INT NOT NULL AUTO_INCREMENT,
  `Nombre` VARCHAR(150) NOT NULL,
  `Descripcion` TEXT NULL,
  `Tipo_platillo` ENUM('platillo_fuerte', 'bebida', 'complemento', 'postre') NOT NULL,
  `Precio_base` DECIMAL(8,2) NOT NULL,
  `Imagen_url` TEXT NULL COMMENT 'Clave publica/segura de la imagen del platillo almacenada fuera de la base de datos.',
  `Activo` BOOLEAN NOT NULL DEFAULT TRUE,
  `Creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `Actualizado_en` TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id_platillo`),
  CONSTRAINT `chk_platillos_precio_base`
    CHECK (`Precio_base` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Catalogo normalizado de platillos ofrecidos.';

CREATE TABLE IF NOT EXISTS `MENU_DIA` (
  `Id_menu` INT NOT NULL AUTO_INCREMENT,
  `Fecha` DATE NOT NULL,
  `Id_platillo` INT NOT NULL,
  `Precio_dia` DECIMAL(8,2) NOT NULL,
  `Publicado` BOOLEAN NOT NULL DEFAULT FALSE
    COMMENT 'TRUE cuando la fila puede exponerse en los menus publicos.',
  `Creado_por` INT NOT NULL,
  `Creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id_menu`),
  UNIQUE KEY `uk_menu_dia_fecha_platillo` (`Fecha`, `Id_platillo`),
  KEY `idx_menu_dia_fecha_publicado` (`Fecha`, `Publicado`),
  KEY `idx_menu_dia_platillo` (`Id_platillo`),
  KEY `idx_menu_dia_creado_por` (`Creado_por`),
  CONSTRAINT `fk_menu_dia_platillo`
    FOREIGN KEY (`Id_platillo`) REFERENCES `PLATILLOS` (`Id_platillo`)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT `fk_menu_dia_creado_por`
    FOREIGN KEY (`Creado_por`) REFERENCES `USUARIOS` (`Id_usuario`)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT `chk_menu_dia_precio`
    CHECK (`Precio_dia` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Platillos publicados para una fecha especifica.';

CREATE TABLE IF NOT EXISTS `DISPONIBILIDAD_MENU` (
  `Id_disponibilidad` INT NOT NULL AUTO_INCREMENT,
  `Id_menu` INT NOT NULL,
  `Disponible` BOOLEAN NOT NULL DEFAULT TRUE,
  `Hora_publicacion` TIME NULL,
  `Hora_agotado` TIME NULL,
  `Actualizado_en` TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id_disponibilidad`),
  UNIQUE KEY `uk_disponibilidad_menu_id_menu` (`Id_menu`),
  CONSTRAINT `fk_disponibilidad_menu_id_menu`
    FOREIGN KEY (`Id_menu`) REFERENCES `MENU_DIA` (`Id_menu`)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Disponibilidad operacional de cada platillo publicado en el menu.';

CREATE TABLE IF NOT EXISTS `CARRITO_ITEMS` (
  `Id_carrito_item` INT NOT NULL AUTO_INCREMENT,
  `Id_usuario` INT NOT NULL,
  `Id_platillo` INT NOT NULL,
  `Cantidad` INT NOT NULL,
  `Precio_unitario` DECIMAL(8,2) NOT NULL
    COMMENT 'Snapshot del precio vigente al agregar el platillo al carrito.',
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
COMMENT='Items temporales previos al pedido; son los unicos datos operativos que pueden eliminarse fisicamente.';

CREATE TABLE IF NOT EXISTS `PEDIDOS` (
  `Id_pedido` INT NOT NULL AUTO_INCREMENT,
  `Id_cliente` INT NULL,
  `Fecha` DATE NOT NULL,
  `Hora` TIME NOT NULL,
  `Estado` ENUM('pendiente', 'aceptado', 'finalizado', 'rechazado', 'cancelado') NOT NULL DEFAULT 'pendiente'
    COMMENT 'Flujo operativo del pedido; la venta remota se genera al pasar correctamente a finalizado.',
  `Total` DECIMAL(10,2) NOT NULL,
  `Tiempo_espera_est` VARCHAR(100) NULL,
  `Motivo_rechazo` TEXT NULL,
  `Categoria_rechazo` ENUM('platillo_agotado', 'fonda_cerrada', 'pedido_fuera_de_horario', 'cantidad_no_disponible', 'otro') NULL,
  `Respondido_por` INT NULL,
  `Respondido_en` TIMESTAMP NULL DEFAULT NULL,
  `Cancelado_por` INT NULL,
  `Cancelado_en` TIMESTAMP NULL DEFAULT NULL,
  `Observaciones` TEXT NULL COMMENT 'Notas operativas del pedido.',
  `Creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id_pedido`),
  KEY `idx_pedidos_cliente` (`Id_cliente`),
  KEY `idx_pedidos_respondido_por` (`Respondido_por`),
  KEY `idx_pedidos_cancelado_por` (`Cancelado_por`),
  KEY `idx_pedidos_estado_fecha` (`Estado`, `Fecha`),
  CONSTRAINT `fk_pedidos_cliente`
    FOREIGN KEY (`Id_cliente`) REFERENCES `USUARIOS` (`Id_usuario`)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
  CONSTRAINT `fk_pedidos_respondido_por`
    FOREIGN KEY (`Respondido_por`) REFERENCES `USUARIOS` (`Id_usuario`)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
  CONSTRAINT `fk_pedidos_cancelado_por`
    FOREIGN KEY (`Cancelado_por`) REFERENCES `USUARIOS` (`Id_usuario`)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
  CONSTRAINT `chk_pedidos_total`
    CHECK (`Total` >= 0),
  CONSTRAINT `chk_pedidos_rechazo_estado`
    CHECK (`Estado` = 'rechazado' OR (`Motivo_rechazo` IS NULL AND `Categoria_rechazo` IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Solicitudes operativas; los pedidos aceptados pueden finalizarse y solo finalizado representa pago/venta remota.';

CREATE TABLE IF NOT EXISTS `VENTAS` (
  `Id_venta` INT NOT NULL AUTO_INCREMENT,
  `Id_pedido` INT NULL
    COMMENT 'NULL para venta manual_fonda; obligatorio para venta remota.',
  `Fuente` ENUM('manual_fonda', 'remota') NOT NULL
    COMMENT 'manual_fonda = venta presencial capturada por encargada; remota = pedido realizado desde la app.',
  `Estado` ENUM('activa', 'anulada') NOT NULL DEFAULT 'activa'
    COMMENT 'Estado logico; las anuladas se excluyen de estadisticas y reportes.',
  `Clave_idempotencia` VARCHAR(100) CHARACTER SET ascii COLLATE ascii_bin NULL
    COMMENT 'Clave por encargada para reintentar una venta manual sin duplicarla.',
  `Fecha` DATE NOT NULL,
  `Hora` TIME NOT NULL,
  `Total` DECIMAL(10,2) NOT NULL,
  `Registrado_por` INT NULL COMMENT 'Usuario encargada que registro o confirmo la venta.',
  `Observaciones` TEXT NULL,
  `Motivo_anulacion` TEXT NULL,
  `Anulada_en` TIMESTAMP NULL DEFAULT NULL,
  `Id_usuario_anulo` INT NULL
    COMMENT 'Usuario encargada que realizo la anulacion logica.',
  `Creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id_venta`),
  UNIQUE KEY `uq_ventas_id_pedido` (`Id_pedido`),
  UNIQUE KEY `uk_ventas_registrado_por_clave_idempotencia` (`Registrado_por`, `Clave_idempotencia`),
  KEY `idx_ventas_fecha` (`Fecha`),
  KEY `idx_ventas_fuente_fecha` (`Fuente`, `Fecha`),
  KEY `idx_ventas_estado_fecha` (`Estado`, `Fecha`),
  KEY `idx_ventas_registrado_por` (`Registrado_por`),
  KEY `idx_ventas_usuario_anulo` (`Id_usuario_anulo`),
  CONSTRAINT `fk_ventas_pedido`
    FOREIGN KEY (`Id_pedido`) REFERENCES `PEDIDOS` (`Id_pedido`)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,
  CONSTRAINT `fk_ventas_registrado_por`
    FOREIGN KEY (`Registrado_por`) REFERENCES `USUARIOS` (`Id_usuario`)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
  CONSTRAINT `fk_ventas_usuario_anulo`
    FOREIGN KEY (`Id_usuario_anulo`) REFERENCES `USUARIOS` (`Id_usuario`)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
  CONSTRAINT `chk_ventas_total`
    CHECK (`Total` >= 0),
  CONSTRAINT `chk_ventas_fuente_id_pedido`
    CHECK (
      (`Fuente` = 'manual_fonda' AND `Id_pedido` IS NULL)
      OR
      (`Fuente` = 'remota' AND `Id_pedido` IS NOT NULL)
    ),
  CONSTRAINT `chk_ventas_anulacion`
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
    ),
  CONSTRAINT `chk_ventas_clave_idempotencia_fuente`
    CHECK (`Clave_idempotencia` IS NULL OR `Fuente` = 'manual_fonda')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Ventas efectivas manuales o remotas; conserva anulacion logica e idempotencia sin duplicar fuentes.';

CREATE TABLE IF NOT EXISTS `DETALLE_PEDIDO` (
  `Id_detalle_pedido` INT NOT NULL AUTO_INCREMENT,
  `Id_pedido` INT NULL,
  `Id_venta` INT NULL,
  `Id_platillo` INT NULL,
  `Id_menu` INT NULL,
  `Nombre_platillo` VARCHAR(150) NOT NULL COMMENT 'Snapshot del nombre al momento de capturar el pedido.',
  `Cantidad` INT NOT NULL,
  `Precio_unitario` DECIMAL(8,2) NOT NULL COMMENT 'Snapshot del precio al momento de capturar el pedido.',
  `Subtotal` DECIMAL(10,2) NOT NULL COMMENT 'Snapshot del subtotal del renglon.',
  PRIMARY KEY (`Id_detalle_pedido`),
  KEY `idx_detalle_pedido_id_pedido` (`Id_pedido`),
  KEY `idx_detalle_pedido_id_platillo` (`Id_platillo`),
  KEY `idx_detalle_pedido_id_menu` (`Id_menu`),
  UNIQUE KEY `uk_detalle_pedido_venta_menu` (`Id_venta`, `Id_menu`),
  CONSTRAINT `fk_detalle_pedido_id_pedido`
    FOREIGN KEY (`Id_pedido`) REFERENCES `PEDIDOS` (`Id_pedido`)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,
  CONSTRAINT `fk_detalle_pedido_id_venta`
    FOREIGN KEY (`Id_venta`) REFERENCES `VENTAS` (`Id_venta`)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,
  CONSTRAINT `fk_detalle_pedido_id_platillo`
    FOREIGN KEY (`Id_platillo`) REFERENCES `PLATILLOS` (`Id_platillo`)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
  CONSTRAINT `fk_detalle_pedido_id_menu`
    FOREIGN KEY (`Id_menu`) REFERENCES `MENU_DIA` (`Id_menu`)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,
  CONSTRAINT `chk_detalle_un_solo_padre`
    CHECK (
      (`Id_pedido` IS NOT NULL AND `Id_venta` IS NULL)
      OR
      (`Id_pedido` IS NULL AND `Id_venta` IS NOT NULL)
    ),
  CONSTRAINT `chk_detalle_venta_manual_menu`
    CHECK (`Id_venta` IS NULL OR `Id_menu` IS NOT NULL),
  CONSTRAINT `chk_detalle_pedido_cantidad`
    CHECK (`Cantidad` > 0),
  CONSTRAINT `chk_detalle_pedido_precio_unitario`
    CHECK (`Precio_unitario` >= 0),
  CONSTRAINT `chk_detalle_pedido_subtotal`
    CHECK (`Subtotal` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Detalle normalizado de pedidos; conserva snapshots de nombre, precio y subtotal para reportes historicos.';

CREATE TABLE IF NOT EXISTS `NOTIFICACIONES` (
  `Id_notificacion` INT NOT NULL AUTO_INCREMENT,
  `Id_usuario` INT NOT NULL,
  `Id_pedido` INT NULL,
  `Tipo` VARCHAR(50) NOT NULL,
  `Titulo` VARCHAR(150) NOT NULL,
  `Mensaje` TEXT NOT NULL,
  `Estado` ENUM('no_leida', 'leida') NOT NULL DEFAULT 'no_leida',
  `Creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `Leida_en` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`Id_notificacion`),
  KEY `idx_notificaciones_usuario_estado` (`Id_usuario`, `Estado`),
  KEY `idx_notificaciones_usuario_fecha` (`Id_usuario`, `Creado_en`, `Id_notificacion`),
  KEY `idx_notificaciones_id_pedido` (`Id_pedido`),
  CONSTRAINT `fk_notificaciones_id_usuario`
    FOREIGN KEY (`Id_usuario`) REFERENCES `USUARIOS` (`Id_usuario`)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT `fk_notificaciones_id_pedido`
    FOREIGN KEY (`Id_pedido`) REFERENCES `PEDIDOS` (`Id_pedido`)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
  CONSTRAINT `chk_notificaciones_leida_en`
    CHECK (`Estado` = 'leida' OR `Leida_en` IS NULL)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Notificaciones internas asociadas a usuarios y, opcionalmente, a pedidos.';

CREATE TABLE IF NOT EXISTS `METRICAS_PLATILLO_DIA` (
  `Id_metrica_platillo` INT NOT NULL AUTO_INCREMENT,
  `Fecha` DATE NOT NULL,
  `Id_platillo` INT NOT NULL,
  `Cantidad_solicitada` INT NOT NULL DEFAULT 0,
  `Cantidad_vendida` INT NOT NULL DEFAULT 0,
  `Total_generado` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (`Id_metrica_platillo`),
  UNIQUE KEY `uk_metricas_platillo_dia_fecha_platillo` (`Fecha`, `Id_platillo`),
  KEY `idx_metricas_platillo_dia_id_platillo` (`Id_platillo`),
  CONSTRAINT `fk_metricas_platillo_dia_id_platillo`
    FOREIGN KEY (`Id_platillo`) REFERENCES `PLATILLOS` (`Id_platillo`)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT `chk_metricas_platillo_dia_cantidades`
    CHECK (`Cantidad_solicitada` >= 0 AND `Cantidad_vendida` >= 0),
  CONSTRAINT `chk_metricas_platillo_dia_total`
    CHECK (`Total_generado` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Metricas derivadas de PEDIDOS, VENTAS y DETALLE_PEDIDO; Cantidad_vendida y Total_generado deben calcularse desde VENTAS unidas al detalle del pedido.';

CREATE TABLE IF NOT EXISTS `METRICAS_HORA_PICO` (
  `Id_metrica_hora` INT NOT NULL AUTO_INCREMENT,
  `Id_estado` INT NOT NULL,
  `Franja_horaria` VARCHAR(20) NOT NULL,
  `Total_ventas` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`Id_metrica_hora`),
  UNIQUE KEY `uk_metricas_hora_pico_estado_franja` (`Id_estado`, `Franja_horaria`),
  CONSTRAINT `fk_metricas_hora_pico_id_estado`
    FOREIGN KEY (`Id_estado`) REFERENCES `ESTADO_DIA` (`Id_estado`)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT `chk_metricas_hora_pico_total`
    CHECK (`Total_ventas` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Metricas de demanda por franja horaria calculadas desde VENTAS.';

CREATE TABLE IF NOT EXISTS `METRICAS_RECHAZOS` (
  `Id_metrica_rechazo` INT NOT NULL AUTO_INCREMENT,
  `Fecha` DATE NOT NULL,
  `Categoria` ENUM('platillo_agotado', 'fonda_cerrada', 'pedido_fuera_de_horario', 'cantidad_no_disponible', 'otro') NOT NULL,
  `Id_platillo` INT NULL,
  `Total_rechazos` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`Id_metrica_rechazo`),
  UNIQUE KEY `uk_metricas_rechazos_fecha_categoria_platillo` (`Fecha`, `Categoria`, `Id_platillo`),
  KEY `idx_metricas_rechazos_id_platillo` (`Id_platillo`),
  CONSTRAINT `fk_metricas_rechazos_id_platillo`
    FOREIGN KEY (`Id_platillo`) REFERENCES `PLATILLOS` (`Id_platillo`)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
  CONSTRAINT `chk_metricas_rechazos_total`
    CHECK (`Total_rechazos` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Metricas derivadas de PEDIDOS rechazados y su Categoria_rechazo.';

CREATE TABLE IF NOT EXISTS `REPORTES_SEMANALES` (
  `Id_reporte` INT NOT NULL AUTO_INCREMENT,
  `Semana_inicio` DATE NOT NULL,
  `Semana_fin` DATE NOT NULL,
  `Total_pedidos_app` INT NOT NULL DEFAULT 0 COMMENT 'Ventas remotas con Fuente=remota dentro de la semana.',
  `Total_ingresos` DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT 'Ingresos calculados desde VENTAS.',
  `Id_platillo_mas_vendido` INT NULL,
  `Dia_mayor_demanda` DATE NULL,
  `Ruta_archivo` TEXT NULL,
  `Resumen_json` JSON NULL
    COMMENT 'Snapshot estructurado usado para regenerar o auditar el reporte.',
  `Version_formato` INT NOT NULL DEFAULT 1
    COMMENT 'Version del contrato almacenado en Resumen_json.',
  `Generado_por` INT NULL,
  `Generado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id_reporte`),
  KEY `idx_reportes_semanales_semana_generado` (`Semana_inicio`, `Semana_fin`, `Generado_en`, `Id_reporte`),
  KEY `idx_reportes_semanales_platillo_mas_vendido` (`Id_platillo_mas_vendido`),
  KEY `idx_reportes_semanales_generado_por` (`Generado_por`),
  CONSTRAINT `fk_reportes_semanales_platillo_mas_vendido`
    FOREIGN KEY (`Id_platillo_mas_vendido`) REFERENCES `PLATILLOS` (`Id_platillo`)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
  CONSTRAINT `fk_reportes_semanales_generado_por`
    FOREIGN KEY (`Generado_por`) REFERENCES `USUARIOS` (`Id_usuario`)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
  CONSTRAINT `chk_reportes_semanales_fechas`
    CHECK (`Semana_inicio` <= `Semana_fin`),
  CONSTRAINT `chk_reportes_semanales_totales`
    CHECK (`Total_pedidos_app` >= 0 AND `Total_ingresos` >= 0),
  CONSTRAINT `chk_reportes_semanales_version_formato`
    CHECK (`Version_formato` > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Snapshots de reportes PDF; permite multiples generaciones por semana y conserva importes y conteos calculados desde VENTAS, PEDIDOS y DETALLE_PEDIDO segun corresponda.';
