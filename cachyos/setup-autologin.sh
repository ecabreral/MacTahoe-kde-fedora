#!/usr/bin/env bash
# Habilita el autologin (gestor plasmalogin de CachyOS, o SDDM si existiera).
# Uso: ./setup-autologin.sh [USUARIO]    (por defecto: $USER)
set -euo pipefail

USERNAME="${1:-${USER:-$(id -un)}}"

if systemctl list-unit-files plasmalogin.service >/dev/null 2>&1; then
    # Plasma Login Manager (CachyOS)
    DIR="/etc/plasmalogin.conf.d"
    CONF="${DIR}/autologin.conf"
    mkdir -p "${DIR}"
    umask 022

    if getent group plasmalogin >/dev/null; then
        usermod -aG plasmalogin "${USERNAME}"
        echo "==> usuario '${USERNAME}' anadido al grupo plasmalogin"
    fi

    cat >"${CONF}" <<EOF
[Autologin]
User=${USERNAME}
Session=plasma
Relogin=true
EOF

    echo "==> Autologin configurado: ${CONF}"
    cat "${CONF}"
    echo
    echo "Aplica ahora con: sudo systemctl restart plasmalogin"
    echo "(o en el proximo arranque)"
else
    # SDDM
    DIR="/etc/sddm.conf.d"
    CONF="${DIR}/10-autologin.conf"
    mkdir -p "${DIR}"
    umask 022

    cat >"${CONF}" <<EOF
[Autologin]
User=${USERNAME}
Session=plasma
Relogin=true
EOF

    echo "==> Autologin configurado: ${CONF}"
    cat "${CONF}"
    echo
    echo "Aplica ahora con: sudo systemctl restart sddm"
    echo "(o en el proximo arranque)"
fi