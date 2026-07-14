# Aura Vitae · Roles, credenciales y recorridos de usuario

Sistema PyME-Sync — proyecto Firebase **PyME (`pyme-47f32`)**.
El rol se lee del documento `users/{uid}` en Firestore al iniciar sesión y
determina el menú, las acciones visibles y los permisos de escritura
(reforzados en el servidor por `firestore.rules`).

## Credenciales

| Rol | Correo | Contraseña | UID |
|---|---|---|---|
| **Administrador** | `admin@auravitae.com` | `AuraAdmin2026!` | `VmO68AuMbyY3XNVNNk1HVEaj0az2` |
| **Operador** | `operador@auravitae.com` | `AuraOper2026!` | `wDADQDkWQ8gHprscmc24e88PAoq2` |

> También siguen activas las cuentas de prueba anteriores:
> `admin@test.com` (admin), `operador@test.com` y `prueba@test.com` (operadores).
> Cambiar contraseñas desde Firebase Console → Authentication.

## Matriz de permisos (RBAC)

| Módulo | Administrador | Operador |
|---|---|---|
| **0. Autenticación y perfil** | Acceso total y gestión de usuarios | Acceso propio, consulta de su perfil |
| **1. Dashboard** | Métricas globales: ventas del mes, valor del inventario a costo y a venta, margen de utilidad, gráfico mensual, top vendidos, alertas | Resumen operativo diario: accesos rápidos, ventas/cobros de hoy, alertas de stock bajo |
| **2. Catálogos e inventario** | CRUD completo: crear/editar/eliminar productos y categorías, ver precio de costo y margen | Solo lectura: busca y consulta productos (sin costos, sin edición) |
| **3. Movimientos** | Registro + auditoría del historial completo | Registro de entradas (compra) y salidas (merma/daño/caducidad) con motivo obligatorio |
| **4. Punto de venta** | Operación de caja + historial completo + **cancelación de folios** | Operación de caja + historial **solo del día** (arqueo de turno) |
| **Gestión de usuarios** | Alta, cambio de rol, desactivar, eliminar | — (módulo oculto) |

Refuerzo en servidor (`firestore.rules`): el operador solo puede modificar el
campo `stock` de productos (nunca precios), los movimientos son inmutables
(bitácora de auditoría) y cancelar ventas exige rol admin.

## Módulos habilitados en el menú

- **Administrador**: Dashboard · Inventario · Movimientos · Ventas · **Usuarios** (5 secciones)
- **Operador**: Dashboard · Inventario · Movimientos · Ventas (4 secciones)

## Recorrido del Administrador

1. **Login** → el sistema detecta rol `admin` en Firestore → Dashboard administrativo.
2. **Dashboard**: revisa ventas del mes, valor del inventario, margen y alertas críticas de stock.
3. **Inventario**: da de alta productos (nombre, SKU, categoría, costo, venta, stock mín/máx, imagen por URL), gestiona categorías.
4. **Movimientos**: audita la bitácora completa de entradas/salidas con usuario responsable.
5. **Ventas → Historial**: consulta ingresos históricos con detalle financiero; cancela folios erróneos (el stock se restaura automáticamente).
6. **Usuarios**: crea operadores, cambia roles, desactiva cuentas.
7. Cierra sesión.

## Recorrido del Operador

1. **Login** → rol `operator` → Dashboard operativo.
2. **Dashboard**: ve sus accesos rápidos (*Nueva venta*, *Registrar entrada*) y las alertas de stock bajo del día.
3. **Ventas → Terminal (POS)**: busca o escanea productos, arma el carrito, elige método de pago y finaliza la venta → el stock se descuenta al instante en todos los dispositivos.
4. **Movimientos**: registra la entrada de mercancía del proveedor o una salida por merma, siempre con motivo.
5. **Inventario**: consulta existencias y precios de venta (sin costos ni edición).
6. **Ventas → Historial**: revisa las ventas de su turno para el arqueo de caja.
7. Cierra sesión.
