# PuraVida Database

Scripts SQL para la base de datos de PuraVida.

## Uso

### Base nueva

Para crear una base nueva desde cero, cargar el esquema base y después aplicar
la migración 002:

```bash
mysql -u <admin_user> -p <database_name> < database/schema.sql
mysql -u <admin_user> -p <database_name> < database/migrations/002_update_ventas_for_manual_and_cancellation.sql
```

`database/schema.sql` ya incluye la tabla `VENTAS` y deja `PEDIDOS` sin la
columna histórica `Fuente`. La migración 002 habilita ventas manuales sin
pedido y agrega la anulación lógica.

No ejecutar `database/migrations/001_add_ventas_move_fuente_from_pedidos.sql` sobre una base creada con este schema actualizado, porque esa migracion es para bases antiguas.

### Base existente

Para una base creada con una version anterior del schema, ejecutar las migraciones en orden:

```bash
mysql -u <admin_user> -p <database_name> < database/migrations/001_add_ventas_move_fuente_from_pedidos.sql
mysql -u <admin_user> -p <database_name> < database/migrations/002_update_ventas_for_manual_and_cancellation.sql
```

Antes de ejecutar migraciones sobre una base existente, hacer backup y revisar que el estado de la base corresponda a la version esperada por la migracion.

### Notificaciones internas

El esquema base actual ya incluye `NOTIFICACIONES.Tipo`. Para una base creada
con una version anterior del esquema, donde `NOTIFICACIONES` existe pero no
tiene esa columna, aplicar una sola vez:

```bash
mysql -u <admin_user> -p <database_name> < database/migrations/004_add_notification_type.sql
```

La migracion conserva las notificaciones existentes con el tipo `sistema` y
agrega el indice de listado por usuario y fecha. No debe aplicarse sobre una
base creada directamente con el `schema.sql` actual.

### Finalizacion de pedidos

El esquema base actual permite la transicion `aceptado -> finalizado`. Para una
base existente cuyo enum `PEDIDOS.Estado` aun no incluya `finalizado`, aplicar
despues de las migraciones de ventas:

```bash
mysql -u <admin_user> -p <database_name> < database/migrations/005_add_finalized_order_status.sql
```

La migracion solo amplia el enum y conserva los datos actuales. Sus consultas
finales verifican el tipo de columna, la distribucion de estados y que no haya
pedidos finalizados sin venta. No debe aplicarse sobre una base creada
directamente con el `schema.sql` actual.

La migración 002 debe ejecutarse después de la 001. Antes de aplicarla, revisa
el conteo de preflight incluido en el script: las filas `manual_fonda` deben
tener `Id_pedido` nulo y las filas `remota` deben conservar un pedido.

## Modelo de ventas

`PEDIDOS` conserva el flujo operativo de la solicitud.

`VENTAS` representa el registro efectivo de venta o ticket. Se relaciona
opcionalmente con `PEDIDOS` mediante `Id_pedido` y distingue el origen con
`Fuente`:

- `manual_fonda`
- `remota`

Las ventas `manual_fonda` no requieren pedido. Las ventas `remota` requieren
un pedido y mantienen unicidad por `Id_pedido`. La anulación es lógica mediante
`Estado`, `Motivo_anulacion`, `Anulada_en` e `Id_usuario_anulo`; no se elimina
la fila de venta.

`VENTAS_UNIFICADAS` no forma parte del modelo final. Las consultas consolidadas deben obtenerse desde `VENTAS` con JOINs hacia `PEDIDOS` y `DETALLE_PEDIDO` cuando corresponda.

La vista antigua `VW_VENTAS_CONSOLIDADAS` solo se elimina en la migracion 001 para limpiar bases previas; no debe reintroducirse sin una decision explicita del equipo.

## Compatibilidad

El objetivo principal es MySQL 8. La migracion 001 incluye una rama dinamica para manejar la diferencia entre MySQL 8 y MariaDB 10.x al eliminar constraints CHECK.
