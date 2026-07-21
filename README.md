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

- **Módulo 0 — Autenticación y usuarios:** login con Firebase Auth, restablecimiento de contraseña y gestión de usuarios (solo Admin).
- **Módulo 1 — Dashboard:** métricas de inventario y ventas, con vistas según el rol.
- **Módulo 2 — Catálogos e inventario:** productos, categorías, SKU, precios, márgenes y niveles de stock (mínimo / máximo).
- **Módulo 3 — Movimientos de almacén:** entradas y salidas con motivo obligatorio.
- **Módulo 4 — Punto de venta e historial:** POS con descuento atómico de inventario y cancelación de folios (solo Admin).

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

