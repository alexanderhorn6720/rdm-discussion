# 07 — PWA + APK strategy

**Status**: Propuesta. Esperando voto.

**Decisión**: `apps/admin` se construye desde día 1 como **PWA installable**. **APK via Capacitor** cuando justifique (estimado: cuando staff/clientes usan mucho la app o pidan push notifications nativas).

## Contexto

Alexander pidió: "Opción a futuro de crear progressive app o apk".

## PWA — desde día 1

### Qué se necesita

1. `manifest.webmanifest`:
```json
{
  "name": "Rincón del Mar — Admin",
  "short_name": "RdM Admin",
  "start_url": "/",
  "display": "standalone",
  "theme_color": "#0e6b7a",
  "background_color": "#fdfaf5",
  "icons": [
    { "src": "/icons/192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/icons/512.png", "sizes": "512x512", "type": "image/png" },
    { "src": "/icons/maskable-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
  ]
}
```

2. Service worker via `vite-plugin-pwa` (Workbox):
```typescript
// vite.config.ts
import { VitePWA } from 'vite-plugin-pwa';

export default {
  plugins: [
    VitePWA({
      registerType: 'autoUpdate',
      workbox: {
        globPatterns: ['**/*.{js,css,html,ico,png,svg,webp}'],
        runtimeCaching: [
          {
            urlPattern: /^https:\/\/api\.rincondelmar\.club\/.*/,
            handler: 'NetworkFirst',
            options: { cacheName: 'api-cache', networkTimeoutSeconds: 5 }
          }
        ]
      },
      manifest: { /* ver arriba */ }
    })
  ]
};
```

3. Iconos generados (192, 512, maskable, Apple touch icon, favicon).

4. Install prompt UX:
- Detección `beforeinstallprompt` event.
- Botón "Instalar app" en sidebar.
- Hide post-install.

### Beneficios PWA

- **Install en iOS**: Add to Home Screen — Safari soporta PWAs (limited push pero install funciona).
- **Install en Android**: Chrome ofrece install banner automático tras engagement.
- **Standalone display**: sin URL bar, look-and-feel app.
- **Offline reads** via service worker cache (bookings cached, prompts en última versión vista).
- **Background sync** (Android, no iOS) para mutations cuando recupera conexión.
- **Push notifications** (Android via FCM, iOS 16.4+ via APNs con limitaciones).

### Workflows offline

Staff en propiedades sin WiFi:
- Lee bookings de hoy (cached).
- Completa tasks (queued para sync).
- Toma fotos (almacenadas localmente).
- Cuando regresa cobertura → sync automático.

Implementación con IndexedDB (via `idb-keyval`) + service worker `sync` event.

### Pros PWA

- **Gratis**: Vite plugin auto-genera.
- **Cross-platform**: Android + iOS + desktop sin código separado.
- **Updates instantáneos**: usuario recarga, ya tiene última versión. Sin App Store review.
- **SEO-friendly**: same URL para web y "app".

### Cons PWA

- **iOS limita**: no Push API pre-16.4, no background sync, no install API estándar.
- **No App Store presence**: usuario no encuentra "RdM Admin" en Play/App Store.
- **Discovery**: solo quien sabe la URL la instala.

## APK — cuando justifique

### Capacitor

Wrappea la PWA existente en native shell:
- Android APK / AAB para Play Store.
- iOS IPA para App Store (requiere Apple Developer $99/año).
- Acceso nativo a: camera, geolocation, push (FCM/APNs native), file system, biometric auth.

### Setup

```bash
pnpm add -D @capacitor/core @capacitor/cli @capacitor/android @capacitor/ios
npx cap init "RdM Admin" "club.rincondelmar.admin"
npx cap add android
npx cap add ios
# Build PWA
pnpm build
# Sync to native
npx cap sync
# Open Android Studio / Xcode para release
npx cap open android
```

`apps/admin/capacitor.config.ts`:
```typescript
import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'club.rincondelmar.admin',
  appName: 'RdM Admin',
  webDir: 'dist',
  server: {
    // Production: load from admin.rincondelmar.club
    url: 'https://admin.rincondelmar.club',
    cleartext: false
  }
};

export default config;
```

### Pros APK

- **App Store visibility**: clientes buscan "Rincón del Mar" en Play Store.
- **Push notifications nativas**: confiables iOS + Android.
- **Branding**: icon + splash screen en home screen.
- **Native APIs**: biometric login, camera, contacts, native file picker.
- **Offline robusto**: native storage > Service Worker cache.

### Cons APK

- **App Store review**: cada update tarda 1-7 días.
- **Maintenance**: dos targets (Android API, iOS SDK) que actualizar.
- **Apple Developer $99/año**.
- **Distribución APK fuera de stores**: posible para distribución interna a staff sin pasar Play Store, pero no public.

### Cuándo justifica

NO ahora. Justifica cuando:
1. Staff lo usa daily → push notifications nativas valiosas (task asignada, booking confirmado).
2. Cliente lo pide ("¿tienen app?").
3. Necesidades native (biometric login, native file system para fotos).
4. Marketing presence en stores.

Estimado: **6-12 meses post-PWA launch**.

## Apps que sería PWA pero NO APK

- `apps/site` — sitio público SEO. PWA no, APK no. Pierde SEO.
- `apps/admin` — staff/admin/clientes power users. PWA sí, APK eventualmente.
- `apps/customer-portal` (futuro, parte de admin con rol customer) — PWA sí.

## Notificaciones push

PWA Web Push (Android Chrome + iOS 16.4+):
- Subscription stored en D1 `push_subscriptions`.
- Send via web-push library en Worker.
- Use cases: booking confirmed, payment received, new conversation needs attention.

APK con FCM (Android) + APNs (iOS) — más confiable. Capacitor maneja la integración.

Implementación inicial: solo Web Push opt-in en PWA. FCM/APNs cuando se ship APK.

## Voto

- [ ] **Claude Code**: ¿OK con Vite PWA + Capacitor stack? Otra preferencia (Tauri, Expo)?
- [ ] **Alexander**: ¿APK timing — 6 meses post-launch razonable? ¿Quieres Play Store presence antes para marketing?

## Refs

- vite-plugin-pwa: `https://vite-pwa-org.netlify.app/`
- Capacitor: `https://capacitorjs.com/`
- Web Push API: `https://developer.mozilla.org/en-US/docs/Web/API/Push_API`
