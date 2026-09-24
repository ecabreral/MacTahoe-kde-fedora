# CachyOS

Scripts de configuracion para CachyOS / Arch con KDE Plasma.

## Autologin (SDDM)

Desde la maquina CachyOS (con internet), descarga el repo y ejecuta:

```bash
git clone -b cachyos https://github.com/ecabreral/MacTahoe-kde-fedora.git /tmp/mac_kde
chmod +x /tmp/mac_kde/cachyos/setup-autologin.sh
cd /tmp/mac_kde/cachyos && sudo ./setup-autologin.sh "${USER}"
sudo systemctl restart sddm
```

El script detecta el gestor de sesion:
- **plasmalogin** (Plasma Login Manager, el estandar de CachyOS) → escribe `/etc/plasmalogin.conf.d/autologin.conf` y anade el usuario al grupo `plasmalogin`.
- **SDDM** (si existiera) → escribe `/etc/sddm.conf.d/10-autologin.conf`.

Si volviera a pedir password: revisa `systemctl status plasmalogin` y que el usuario este en el grupo `plasmalogin` (`groups $USER`).