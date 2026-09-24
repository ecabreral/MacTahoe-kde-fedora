# Changelog

Formato: `YYYY-MM-DD` · ramas locales del fork `vinceliuice/MacTahoe-kde`.

## 1.2.2 — 2026-09-24 · rama `fedora-45-beta`

### Añadido

- `fedora/setup-magic-lamp.sh`: activa el efecto **Magic Lamp integrado de kwin** (`magiclamp`): minimizar una
  ventana la encoje hasta el icono del dock, como en macOS. No compila nada (kwin 6.7.4 ya lo incluye en el
  binario) y sólo escribe `kwinrc`: `[Plugins] magiclampEnabled=true`, `[Plugins] squashEnabled=false`
  (`squash` comparte el grupo exclusivo `minimize`) y, opcionalmente, `[Effect-magiclamp] AnimationDuration`.
  Aplica al momento vía DBus (`org.kde.kwin.Effects.loadEffect` / `unloadEffect` + `org.kde.KWin.reconfigure`)
  y es idempotente. Opción `--disable` para revertir a Squash. Documentado en `fedora/README.md`.

### Requisito descubierto

- **3D real en la VM**: kwin sólo carga animaciones si el compositor no usa un renderizador GL por software
  (`WorkspaceScene::animationsSupported`). Con un renderizador software (VM sin 3D) kwin rechaza cargar
  `magiclamp`, `squash` y `fade`. En este host la habilitación no bastó con `accel3d=yes` + `<gl enable='yes'>`:
  libvirt 12.6 no emite la variante GL de `virtio-vga` para QEMU 11.1, así que se inyecta el dispositivo vía
  `qemu:commandline`: `-device virtio-vga-gl,blob=on` (con `<video><model type='none'/>`) y `gl=on,
  rendernode=/dev/dri/renderD128` en spice. Además, GNOME Boxes debe tener `acceleration-3d=true` en
  `~/.config/gnome-boxes/sources/QEMU Session`, o al lanzar reescribe el dominio con `gl=no` y el arranque
  falla ("The display backend does not have OpenGL support enabled"). Detalles en `fedora/README.md`.

## 1.2.1 — 2026-09-24 · rama `fedora-45-beta`

### Corregido

- **Dock de sólo iconos en Plasma 6.7**: se revierte la sustitución de `org.kde.plasma.icontasks` por
  `org.kde.plasma.taskmanager` en los tres ficheros de layout (`MacTahoe-Dark`, `MacTahoe-Light`, `MacOSDock`).
  En 6.7 `icontasks` es un paquete válido (`metadata.json` + `X-Plasma-RootPath` → reusa el QML del
  `taskmanager`; su `main.qml` activa `iconsOnly` según el `pluginName`), por lo que el dock vuelve a mostrar
  **sólo iconos** al abrir aplicaciones. El fallo de carga (error `mainscript`) era exclusivo de Plasma 6.6.
  Validado en la VM de Fedora 45 beta (applet `org.kde.plasma.icontasks`, journal limpio).

## 1.2.0 — 2026-09-24 · rama `fedora-45-beta`

Soporte de **Fedora 45 beta** (Plasma 6.7.4 · Qt 6.11.1 · Wayland), validado de extremo a extremo.

### Añadido

- `fedora/build-bundle.sh`: opción `--rpm-dir DIR` para construir el bundle con RPMs ya descargados (imprescindible
  en Branched/Rawhide, donde las rutas públicas de descarga aún no existen).
- `fedora/build-bundle.sh`: prueba automáticamente las rutas `releases/` y `development/` antes de fallar.

### Verificado

- Instalación completa desde bundle sobre Fedora 45 beta: Global Theme, iconos/cursores, esquema de color,
  Kvantum (`1.1.6-2.fc45`), Aurorae y layout macOS (`[top h=44] [bottom h=64]`), sin huecos de letterbox.
- Los parches siguen siendo necesarios en Plasma 6.7: `org.kde.plasma.icontasks` continúa roto y
  `lookandfeeltool` sigue sin aplicar todas las claves de `defaults`.

## 1.1.1 — 2026-09-24 · rama `fedora-44-plasma-6.6`

