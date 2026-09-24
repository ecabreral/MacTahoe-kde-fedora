#!/usr/bin/env bash
# Copy this repo to a Fedora KDE machine over SSH and run fedora/setup-mactahoe.sh there.
# Run it from any host that has ssh + rsync and access to the target machine.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-}"
REMOTE_DIR="${REMOTE_DIR:-MacTahoe-kde}"
shift $(( $# > 0 ? 1 : 0 ))

usage() {
  cat <<EOF
Usage: $(basename "$0") <ssh-destino> [opciones de setup-mactahoe.sh]

  <ssh-destino>   Alias o usuario@host de la maquina con Fedora KDE
                  (ej. usuario@192.168.122.109 o el alias ~/.ssh/config)

Opciones que se reenvian al script remoto:
  -v, --variant dark|light
      --no-layout
      --no-icons
      --enable-ssh
      --reboot

Variables de entorno:
  REMOTE_DIR=MacTahoe-kde   Directorio del repo en la maquina remota
EOF
}

[[ -n "${TARGET}" ]] || { usage; exit 1; }

command -v rsync >/dev/null || { echo "ERROR: falta rsync en el equipo local"; exit 1; }

printf '\033[1;36m==>\033[0m Probando conexion con %s\n' "${TARGET}"
ssh -o BatchMode=yes "${TARGET}" true 2>/dev/null || { echo "ERROR: no hay acceso ssh sin password a ${TARGET} (usa ssh-copy-id)"; exit 1; }

printf '\033[1;36m==>\033[0m Copiando el repo en %s:~/%s\n' "${TARGET}" "${REMOTE_DIR}"
rsync -a --delete --exclude .git "${REPO_ROOT}/" "${TARGET}:${REMOTE_DIR}/"

printf '\033[1;36m==>\033[0m Ejecutando setup-mactahoe.sh (te pedira la contrasena de sudo)\n'
ssh -t "${TARGET}" "cd ~/${REMOTE_DIR} && chmod +x fedora/setup-mactahoe.sh && ./fedora/setup-mactahoe.sh $*"
