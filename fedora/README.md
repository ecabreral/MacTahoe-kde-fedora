---
title: MacTahoe-kde en Fedora KDE
aliases:
  - MacTahoe Fedora
  - provisioning MacTahoe
tags:
  - fedora
  - kde-plasma
  - plasma6
  - boxes
  - libvirt
  - theming
  - mactahoe
created: 2026-09-24
updated: 2026-09-24
---

# MacTahoe-kde en Fedora KDE (Plasma 6 / Fedora 44)

Guía y aprovisionamiento **reproducible** del tema [MacTahoe-kde](https://github.com/vinceliuice/MacTahoe-kde)
sobre una máquina Fedora con KDE Plasma 6.

> [!NOTE] Estado de los entornos validados
> - **Fedora 44 · Plasma 6.6.4 · Qt 6.10.2 · Wayland** (GNOME Boxes, red NAT `virbr0`) — rama
>   `fedora-44-plasma-6.6`. El procedimiento se repitió tres veces sobre la misma máquina (dark → light → dark).
> - **Fedora 45 beta · Plasma 6.7.4 · Qt 6.11.1 · Wayland** — rama **`fedora-45-beta`**, mismo procedimiento con
>   kvantum `1.1.6-2.fc45`.

> [!WARNING] Este repo es un fork local del original
> Los ficheros del tema son del autor original (Vince Liuice). Aquí sólo se añaden **parches de compatibilidad**
> y los scripts de `fedora/`. Todo el trabajo vive en la rama local `fedora-44-plasma-6.6` y **no se sube a
> `origin`**.

## Índice

- [Requisitos](#requisitos)
- [Mapa de archivos](#mapa-de-archivos)
- [Guía rápida](#guía-rápida)
- [Instalación sin red: bundle autocontenido](#instalación-sin-red-bundle-autocontenido)
- [De cero con GNOME Boxes](#de-cero-con-gnome-boxes)
- [Referencia de opciones](#referencia-de-opciones)
- [Qué hace exactamente el script](#qué-hace-exactamente-el-script)
- [Rutas y claves que se modifican](#rutas-y-claves-que-se-modifican)
- [Idempotencia y cambio de variante](#idempotencia-y-cambio-de-variante)
- [Verificación](#verificación)
- [Volver atrás](#volver-atrás)
- [Solución de problemas](#solución-de-problemas)
- [Parches locales incluidos](#parches-locales-incluidos)
- [Compatibilidad y mantenimiento](#compatibilidad-y-mantenimiento)
- [Alcance y fuera de alcance](#alcance-y-fuera-de-alcance)
- [Referencias](#referencias)

## Requisitos

### En la máquina de destino (la VM)

| Requisito | Nota |
| --- | --- |
| Fedora 44 o superior con KDE Plasma 6 | Validado con Plasma 6.6.4 |
| **Sesión gráfica iniciada** | El script necesita el bus de sesión (`/run/user/<uid>/bus`) para hablar con plasmashell y kwin |
| Usuario con `sudo` | Para instalar `kvantum` (y `sshd` si usas `--enable-ssh`) |
| Red de salida | Descarga kvantum y el paquete de iconos |
| Herramientas de serie | `curl`, `tar`, `gdbus`, `kwriteconfig6`, `kreadconfig6`, `lookandfeeltool`, `pgrep` |

> [!TIP]
> No hace falta `git` en la VM: los iconos se descargan como tarball y este repo se copia con `rsync` desde el host.

### En el host (si usas `setup-remote.sh`)

- `ssh` con acceso por clave y `rsync`.
- Opcional: `virsh` si la VM está en libvirt/Boxes (para descubrir la IP y hacer capturas de pantalla).

## Mapa de archivos

| Archivo | Se ejecuta en | Qué hace |
| --- | --- | --- |
| `fedora/setup-mactahoe.sh` | La propia VM | Provisionamiento completo: dependencias, iconos, tema, Global Theme, claves, layout, fondo y recarga |
| `fedora/setup-remote.sh` | El host | Copia este repo a `~/MacTahoe-kde` en la VM (sin `.git`) y ejecuta el script anterior por SSH con TTY |
| `fedora/build-bundle.sh` | El host | Descarga aquí kvantum y el tema de iconos y genera un **paquete autocontenido** para instalar sin red |
| `fedora/README.md` | — | Este documento |
| `fedora/CHANGELOG.md` | — | Historial de versiones |
| `install.sh` (raíz) | La VM | Instalador original del tema (modo usuario → `~/.local/...`); lo invoca el script de provisioning |
| `uninstall.sh` (raíz) | La VM | Desinstala el tema del autor original |

Variables de entorno reconocidas:

| Variable | Valor por defecto | Para qué |
| --- | --- | --- |
| `REMOTE_DIR` | `MacTahoe-kde` | Directorio del repo en la máquina remota (`setup-remote.sh`) |

## Guía rápida

Desde el host, contra una Fedora KDE nueva con SSH por clave:

```bash
ssh-copy-id usuario@IP_DE_LA_VM                 # una sola vez
./fedora/setup-remote.sh usuario@IP_DE_LA_VM --enable-ssh
```

Desde dentro de la propia VM (con el repo ya copiado):

```bash
cd ~/MacTahoe-kde && ./fedora/setup-mactahoe.sh
```

> [!IMPORTANT]
> `--enable-ssh` instala y arranca `sshd` dentro de la VM; es lo único que hay que hacer a mano (o con esa opción)
> si la máquina es recién instalada, porque Fedora Workstation/KDE trae `sshd` **desactivado** por defecto.

## De cero con GNOME Boxes

1. **Crea la VM** con la ISO *Fedora KDE Plasma Desktop* y completa el asistente de instalación.
2. **Activa SSH dentro de la VM** (abrir Konsole y ejecutar):

   ```bash
   sudo dnf install -y openssh-server
   sudo systemctl enable --now sshd
   sudo firewall-cmd --permanent --add-service=ssh && sudo firewall-cmd --reload
   ```

3. **Averigua la IP** desde el host:

   ```bash
   virsh list --all
   virsh domifaddr <dominio> --source arp        # ej. 192.168.122.109
   ```

4. **Copia tu clave y crea un alias** (opcional pero cómodo):

   ```bash
   ssh-copy-id usuario@IP
   cat >> ~/.ssh/config <<'EOF'
   Host fedora-kde
       HostName IP_DE_LA_VM
       User usuario
       IdentityFile ~/.ssh/id_ed25519
   EOF
   ```

5. **Ejecuta el aprovisionamiento** desde el host:

   ```bash
   ./fedora/setup-remote.sh fedora-kde --variant dark
   ```

6. **Verifica** (ver [Verificación](#verificación)).

> [!TIP] IP fija para que no cambie al reiniciar
> La IP es DHCP de `virbr0`. Para reservarla hace falta root en el host:
> `sudo virsh net-update default add ip-dhcp-host "<mac> <ip>" --live --config`
> (MAC e IP actuales salen de `virsh domifaddr <dominio> --source arp`).

## Referencia de opciones

| Opción | Qué hace |
| --- | --- |
| `-v dark` / `-v light` (`--variant`) | Variante del tema. Por defecto `dark`. `light` usa iconos/cursores `MacTahoe-light`, Kvantum `MacTahoe` y `widgetStyle=kvantum`. |
| `--bundle DIR` | Usa los ficheros de un bundle local (RPM de kvantum y tarball de iconos) en vez de descargarlos |
| `--offline` | Prohíbe la red: si algo falta en el bundle, avisa y continúa |
| `--no-layout` | Conserva tus paneles actuales; aplica sólo el aspecto (colores, tema Plasma, Aurorae, Kvantum, iconos, fondo). |
| `--no-icons` | No descarga ni instala el tema de iconos/cursores compañero. |
| `--enable-ssh` | Instala y activa `sshd` y abre el servicio en el cortafuegos. |
| `--reboot` | Reinicia la máquina al terminar. |
| `-h` / `--help` | Muestra la ayuda. |

Todas las opciones se pueden pasar igualmente a `setup-remote.sh`, que las reenvía al script remoto:

```bash
./fedora/setup-remote.sh fedora-kde --variant light --no-layout
```

## Qué hace exactamente el script

1. **Localiza la sesión Plasma**: lee `/run/user/<uid>/bus` y el primer socket `wayland-*` disponible. Por eso
   funciona también ejecutado por SSH mientras la sesión gráfica sigue viva.
2. **Backup** de `~/.config`, `~/.local/share/plasma` y `~/.config/Kvantum` en
   `~/.local/state/mactahoe/backups/kde-<AAAAMMDD-HHMMSS>.tar.gz`.
3. **Dependencias**: instala `kvantum` con `dnf` (usa `sudo` si no eres root).
4. **Iconos y cursores**: descarga el tarball de `vinceliuice/MacTahoe-icon-theme` en
   `~/.cache/mactahoe/`, ejecuta su `install.sh` en modo usuario y deja `MacTahoe`, `MacTahoe-light` y
   `MacTahoe-dark` en `~/.local/share/icons`. Cada tema de iconos lleva dentro su directorio `cursors/`, por eso
   el cursor se llama igual que el tema de iconos.
5. **Instala el tema** con el `install.sh` del repo (modo usuario): esquemas de color, `desktoptheme`,
   `look-and-feel`, plantillas de layout, `aurorae`, wallpapers y Kvantum.
6. **Aplica el Global Theme**: `lookandfeeltool -a com.github.vinceliuice.MacTahoe-Dark`.
7. **Reescribe las claves de `defaults`**: en Plasma 6.6 `lookandfeeltool` sólo aplica colores y
   `LookAndFeelPackage`, así que el script **parsea el fichero `contents/defaults`** del paquete instalado y
   escribe cada entrada con `kwriteconfig6` (iconos, cursor, `widgetStyle`, tema Plasma y decoración de kwin).
8. **Configura Kvantum** en `~/.config/Kvantum/kvantum.kvconfig` (`MacTahoeDark` o `MacTahoe`).
9. **Aplica el layout macOS** (salvo `--no-layout`): guarda `plasma-org.kde.plasma.desktop-appletsrc`, borra los
   paneles existentes y ejecuta el `desktop-layout.js` del look-and-feel vía DBus
   (`org.kde.PlasmaShell.evaluateScript`) → **panel superior de 44 px** + **dock inferior de 64 px**
   (`lengthMode=fit`, `hiding=dodgewindows`) con el gestor de tareas y sus lanzadores.
10. **Ajusta el fondo** con `FillMode=2` para que rellene la pantalla sin franjas.
11. **Recarga** kwin (`org.kde.KWin.reconfigure`) y `plasmashell`, y **imprime el estado final**.

> [!NOTE] Idempotencia del paso de iconos
> Si ya existe `~/.local/share/icons/MacTahoe`, el script **no** los reinstala. Para forzar una actualización:
> `rm -rf ~/.local/share/icons/MacTahoe*` y vuelve a ejecutarlo.

## Rutas y claves que se modifican

| Fichero | Entradas que se escriben |
| --- | --- |
| `~/.config/kdeglobals` | `[Icons] Theme`, `[KDE] LookAndFeelPackage`, `[KDE] widgetStyle`, `[General] ColorScheme` (+ colores del esquema) |
| `~/.config/kcminputrc` | `[Mouse] cursorTheme` |
| `~/.config/plasmarc` | `[Theme] name` |
| `~/.config/kwinrc` | `[org.kde.kdecoration2]` → `library=org.kde.kwin.aurorae`, `theme=__aurorae__svg__MacTahoe-Dark`, `BorderSize`, `ButtonsOnLeft`, `ButtonsOnRight`; `[DesktopSwitcher]`/`[WindowSwitcher]` |
| `~/.config/plasma-org.kde.plasma.desktop-appletsrc` | Paneles (eliminación y creación) e imagen de fondo + `FillMode` |
| `~/.local/share/` | `color-schemes/`, `plasma/desktoptheme/`, `plasma/look-and-feel/`, `plasma/layout-templates/`, `wallpapers/`, `aurorae/themes/`, `icons/` |
| `~/.config/Kvantum/` | Tema de Kvantum y `kvantum.kvconfig` |

## Instalación sin red: bundle autocontenido

Para máquinas sin internet (o para no depender de los repos en una Branched), genera en **tu máquina** un único
fichero con todo y cópialo.

> [!TIP] Contenido
> `MacTahoe-kde/` (tema parcheado + scripts) · `MacTahoe-icon-theme.tar.gz` · `kvantum-*.rpm` ·
> `install.sh` · `INSTALL.md` · `SHA256SUMS.txt`

### 1 · Construir (host)

```bash
./fedora/build-bundle.sh                      # Fedora 44 y kvantum 1.1.6 por defecto
# ./fedora/build-bundle.sh --fedora 45 --kvantum 1.1.7 --version 1.2.0
# ./fedora/build-bundle.sh --no-cache         # ignora la cache de descargas
```

Opciones: `--fedora`, `--kvantum`, `--version`, `--out-dir`, `--cache-dir`, `--no-cache`, `--rpm-dir`.
Las descargas se cachean en `~/.cache/mactahoe-bundle` para rehacer el bundle al instante.

> [!TIP] Fedora Branched / Rawhide (45 beta)
> En una beta los RPM suelen no estar aún en las rutas públicas de descarga. Bájalos en cualquier Fedora 45 y
> pásalos al builder:
>
> ```bash
> dnf download --destdir /tmp/kvantum45 kvantum kvantum-data
> rm -f /tmp/kvantum45/*i686*                       # descartar la arquitectura que no toque
> ./fedora/build-bundle.sh --fedora 45 --rpm-dir /tmp/kvantum45 --version 1.2.0
> ```

### 2 · Enviar (host)

```bash
rsync -av dist/MacTahoe-kde-bundle-<versión>.tar.gz usuario@IP:~/
```

### 3 · Instalar (VM)

```bash
tar xzf ~/MacTahoe-kde-bundle-<versión>.tar.gz
cd MacTahoe-kde-bundle
./install.sh                    # tema oscuro + layout macOS, sin descargar nada
```

Variantes útiles:

```bash
./install.sh -v light           # tema claro
./install.sh --no-layout        # conserva tus paneles actuales
./install.sh --offline          # falla limpio (avisa) en vez de descargar si algo falta
```

> [!NOTE] Qué hace `install.sh`
> Es un envoltorio: ejecuta `./MacTahoe-kde/fedora/setup-mactahoe.sh --bundle "$(pwd)"`, de modo que kvantum se
> instala desde los RPM incluidos (`dnf install --disablerepo='*'` con fallback a `rpm -Uvh`) y los iconos y
> cursores desde el tarball incluido. Si no pasas `--bundle`, el propio script lo detecta cuando hay
> `kvantum-*.rpm` o `MacTahoe-icon-theme.tar.gz` junto al repo.

## Idempotencia y cambio de variante

El script se puede relanzar sin romper nada: reinstala los ficheros del tema, vuelve a escribir las claves y
regenera los dos paneles (perderás cambios manuales de paneles, por eso hay backup y `--no-layout`).

```bash
./fedora/setup-remote.sh fedora-kde --variant light   # cambiar a la variante clara
./fedora/setup-remote.sh fedora-kde --variant dark    # volver a la oscura
```

Validación real durante el desarrollo (sobre la misma VM):

| Ejecución | Resultado |
| --- | --- |
| dark (1.ª) | 2 paneles `[top h=44] [bottom h=64]`, todo aplicado, sin franjas |
| light | `MacTahoe-Light`, iconos `MacTahoe-light`, `widgetStyle=kvantum`, Kvantum `MacTahoe` |
| dark (repetida) | Vuelve a `MacTahoe-Dark` sin residuos, plasmashell activo |

## Verificación

Valores esperados (oscilan según la variante elegida):

```bash
kreadconfig6 --file kdeglobals --group KDE       --key LookAndFeelPackage   # com.github.vinceliuice.MacTahoe-Dark
kreadconfig6 --file kdeglobals --group General   --key ColorScheme          # MacTahoeDark
kreadconfig6 --file kdeglobals --group Icons     --key Theme                # MacTahoe-dark
kreadconfig6 --file kdeglobals --group KDE       --key widgetStyle          # kvantum-dark
kreadconfig6 --file plasmarc   --group Theme     --key name                 # MacTahoe-Dark
kreadconfig6 --file kcminputrc --group Mouse     --key cursorTheme          # MacTahoe-dark
kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key library       # org.kde.kwin.aurorae
kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme         # __aurorae__svg__MacTahoe-Dark
grep -h '^theme=' ~/.config/Kvantum/kvantum.kvconfig                        # theme=MacTahoeDark
```

Paneles vivos por DBus:

```bash
gdbus call --session --dest org.kde.plasmashell --object-path /PlasmaShell \
  --method org.kde.PlasmaShell.evaluateScript \
  'var ps=panels(); var o="paneles="+ps.length; for (var i=0;i<ps.length;i++){ o+=" ["+ps[i].location+" h="+ps[i].height+"]"; } print(o);'
```

Comprobación visual desde el host (VM en libvirt/Boxes):

```bash
virsh screenshot <dominio> /tmp/vm.png
# si sale negra es que la pantalla está en reposo:
virsh qemu-monitor-command <dominio> --hmp 'sendkey ctrl'
```

> [!TIP] Cómo “mirar” la captura sin verla
> Analiza la media de color por fila con Pillow: las franjas de letterbox o un panel mal pintado aparecen como
> bandas de color plano (blanco/gris) arriba o abajo, mientras que el fondo correcto da degradados azules.
>
> ```python
> from PIL import Image
>
> im = Image.open('/tmp/vm.png').convert('RGB')
> def row(y):
>     px = [im.getpixel((x, y)) for x in range(0, im.width, 20)]
>     return tuple(round(sum(p[i] for p in px) / len(px)) for i in range(3))
>
> print(row(2), row(im.height // 2), row(im.height - 5))
> ```

## Volver atrás

```bash
cd ~/MacTahoe-kde && ./uninstall.sh
tar xzf ~/.local/state/mactahoe/backups/kde-<fecha>.tar.gz -C ~
systemctl --user restart plasma-plasmashell.service
```

Limpieza completa (opcional):

```bash
rm -rf ~/.local/share/icons/MacTahoe* ~/.local/share/plasma/desktoptheme/MacTahoe* \
       ~/.local/share/plasma/look-and-feel/com.github.vinceliuice.MacTahoe* ~/.config/Kvantum
sudo dnf remove kvantum
```

## Solución de problemas

| Síntoma | Causa | Arreglo |
| --- | --- | --- |
| `ERROR: No hay sesion grafica en /run/user/<uid>` | No hay sesión KDE iniciada (o se ejecuta desde tty) | Entra en la sesión gráfica y relanza; el script necesita el bus de sesión |
| El dock aparece vacío y el journal muestra `Could not find required file "mainscript" ... icontasks` | **Plasma 6.6/Fedora 44** no carga `org.kde.plasma.icontasks` (paquete con sólo `metadata.json`) | En la rama `fedora-44-plasma-6.6` los layouts usan `org.kde.plasma.taskmanager` (dock con texto junto al icono). En Plasma 6.7 el paquete es válido y carga |
| Sólo cambian los colores; iconos/cursor/decoración siguen con Breeze | `lookandfeeltool` de Plasma 6.6 aplica únicamente colores y `LookAndFeelPackage` | El script parsea `contents/defaults` y escribe cada entrada con `kwriteconfig6` |
| Franja blanca arriba y abajo que parece “otro panel” | Fondo 3840x2160 (16:9) con `FillMode=1` (`KeepAspectRatio`) en pantalla 16:10 → letterbox | El script fuerza `FillMode=2` |
| Captura `virsh screenshot` en negro con `Display output is not active` | La pantalla de la VM está en reposo | `virsh qemu-monitor-command <dominio> --hmp 'sendkey ctrl'` y volver a capturar |
| Pantalla bloqueada al capturar | Bloqueo por inactividad | `loginctl unlock-session <id>` dentro de la VM; los cambios se aplican igualmente |
| La decoración vuelve a Breeze sola | kwin hizo fallback porque el tema Aurorae no cargó | Revisa `kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key library`; reinstala con el script |
| `No hay bus de sesion` pese a tener sesión | Variable de entorno o `$XDG_RUNTIME_DIR` distinto | El script lo calcula de `/run/user/<uid>`; si usas otro uid, ajústalo |
| `No hay directorios de Global Themes` / falla `lookandfeeltool` | Paquete no instalado o ruta incorrecta | Ejecuta `./install.sh` primero (lo hace el script) y revisa `~/.local/share/plasma/look-and-feel` |
| Sin red en la VM al descargar iconos | NAT de libvirt caído o DNS | Comprueba `ip route` en la VM y `virsh net-list --all` en el host |

## Parches locales incluidos

| Fichero | Cambio | Motivo |
| --- | --- | --- |
| `install.sh` | `LAYOUT_DIR="${dest}/share/plasma/layout-templates"` | En la rama root estaba hardcodeado a `/usr` |
| `install.sh` | `-n/--name` → `name="${2}"; shift 2` | El original guardaba el propio flag y rompía la opción |
| `plasma/look-and-feel/com.github.vinceliuice.MacTahoe-Dark/contents/layouts/org.kde.plasma.desktop-layout.js` | `org.kde.plasma.icontasks` → `org.kde.plasma.taskmanager` | **Sólo rama `fedora-44-plasma-6.6`** (Plasma 6.6): el applet “Icons-only task manager” no carga |
| `plasma/look-and-feel/com.github.vinceliuice.MacTahoe-Light/contents/layouts/org.kde.plasma.desktop-layout.js` | ídem | ídem |
| `plasma/layout-templates/org.github.desktop.MacOSDock/contents/layout.js` | ídem | ídem |

> Nota: en la rama `fedora-45-beta` (Plasma 6.7) **no** se aplica este parche: `org.kde.plasma.icontasks` carga
> y da el dock de sólo iconos (su `main.qml` fuerza `iconsOnly` según el `pluginName`).

Commits de la rama local `fedora-44-plasma-6.6`:

- `dd15e3d` — fix: plasma 6.6 / fedora compatibility fixes
- `887df8f` — feat: reproducible Fedora KDE Plasma 6 provisioning scripts

## Compatibilidad y mantenimiento

- **Fedora 44 / Plasma 6.6.4 / Qt 6.10.2 / Wayland**: soportado y verificado (rama `fedora-44-plasma-6.6`).
- **Fedora 45 beta / Plasma 6.7.4 / Qt 6.11.1 / Wayland**: soportado y verificado (rama `fedora-45-beta`).
  Los parches en Plasma 6.7 se reducen a `install.sh`: el **dock de sólo iconos funciona** con `icontasks`
  (a diferencia de Plasma 6.6) y `lookandfeeltool` sigue aplicando sólo una parte de `defaults`. kvantum para
  esta release es `1.1.6-2.fc45` (no disponible en las rutas públicas de
  descarga de la beta: usa `dnf download` + `--rpm-dir`).
- **Aurorae** sigue presente en Plasma 6.6 y 6.7:
  `/usr/lib64/qt6/plugins/org.kde.kdecoration3/org.kde.kwin.aurorae.so`. Si kwin hiciera fallback, reescribiría
  `kwinrc` con `org.kde.breezedecoration`: es la señal para revisar el tema de Aurorae instalado.
- **Applets**: en Fedora 44 los applets “core” (reloj, bandeja, kickoff, taskmanager…) vienen **compilados** en
  `/usr/lib64/qt6/plugins/plasma/applets/*.so`, no como directorios en `/usr/share/plasma/plasmoids`. Por eso un
  `ls` de esa ruta engaña: el applet sí existe.
- **Actualizar desde upstream** conservando los parches:

  ```bash
  git switch fedora-44-plasma-6.6
  git pull upstream main          # o: git fetch upstream && git rebase upstream/main
  git cherry-pick dd15e3d 887df8f # tus commits locales, si el rebase los dejó fuera
  ```

  Tras actualizar, vuelve a revisar los ficheros parcheados: en la rama `fedora-45-beta` el layout debe seguir
  con `icontasks` (upstream podría reintroducir `taskmanager` y perderías el dock de sólo iconos).

## Alcance y fuera de alcance

**Incluido**: esquema de color, tema Plasma, decoración de ventana (Aurorae), iconos, cursores, estilo Qt
(Kvantum), fondo de pantalla, layout macOS (panel superior + dock) y recarga de la sesión.

**Fuera de alcance (por ahora)**:

| Pieza | Motivo / cómo activarla |
| --- | --- |
| Tema de login `sddm/` | Esta instalación **no trae SDDM**. Instalarlo: `sudo dnf install sddm sddm-wayland-plasma`, habilitarlo y aplicar `sddm/MacTahoe-6.0` |
| Blur tipo macOS (`kwin-effects-forceblur`) | Efecto externo [kwin-effects-forceblur](https://github.com/taj-ny/kwin-effects-forceblur); recomendado por el autor (esquinas 24 px) |
| Repo original de iconos | Se descarga automáticamente: [MacTahoe-icon-theme](https://github.com/vinceliuice/MacTahoe-icon-theme) |

## Referencias

- Tema original: <https://github.com/vinceliuice/MacTahoe-kde>
- Iconos y cursores: <https://github.com/vinceliuice/MacTahoe-icon-theme>
- Kvantum: <https://github.com/tsujan/Kvantum>
- Efecto de blur recomendado: <https://github.com/taj-ny/kwin-effects-forceblur>
