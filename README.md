# AURA VITAE · PyME-Sync

**Control de Inventarios y Ventas Multiplataforma** para PyMEs de skincare, construido con Flutter (Web / móvil / escritorio) sobre Firebase Authentication y Cloud Firestore.

La app ofrece gestión de inventario en tiempo real, punto de venta con transacciones atómicas y acceso diferenciado por roles (**Administrador** y **Operador**).

---

## 🔐 Credenciales de prueba

> Usa estas cuentas para probar la aplicación. Corresponden a usuarios reales en **Firebase Authentication**; el rol se detecta automáticamente al iniciar sesión.

| Rol           | Correo                     | Contraseña       |
| ------------- | -------------------------- | ---------------- |
| Administrador | `admin@auravitae.com`      | `AuraAdmin2026!` |
| Operador      | `operador@auravitae.com`   | `AuraOpen2026!`  |

**Requisitos de la contraseña** (validados por Firebase Auth; el medidor de la app es solo una guía visual):

- Mínimo 8 caracteres (máximo 64), sin espacios en blanco.
- Al menos una mayúscula, una minúscula, un número y un carácter especial.

> 💡 El rol se detecta automáticamente al iniciar sesión: se lee desde el documento del usuario en la colección `users` de Firestore. Si el usuario no tiene documento, se crea como **Operador** (el Administrador puede cambiar el rol después en *Gestión de Usuarios*). Como respaldo sin conexión, un correo que empieza con `admin` se trata como Administrador.

---

## ✨ Módulos

- **Módulo 0 — Autenticación y usuarios:** login con Firebase Auth, restablecimiento de contraseña y gestión de usuarios (solo Admin). El alta crea la cuenta en Firebase Auth con una contraseña temporal y el documento de rol en `users/{uid}`; el nuevo usuario entra de inmediato y cambia su contraseña desde *¿Olvidaste tu contraseña?*.
- **Módulo 1 — Dashboard:** métricas de inventario y ventas, con vistas según el rol.
- **Módulo 2 — Catálogos e inventario:** productos, categorías, SKU, precios, márgenes y niveles de stock (mínimo / máximo).
- **Módulo 3 — Movimientos de almacén:** entradas y salidas con motivo obligatorio.
- **Módulo 4 — Punto de venta e historial:** POS con descuento atómico de inventario y cancelación de folios (solo Admin).
- **Configuración de la cuenta** (ambos roles, desde el menú de usuario): nombre, correo de recuperación, cambio de contraseña y sección de inicio del sistema.

> **Contraseñas y correos.** El sistema gestiona contraseñas, nunca identidades: el correo del usuario no se cambia desde la app, porque es su identidad en el CRM y de él cuelgan las ventas y movimientos que registró. Cada persona puede cambiar su contraseña desde *Configuración → Seguridad* introduciendo la actual, y registrar un **correo de recuperación** por adelantado.
>
> Límite conocido: Firebase solo envía el enlace de restablecimiento al correo de la cuenta, así que ese correo secundario queda registrado para que el administrador pueda devolverle el acceso a esa persona. Entregar el enlace directamente al correo secundario requiere un backend propio (Cloud Function con `generatePasswordResetLink` + un servicio de correo, lo que exige plan Blaze).

## 👥 Roles (RBAC)

| Capacidad                          | Administrador | Operador |
| ---------------------------------- | :-----------: | :------: |
| Dashboard                          |       ✅       |    ✅     |
| Punto de venta                     |       ✅       |    ✅     |
| Registrar movimientos de stock     |       ✅       |    ✅     |
| Gestionar productos y categorías   |       ✅       |    ❌     |
| Cancelar ventas (folios)           |       ✅       |    ❌     |
| Gestión de usuarios                |       ✅       |    ❌     |

---

## 📴 Modo sin conexión

La app es una PWA instalable y sigue funcionando con la red caída, pero **no todo**. Esto es exactamente lo que cubre:

| Sin conexión | ¿Funciona? | Por qué |
| --- | :---: | --- |
| Abrir la app (ya instalada o visitada) | ✅ | El service worker cachea el *app shell* |
| Mantener la sesión iniciada | ✅ | Firebase Auth guarda la sesión localmente |
| Consultar inventario, ventas y movimientos ya vistos | ✅ | Caché local de Firestore (`persistenceEnabled`) |
| Cobrar una venta en el POS | ❌ | Necesita transacción contra el servidor |
| Registrar entradas o salidas de stock | ❌ | Necesita transacción contra el servidor |
| Cancelar un folio | ❌ | Necesita transacción contra el servidor |
| Iniciar sesión por primera vez en ese dispositivo | ❌ | Firebase Auth debe validar las credenciales |

Las tres operaciones que no funcionan usan **transacciones de Firestore**, que no se resuelven sin conexión porque necesitan leer el stock del servidor para descontarlo de forma atómica. Es a propósito: encolarlas offline permitiría vender existencias que otro dispositivo ya vendió. Cuando se intenta, la app avisa "Sin conexión" y explica por qué, en vez de fallar en silencio.

> La caché local guarda lo que ya se consultó en ese navegador. Un dispositivo que nunca abrió el módulo de Ventas no verá ventas al quedarse sin red.

## 🛠️ Stack técnico

| Área              | Tecnología                          |
| ----------------- | ----------------------------------- |
| Framework         | Flutter                             |
| Estado            | `provider` (ChangeNotifier)         |
| Autenticación     | `firebase_auth`                     |
| Base de datos     | `cloud_firestore` (snapshots reactivos) |
| Inicialización    | `firebase_core`                     |

## 📁 Estructura

```
lib/
├── main.dart                 # Entry point + AuthGate (enrutado por sesión)
├── firebase_options.dart     # Config generada por FlutterFire
├── core/                     # Tema y utilidades responsive
├── models/                   # Modelos de dominio (toMap/fromMap)
├── services/                 # AuthService + repositorio de inventario (Firestore)
├── screens/                  # Login, dashboard, productos, movimientos, ventas, usuarios
└── widgets/                  # Componentes compartidos
```

---

*Proyecto académico — Equipo 1.*
