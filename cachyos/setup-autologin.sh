#!/usr/bin/env bash
# Habilita el autologin de SDDM (usuario + sesion Plasma) en CachyOS / Arch.
# Uso: ./setup-autologin.sh [USUARIO]    (por defecto: $USER)
set -euo pipefail

USERNAME="${1:-${USER:-$(id -un)}}"
CONF="/etc/sddm.conf.d/10-autologin.conf"

mkdir -p /etc/sddm.conf.d
umask 022

cat >"${CONF}" <<EOF
[Autologin]
User=${USERNAME}
Session=plasma
Relogin=true
EOF

echo "==> Autologin configurado: ${CONF}"
sed -n p "${CONF}"
echo
echo "Aplica en el proximo arranque (o ahora con: sudo systemctl restart sddm)"
echo "Nota: si al reiniciar pide password, anade el usuario al grupo autologin:"
echo "      sudo usermod -aG autologin ${USERNAME}"