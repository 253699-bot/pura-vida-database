-- PuraVida - esquema inicial MySQL 8
-- PEDIDOS conserva el flujo operativo; VENTAS representa las ventas efectivas generadas por pedidos aceptados.
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
  `Nombre_fonda` VARCHAR(150) NOT NULL DEFAULT 'PuraVida',
  `Logo_url` TEXT NULL,
  `Direccion` TEXT NULL,
  `Horarios` TEXT NULL,
  `Telefono` VARCHAR(20) NULL,
  `Correo` VARCHAR(255) NULL,
  `Actualizado_por` INT NULL COMMENT 'Usuario que modifico la configuracion por ultima vez.',
  `Actualizado_en` TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id_config`),
  CONSTRAINT `fk_configuracion_negocio_actualizado_por`
    FOREIGN KEY (`Actualizado_por`) REFERENCES `USUARIOS` (`Id_usuario`)
    ON UPDATE CASCADE
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Configuracion editable de la fonda.';

CREATE TABLE IF NOT EXISTS `ESTADO_DIA` (
  `Id_estado` INT NOT NULL AUTO_INCREMENT,
  `Fecha` DATE NOT NULL,
  `Abierto` BOOLEAN NOT NULL,
  `Motivo_cierre` TEXT NULL,
  `Registrado_por` INT NOT NULL,
  `Creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `Actualizado_en` TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id_estado`),
  UNIQUE KEY `uk_estado_dia_fecha` (`Fecha`),
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
  `Creado_por` INT NOT NULL,
  `Creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id_menu`),
  UNIQUE KEY `uk_menu_dia_fecha_platillo` (`Fecha`, `Id_platillo`),
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

CREATE TABLE IF NOT EXISTS `PEDIDOS` (
  `Id_pedido` INT NOT NULL AUTO_INCREMENT,
  `Id_cliente` INT NULL,
  `Fecha` DATE NOT NULL,
  `Hora` TIME NOT NULL,
  `Estado` ENUM('pendiente', 'aceptado', 'rechazado', 'cancelado') NOT NULL DEFAULT 'pendiente'
    COMMENT 'Flujo operativo del pedido; Estado aceptado debe generar una venta efectiva en VENTAS.',
  `Total` DECIMAL(10,2) NOT NULL,
  `Tiempo_espera_est` VARCHAR(100) NULL,
  `Motivo_rechazo` TEXT NULL,
  `Categoria_rechazo` ENUM('platillo_agotado', 'fonda_cerrada', 'pedido_fuera_de_horario', 'cantidad_no_disponible', 'otro') NULL,
  `Respondido_por` INT NULL,
  `Respondido_en` TIMESTAMP NULL DEFAULT NULL,
  `Observaciones` TEXT NULL COMMENT 'Notas operativas del pedido.',
  `Creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id_pedido`),
  KEY `idx_pedidos_cliente` (`Id_cliente`),
  KEY `idx_pedidos_respondido_por` (`Respondido_por`),
  KEY `idx_pedidos_estado_fecha` (`Estado`, `Fecha`),
  CONSTRAINT `fk_pedidos_cliente`
    FOREIGN KEY (`Id_cliente`) REFERENCES `USUARIOS` (`Id_usuario`)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
  CONSTRAINT `fk_pedidos_respondido_por`
    FOREIGN KEY (`Respondido_por`) REFERENCES `USUARIOS` (`Id_usuario`)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
  CONSTRAINT `chk_pedidos_total`
    CHECK (`Total` >= 0),
  CONSTRAINT `chk_pedidos_rechazo_estado`
    CHECK (`Estado` = 'rechazado' OR (`Motivo_rechazo` IS NULL AND `Categoria_rechazo` IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Solicitudes operativas del sistema; los pedidos aceptados generan una venta efectiva en VENTAS.';

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

CREATE TABLE IF NOT EXISTS `DETALLE_PEDIDO` (
  `Id_detalle_pedido` INT NOT NULL AUTO_INCREMENT,
  `Id_pedido` INT NOT NULL,
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
  CONSTRAINT `fk_detalle_pedido_id_pedido`
    FOREIGN KEY (`Id_pedido`) REFERENCES `PEDIDOS` (`Id_pedido`)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT `fk_detalle_pedido_id_platillo`
    FOREIGN KEY (`Id_platillo`) REFERENCES `PLATILLOS` (`Id_platillo`)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
  CONSTRAINT `fk_detalle_pedido_id_menu`
    FOREIGN KEY (`Id_menu`) REFERENCES `MENU_DIA` (`Id_menu`)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
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
  `Titulo` VARCHAR(150) NOT NULL,
  `Mensaje` TEXT NOT NULL,
  `Estado` ENUM('no_leida', 'leida') NOT NULL DEFAULT 'no_leida',
  `Creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `Leida_en` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`Id_notificacion`),
  KEY `idx_notificaciones_usuario_estado` (`Id_usuario`, `Estado`),
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
  `Generado_por` INT NULL,
  `Generado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id_reporte`),
  UNIQUE KEY `uk_reportes_semanales_semana` (`Semana_inicio`, `Semana_fin`),
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
    CHECK (`Total_pedidos_app` >= 0 AND `Total_ingresos` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Snapshot de reportes PDF; sus importes y conteos se calculan desde VENTAS, PEDIDOS y DETALLE_PEDIDO segun corresponda.';
