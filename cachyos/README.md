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

Esto escribe `/etc/sddm.conf.d/10-autologin.conf` con `[Autologin] User=<tu-usuario> Session=plasma Relogin=true`.

Si al reiniciar aun pide password: `sudo usermod -aG autologin ${USER}`.