# CachyOS

Scripts de configuracion para CachyOS / Arch con KDE Plasma 6.

## Instalacion completa (tema Mac OS + Magic Lamp)

Desde la maquina CachyOS (con internet), descarga el repo y ejecuta:

```bash
git clone -b cachyos https://github.com/ecabreral/MacTahoe-kde-fedora.git /tmp/mac_kde
cd /tmp/mac_kde/cachyos && chmod +x *.sh

# 1) Tema MacTahoe completo (plasma, aurorae, color, kvantum, iconos, dock macOS)
sudo ./setup-mactahoe.sh -v dark

# 2) Efecto "Yet Another Magic Lamp" (minimizar estilo macOS)
./install-magic-lamp.sh
# ... cierra sesion y vuelve a entrar (o reinicia) para que KWin catalogue el plugin ...

# 3) Activa el efecto como minimizacion exclusiva
./setup-magic-lamp.sh --yaml --duration 400
```

Opciones utiles de `setup-mactahoe.sh`: `-v light`, `--no-layout`, `--no-icons`,
`--enable-ssh`. Los iconos se bajan de `vinceliuice/MacTahoe-icon-theme` (o usa
`--bundle RUTA` si tienes el tarball local).

## Autologin (Plasma Login Manager)

```bash
sudo ./setup-autologin.sh "${USER}"
systemctl restart plasmalogin
```

## Notas

- El login manager de CachyOS es **plasmalogin** (Plasma Login Manager); el tema se
  aplica al greeter desde el tema Plasma (abre "Login Screen (SDDM)" y usa "Apply
  Plasma Settings", o ajusta `/var/lib/plasmalogin/.config`).
- `setup-magic-lamp.sh` y `install-magic-lamp.sh` necesitan sesion KWin Wayland activa.
- Efectos de minimizar alternativos: integrado `--builtin`, o volver a Squash con `--disable`.