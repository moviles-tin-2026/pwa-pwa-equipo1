# PyME-Sync — Professional Inventory Control

PWA de control de inventario para PyMEs, construida **Mobile First** y totalmente responsiva.
Réplica fiel de los diseños: Login, Dashboard, Inventory, Transactions (Record Sale) y Settings.

## Stack

- **React 18** + **TypeScript**
- **Vite 5** (build / dev server)
- **React Router 6** (navegación)
- **vite-plugin-pwa** (manifest + service worker, instalable y offline)
- CSS puro Mobile First (sin frameworks)

## Características

- 🔐 **Login** con mostrar/ocultar contraseña, "keep me logged in" y sesión persistente (localStorage).
- 📊 **Dashboard** con KPIs (ventas, transacciones, low stock, top product), actividad reciente y distribución de stock.
- 📦 **Inventory** con búsqueda por nombre/SKU, filtros por estado de stock, barras de nivel y modal **Add Product**.
- 🧾 **Transactions / Record Sale** tipo POS: catálogo + carrito en vivo, cantidades, subtotal, IVA (8%), total y confirmación que descuenta stock.
- ⚙️ **Settings** con cuenta, preferencias (toggles) y badges de seguridad.
- 📱 Navegación adaptativa: **sidebar** en escritorio, **bottom-nav + FAB** en móvil.

## Cómo correr

```bash
npm install
npm run dev      # http://localhost:5173
```

### Build de producción

```bash
npm run build
npm run preview
```

## Despliegue en GitHub Pages (manual, sin GitHub Actions)

El build se genera localmente y se commitea en la carpeta `/docs` de la raíz del repo.
GitHub Pages sirve esa carpeta directamente.

### Configuración inicial (una sola vez)
En GitHub: **Settings → Pages → Build and deployment → Source = Deploy from a branch → Branch: `main` → Folder: `/docs`**

### Cada vez que quieras publicar cambios
Desde la carpeta `pwa/`:
```bash
npm run build        # genera /docs en la raíz del repo
cd ..
git add docs/
git commit -m "Deploy: update PWA build"
git push origin main
```

La app queda en: **https://moviles-tin-2026.github.io/pwa-pwa-equipo1/**

### Íconos PNG
Los íconos `public/pwa-192.png` y `public/pwa-512.png` cumplen el requisito de la
[guía PWA de Microsoft Edge](https://learn.microsoft.com/es-es/microsoft-edge/progressive-web-apps/).
Si los necesitas regenerar:
```bash
node scripts/generate-icons.mjs
```

### Notas técnicas
- `vite.config.ts` usa `base: '/pwa-pwa-equipo1/'` para que los assets carguen en Pages.
- Se usa `HashRouter`: las rutas son tipo `.../#/dashboard` (funciona sin servidor).
- Service worker (Workbox) precachea todos los assets → la app funciona offline.

## Credenciales demo

Cualquier email/contraseña funciona (auth simulada). El formulario viene pre-cargado con
`owner@business.com`.

## Estructura

```
src/
  components/    Layout, Icons, AddProductModal
  data/          tipos + datos mock
  pages/         Login, Dashboard, Inventory, Transactions, Settings
  store/         AppContext (auth + inventario + carrito) y helpers
  styles/        index.css (Mobile First)
```