### Corregido

- `fedora/setup-mactahoe.sh`: `say`/`warn`/`die` se definían **después** de la detección del bundle, así que
  `install.sh` abortaba al instante con `say: orden no encontrada`. Reconstruido el bundle como `1.1.1`
  (quien se haya descargado el `1.1.0` debe usar éste).

## 1.1.0 — 2026-09-24

Instalación sin red mediante paquete autocontenido.

### Añadido

- `fedora/build-bundle.sh`: descarga en el host kvantum (`kvantum` + `kvantum-data` de Fedora 44) y el tarball de
  `MacTahoe-icon-theme`, los junta con el tema parcheado y genera
  `dist/MacTahoe-kde-bundle-<versión>.tar.gz` con sumas de verificación. Opciones `--fedora`, `--kvantum`,
  `--version`, `--out-dir`, `--cache-dir` y `--no-cache`; cache de descargas en `~/.cache/mactahoe-bundle`.
- `install.sh` en la raíz del bundle: ejecuta todo con un solo comando y sin red.
- `fedora/setup-mactahoe.sh`: opciones `--bundle DIR` y `--offline`. Instala kvantum desde los RPM locales
  (`dnf install --disablerepo='*'` con fallback a `rpm -Uvh`) y los iconos/cursores desde el tarball local;
  detecta automáticamente un bundle situado junto al repo. Los fallos de kvantum e iconos ya no abortan.
- Documentación del modo bundle/offline en `fedora/README.md`.

## 1.0.0 — 2026-09-24

Primera release del aprovisionamiento para **Fedora KDE Plasma 6** (validado en Fedora 44 · Plasma 6.6.4 ·
Qt 6.10.2 · Wayland · GNOME Boxes).

### Añadido

- `fedora/setup-mactahoe.sh`: provisionamiento completo de una máquina Fedora KDE.
  - Detección de la sesión Plasma (`/run/user/<uid>/bus` + socket Wayland) → usable también por SSH.
  - Backup previo en `~/.local/state/mactahoe/backups/kde-<fecha>.tar.gz`.
  - Instalación de `kvantum` (sudo) y del tema de iconos/cursores `MacTahoe-icon-theme`.
  - Instalación del tema (`install.sh` en modo usuario).
  - Aplicación del Global Theme (`lookandfeeltool`) y de todas las entradas de `contents/defaults` con
    `kwriteconfig6`, porque Plasma 6.6 sólo aplica colores y `LookAndFeelPackage`.
  - Configuración de Kvantum (`MacTahoeDark` / `MacTahoe`).
  - Layout macOS por DBus (`org.kde.PlasmaShell.evaluateScript`): panel superior 44 px + dock inferior 64 px
    (`fit`, `dodgewindows`).
  - Fondo de pantalla con `FillMode=2` (sin franjas de letterbox) y recarga de kwin + plasmashell.
  - Opciones: `-v dark|light`, `--no-layout`, `--no-icons`, `--enable-ssh`, `--reboot`.
- `fedora/setup-remote.sh`: copia del repo por `rsync` y ejecución remota con TTY para `sudo`.
- `fedora/README.md`: requisitos, quickstart, runbook completo desde cero con GNOME Boxes, referencia de
  opciones, rutas y claves modificadas, verificación, rollback, solución de problemas, parches y mantenimiento.
- Sección en el `README.md` raíz enlazando a `fedora/README.md`.

### Corregido (compatibilidad Plasma 6.6 / Fedora 44)

- `install.sh`: `LAYOUT_DIR` respeta `${dest}` en la rama root; `-n/--name` ya lee su valor (`name="${2}"`).
- Sustitución de `org.kde.plasma.icontasks` por `org.kde.plasma.taskmanager` en los tres ficheros de layout
  (`MacTahoe-Dark`, `MacTahoe-Light` y `MacOSDock`), porque ese applet ya no existe en Plasma 6.6.

### Conocido / fuera de alcance

- Tema de login `sddm/`: requiere instalar SDDM (`sudo dnf install sddm sddm-wayland-plasma`).
- Efecto blur tipo macOS: externo (`kwin-effects-forceblur`), recomendado por el autor.
