#!/usr/bin/env bash
# Enable (or disable) KWin's built-in Magic Lamp minimize effect (macOS-like genie animation).
# Meant to run inside the target machine, as the regular user, inside (or against) a Plasma session.

set -euo pipefail

APPLY=enable
DURATION=""
FORCE_SOFTWARE=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTION]...

  --disable           Revert to the default minimize animation (Squash)
  --duration MS       Animation duration in milliseconds (default: KWin default, 250ms)
  --force-software    If the GPU is a software renderer, set KWIN_EFFECTS_FORCE_ANIMATIONS=1
                      (requires logging out and back in).
  -h, --help          Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --disable) APPLY=disable; shift ;;
    --duration) DURATION="$2"; shift 2 ;;
    --force-software) FORCE_SOFTWARE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m    %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

run_qdbus() {
  gdbus call --session --dest org.kde.KWin --object-path "$1" --method "$2" "${@:3}" 2>&1
}

effect_loaded() {
  run_qdbus /Effects org.kde.kwin.Effects.isEffectLoaded "$1" | grep -q 'true'
}

effect_available() {
  run_qdbus /Effects org.freedesktop.DBus.Properties.Get org.kde.kwin.Effects listOfEffects \
    | grep -q "\b${1}\b"
}

try_load() {
  run_qdbus /Effects org.kde.kwin.Effects.loadEffect "$1" | grep -q 'true'
}

try_unload() {
  run_qdbus /Effects org.kde.kwin.Effects.unloadEffect "$1" >/dev/null
}

force_animations_file() {
  printf '[kwin]\nKWIN_EFFECTS_FORCE_ANIMATIONS=1\n' \
    > "${HOME}/.config/environment.d/95-kwin-force-animations.conf"
}

locate_session() {
  local uid runtime wayland
  uid="$(id -u)"
  runtime="/run/user/${uid}"
  [[ -d "${runtime}" ]] || die "No hay sesion grafica en ${runtime}; inicia sesion en KDE antes de ejecutar el script"
  export XDG_RUNTIME_DIR="${runtime}"
  export DBUS_SESSION_BUS_ADDRESS="unix:path=${runtime}/bus"
  wayland="$(ls -d ${runtime}/wayland-* 2>/dev/null | grep -v '\.lock$' | head -1 || true)"
  if [[ -n "${wayland}" ]]; then
    export WAYLAND_DISPLAY="$(basename "${wayland}")"
    export QT_QPA_PLATFORM=wayland
  fi
  export XDG_CURRENT_DESKTOP=KDE
  export DISPLAY="${DISPLAY:-:0}"
  [[ -S "${runtime}/bus" ]] || die "No hay bus de sesion (${runtime}/bus)"
}

animations_unsupported() {
  [[ "${APPLY}" == "enable" ]] || return 1
  effect_available squash || return 1
  effect_loaded squash && return 1
  try_load squash || return 0
  try_unload squash
  return 1
}

if [[ -n "${DURATION}" ]] && ! [[ "${DURATION}" =~ ^[0-9]+$ ]]; then
  die "--duration debe ser un numero de milisegundos"
fi

say "Sesion de Plasma"
locate_session
command -v kwriteconfig6 >/dev/null || die "No encuentro kwriteconfig6"
pgrep -x kwin_wayland >/dev/null || die "No hay una sesion de KWin Wayland activa"

say "Efecto integrado Magic Lamp disponible en kwin"
effect_available magiclamp \
  || die "Tu kwin no incorpora el efecto magiclamp"

if [[ "${APPLY}" == "enable" ]]; then
  say "Activando Magic Lamp (y desactivando Squash, grupo exclusivo minimize)"
  kwriteconfig6 --file kwinrc --group Plugins --key magiclampEnabled true
  kwriteconfig6 --file kwinrc --group Plugins --key squashEnabled false
  if [[ -n "${DURATION}" ]]; then
    say "Duracion de la animacion: ${DURATION} ms"
    kwriteconfig6 --file kwinrc --group Effect-magiclamp --key AnimationDuration "${DURATION}"
  fi
  if effect_loaded magiclamp || try_load magiclamp; then
    :
  elif animations_unsupported; then
    warn "El compositor no puede animar: kwin usa un renderizador GL por SOFTWARE"
    warn "(tipico en GNOME Boxes / virt-manager sin '3D acceleration' en la VM)."
    warn "KWin desactiva las animaciones por diseno y rechaza cargar magiclamp/squash/fade."
    if [[ "${FORCE_SOFTWARE}" -eq 1 ]]; then
      say "Forzando animaciones por software (KWIN_EFFECTS_FORCE_ANIMATIONS=1)"
      mkdir -p "${HOME}/.config/environment.d"
      force_animations_file
      say "Listo. Cierra sesion y vuelve a entrar para que kwin lea la variable;"
      say "luego relanza este script y el efecto se cargara."
    else
      say "Soluciones:"
      say "  1. Activa '3D acceleration' en la VM (accel3d=yes + spice gl=yes) y reinicia:"
      say "     es el arreglo correcto y las animaciones iran fluidas."
      say "  2. Relanza con --force-software para usar CPU (requiere logout/in)."
    fi
  else
    warn "magiclamp no se pudo cargar por una razon desconocida; revisa journalctl -u plasma-kwin_wayland"
  fi
  if effect_loaded squash; then
    try_unload squash
  fi
  run_qdbus /KWin org.kde.KWin.reconfigure >/dev/null
else
  say "Desactivando Magic Lamp (vuelvo a Squash)"
  kwriteconfig6 --file kwinrc --group Plugins --key magiclampEnabled false
  kwriteconfig6 --file kwinrc --group Plugins --key squashEnabled true
  if effect_loaded magiclamp; then
    try_unload magiclamp
  fi
  if ! effect_loaded squash; then
    try_load squash || warn "squash no quiso volver a cargar (situacion esperada si no hay acel. 3D)"
  fi
  rm -f "${HOME}/.config/environment.d/95-kwin-force-animations.conf"
  run_qdbus /KWin org.kde.KWin.reconfigure >/dev/null
fi

sleep 2

say "Estado final"
printf '  magiclampEnabled : %s\n' "$(kreadconfig6 --file kwinrc --group Plugins --key magiclampEnabled)"
printf '  squashEnabled    : %s\n' "$(kreadconfig6 --file kwinrc --group Plugins --key squashEnabled)"
printf '  AnimationDuration: %s\n' "$(kreadconfig6 --file kwinrc --group Effect-magiclamp --key AnimationDuration)"
if effect_loaded magiclamp; then
  printf '  Magic Lamp       : cargado (activo)\n'
  [[ "${APPLY}" == "enable" ]] && say "Listo. Minimiza una ventana y veras el efecto lámpara mágica hacia el dock."
else
  warn "Magic Lamp no esta cargado en kwin"
fi
if effect_loaded squash; then
  printf '  Squash           : cargado\n'
else
  printf '  Squash           : descargado\n'
fi