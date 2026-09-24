# Changelog

Formato: `YYYY-MM-DD` · rama local `fedora-44-plasma-6.6` (fork de `vinceliuice/MacTahoe-kde`).

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
