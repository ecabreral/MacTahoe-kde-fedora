# MacTahoe-kde en Fedora KDE (Plasma 6 / Fedora 44)

Este directorio contiene el aprovisionamiento reproducible del tema `MacTahoe-kde` sobre una máquina
Fedora con KDE Plasma 6 (probado en **Fedora 44, Plasma 6.6.4, Qt 6.10, Wayland** dentro de GNOME Boxes).

Incluye también los parches locales que hacen falta para Plasma 6.6 (ver [Parches locales](#parches-locales)).

## Requisitos en la máquina de destino

- Fedora 44 (o superior) con el escritorio KDE Plasma 6 instalado y **sesión gráfica iniciada**.
- Usuario con `sudo`.
- `curl`, `tar`, `gdbus`, `kwriteconfig6`/`kreadconfig6`, `lookandfeeltool`, `pgrep` (vienen de serie en la
  instalación KDE de Fedora).
- Red (para descargar kvantum y el tema de iconos).

## Instalación en una VM nueva: dos formas

### A) Desde otra máquina (recomendado): un solo script

Requiere acceso SSH por clave (`ssh-copy-id usuario@IP`):

```bash
ssh-copy-id usuario@IP_DE_LA_VM          # una sola vez
./fedora/setup-remote.sh usuario@IP_DE_LA_VM
```

Ese script:
1. Verifica que hay SSH sin contraseña.
2. Copia este repo (sin `.git`) a `~/MacTahoe-kde` en la VM.
3. Ejecuta dentro de la VM `fedora/setup-mactahoe.sh` con TTY, para que `sudo` pregunte la contraseña normalmente.

### B) Desde dentro de la propia VM

```bash
# (si el repo ya esta en ~/MacTahoe-kde)
cd ~/MacTahoe-kde && ./fedora/setup-mactahoe.sh
```

## Opciones útiles

| Opción | Qué hace |
| --- | --- |
| `-v dark` / `-v light` | Variante del tema (por defecto `dark`). La clara usa iconos/cursores `MacTahoe-light`, kvantum `MacTahoe` y `widgetStyle=kvantum`. |
| `--no-layout` | No toca los paneles actuales; sólo aplica el aspecto (colores, tema Plasma, Aurorae, Kvantum, iconos). |
| `--no-icons` | No instala el tema de iconos/cursores compañero. |
| `--enable-ssh` | Instala y activa `sshd` + abre el servicio en el cortafuegos (útil en una VM recién creada). |
| `--reboot` | Reinicia al terminar. |

Ejemplo típico para una VM nueva, desde el host:

```bash
./fedora/setup-remote.sh xmoul@192.168.122.109 --enable-ssh --variant dark
```

## Qué hace exactamente el script

1. **Localiza la sesión** Plasma leyendo `/run/user/<uid>/bus` y el socket Wayland (por eso funciona también
   por SSH mientras la sesión gráfica está viva).
2. **Backup** de `~/.config`, `~/.local/share/plasma` y `~/.config/Kvantum` en
   `~/.local/state/mactahoe/backups/kde-<fecha>.tar.gz`.
3. **Dependencias**: `dnf install kvantum` (por `sudo`).
4. **Iconos y cursores**: descarga el tarball de `vinceliuice/MacTahoe-icon-theme`, ejecuta su `install.sh`
   en modo usuario y deja `MacTahoe`, `MacTahoe-light` y `MacTahoe-dark` en `~/.local/share/icons`
   (el paquete de iconos incluye dentro el directorio `cursors/`, por eso el cursor se llama igual que el tema
   de iconos).
5. **Tema**: ejecuta el `install.sh` de este repo (modo usuario → `~/.local/share/{color-schemes,plasma,wallpapers,aurorae}`
   y `~/.config/Kvantum`).
6. **Global Theme**: `lookandfeeltool -a com.github.vinceliuice.MacTahoe-Dark`.
7. **Claves de `defaults`**: en Plasma 6.6 `lookandfeeltool` sólo aplica colores y `LookAndFeelPackage`;
   el script parsea el fichero `contents/defaults` del paquete instalado y escribe cada entrada con
   `kwriteconfig6` (iconos, cursor, `widgetStyle`, `plasmarc` y la decoración de `kwinrc`).
8. **Kvantum**: `~/.config/Kvantum/kvantum.kvconfig` → `theme=MacTahoeDark` (o `MacTahoe` en claro).
9. **Layout macOS**: borra los paneles existentes y ejecuta, vía DBus (`org.kde.PlasmaShell.evaluateScript`),
   el `desktop-layout.js` del look-and-feel → panel superior + dock inferior (64 px, `fit`, `dodgewindows`).
10. **Fondo de pantalla** con `FillMode=2` (recorta para rellenar) para evitar las franjas de letterbox.
11. **Recarga** KWin (`reconfigure`) y `plasmashell`, y muestra el estado final.

## Verificación

Desde la máquina de destino (o por SSH):

```bash
kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage   # com.github.vinceliuice.MacTahoe-Dark
kreadconfig6 --file plasmarc   --group Theme --key name               # MacTahoe-Dark
kreadconfig6 --file kdeglobals --group Icons --key Theme              # MacTahoe-dark
kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme   # __aurorae__svg__MacTahoe-Dark
```

Y desde el host, si la VM está en libvirt/Boxes:

```bash
virsh screenshot <dominio> /tmp/vm.png     # si sale negro: la pantalla esta apagada,
virsh qemu-monitor-command <dominio> --hmp 'sendkey ctrl'   # pulsa una tecla para despertarla
```

Truco: para comprobar franjas/paneles sin ver la imagen, analiza filas con Python/Pillow
(media de color por fila) y compara antes/después.

## Volver atrás

```bash
cd ~/MacTahoe-kde && ./uninstall.sh
tar xzf ~/.local/state/mactahoe/backups/kde-<fecha>.tar.gz -C ~
systemctl --user restart plasma-plasmashell.service
```

## Incidencias conocidas y por qué están así

| Problema | Causa | Solución aplicada |
| --- | --- | --- |
| El dock sale vacío y en el journal aparece `Could not find required file "mainscript" ... icontasks` | Plasma 6.6/Fedora 44 ya no trae el applet `org.kde.plasma.icontasks` (queda sólo un `metadata.json` suelto); el gestor de tareas es `org.kde.plasma.taskmanager`, compilado en `/usr/lib64/qt6/plugins/plasma/applets/` | Parche en los 3 ficheros de layout (`icontasks` → `taskmanager`) |
| `lookandfeeltool` no aplica iconos, cursor, `widgetStyle`, tema Plasma ni decoración | En Plasma 6.6 sólo aplica el esquema de color y `LookAndFeelPackage` | El script reescribe todas las entradas del fichero `defaults` con `kwriteconfig6` |
| Franja blanca arriba y abajo, que parece “otro panel” | El fondo 3840x2160 (16:9) se pintaba con `FillMode=1` (`KeepAspectRatio`) en una pantalla 16:10 → letterbox | `FillMode=2` |
| Aurorae sigue activo tras `reconfigure` | Compatible en Plasma 6.6 (`/usr/lib64/qt6/plugins/org.kde.kdecoration3/org.kde.kwin.aurorae.so`) | Sin cambios; si kwin hiciera fallback, reescribiría `kwinrc` con `org.kde.breezedecoration` |
| El tema de login (`sddm/`) no se puede usar | Esta instalación no tiene SDDM instalado | Fuera de alcance: `sudo dnf install sddm sddm-wayland-plasma` y aplicar `sddm/MacTahoe-6.0` |

## Parches locales incluidos

- `install.sh`: respeta `${dest}` para `layout-templates` en la rama root; corrige `-n/--name`, que guardaba el
  flag en vez de su valor.
- `plasma/look-and-feel/com.github.vinceliuice.MacTahoe-Dark|Light/contents/layouts/org.kde.plasma.desktop-layout.js`
  y `plasma/layout-templates/org.github.desktop.MacOSDock/contents/layout.js`: `org.kde.plasma.taskmanager`
  en lugar de `org.kde.plasma.icontasks`.

Se guardaron en la rama local `fedora-44-plasma-6.6` (no se suben a `origin`).

## Notas para reconstruir el escenario desde cero (GNOME Boxes)

1. Crear la VM con la ISO de Fedora KDE Desktop y completar la instalación.
2. Dentro de la VM activar SSH:
   `sudo dnf install -y openssh-server && sudo systemctl enable --now sshd`
   (el script puede hacerlo con `--enable-ssh`).
3. Desde el host averiguar la IP: `virsh domifaddr <dominio> --source arp`.
4. `ssh-copy-id usuario@IP` y luego `./fedora/setup-remote.sh usuario@IP`.
5. Opcional: reservar la IP por DHCP en la red `virbr0` (requiere root en el host) para que no cambie al
   reiniciar la VM.
