# PuraVida Database

Scripts SQL para la base de datos MySQL 8 de PuraVida.

## Uso

### Base nueva

`database/schema.sql` es el esquema final autocontenido. Para una base vacía se
ejecuta únicamente ese archivo:

```bash
mysql -u <admin_user> -p <database_name> < database/schema.sql
```

No se deben aplicar las migraciones `001`-`009` después de crear una base con
el esquema final: sus cambios estructurales ya están incorporados.

### Base existente

Antes de cualquier migración, crear un respaldo y confirmar la versión real del
esquema. Las migraciones históricas se conservan y se aplican una sola vez, en
este orden, cuando sus precondiciones correspondan:

```text
001_add_ventas_move_fuente_from_pedidos.sql
002_update_ventas_for_manual_and_cancellation.sql
003_add_cart_items.sql
004_add_notification_type.sql
005_add_finalized_order_status.sql
006_complete_admin_flows.sql
007_add_dish_image.sql
008_allow_multiple_weekly_report_snapshots.sql
009_add_business_cycle_started_at.sql
```

`004` solo corresponde cuando `NOTIFICACIONES` todavía no tiene `Tipo`; `005`
solo cuando `PEDIDOS.Estado` todavía no incluye `finalizado`. La migración
`006` exige como baseline el resultado completo de `001`-`005`, incluido
`CARRITO_ITEMS`, `NOTIFICACIONES.Tipo` y el estado `finalizado`. `007` agrega la
URL nullable de imagen para platillos, `008` permite guardar varios snapshots
semanales independientes y `009` registra el inicio del ciclo operativo actual
en `ESTADO_DIA.Ciclo_iniciado_en`.

Ejecutar cada script con el cliente MySQL sin `--force`. Revisar primero sus
consultas de preflight y detenerse si una comprobación falla. En particular:

- `002` no puede decidir automáticamente qué hacer con ventas históricas cuya
  combinación `Fuente`/`Id_pedido` sea incompatible.
- `006` aborta antes del primer `ALTER` si está incompleta o parcialmente
  aplicada, si el baseline no coincide o si `CONFIGURACION_NEGOCIO` tiene más
  de una fila. Esas configuraciones deben fusionarse manualmente; la migración
  no borra datos para resolverlo.
- `006` preserva las filas antiguas de `MENU_DIA` como publicadas y deja
  `Publicado = FALSE` como valor predeterminado para nuevas filas.

## Modelo de ventas

`PEDIDOS` conserva el flujo operativo de las solicitudes remotas. `VENTAS`
representa los registros efectivos y distingue la fuente real:

- `manual_fonda`: venta presencial sin cliente ni pedido ficticio;
- `remota`: venta vinculada de forma única con un pedido aceptado.

La anulación es lógica mediante `Estado`, `Motivo_anulacion`, `Anulada_en` e
`Id_usuario_anulo`; no se elimina la venta. `DETALLE_PEDIDO` conserva snapshots
de nombre, cantidad, precio y subtotal: una línea pertenece exactamente a un
pedido remoto o a una venta manual. Las claves foráneas de sus padres y menú
usan `RESTRICT` para proteger el historial y ser compatibles con los `CHECK` de
MySQL.

La idempotencia de ventas manuales se conserva en `VENTAS.Clave_idempotencia`,
única por encargada. Los reportes semanales pueden tener varias generaciones para la misma semana y guardan cada snapshot estructurado en
`Resumen_json`; el PDF se regenera y no se almacena como base64.

No se agrega una tabla auxiliar de consolidacion. Las estadisticas y reportes
se calculan desde `VENTAS`, uniendo `PEDIDOS` y `DETALLE_PEDIDO` cuando
corresponde, y excluyendo ventas anuladas y pedidos invalidos.

## Historial y borrado

Pedidos, ventas, líneas, menús y platillos referenciados no se eliminan
físicamente. Los platillos usan `PLATILLOS.Activo`, las ventas usan anulación
lógica y las filas retiradas del menú usan `MENU_DIA.Publicado`. Solo
`CARRITO_ITEMS`, por ser información temporal anterior al pedido, puede
eliminarse físicamente.

## Compatibilidad

El objetivo es MySQL 8.0.16 o superior por el uso efectivo de restricciones
`CHECK` y columnas `JSON`. La migración `001` conserva una rama histórica de
compatibilidad para MariaDB, pero el modelo final y `006` se validan contra
MySQL 8.
