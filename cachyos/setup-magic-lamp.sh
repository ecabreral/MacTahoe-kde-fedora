#!/usr/bin/env bash
# Enable (or disable) the Magic Lamp minimize effect: either KWin's built-in
# "magiclamp" or the more macOS/Compiz-like external "Yet Another Magic Lamp".
# Meant to run inside the target machine, as the regular user, inside a Plasma session.

set -euo pipefail

APPLY=enable
DURATION=""
CHOICE=auto
FORCE_SOFTWARE=0

BUILTIN_ID="magiclamp"
YAML_ID="kwin4_effect_yetanothermagiclamp"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTION]...

  --yaml              Use the external effect "Yet Another Magic Lamp"
                      (${YAML_ID}); requires it to be installed
                      (koryboc/kwin-effects-yet-another-magic-lamp-reloaded) and
                      requires a KWin restart / re-login after installing it.
  --builtin           Use KWin's built-in magiclamp effect.
  --disable           Revert to the default minimize animation (Squash).
  --duration MS       Animation duration in milliseconds (default: the effect's own).
  --force-software    If the GPU is a software renderer, set KWIN_EFFECTS_FORCE_ANIMATIONS=1
                      (requires logging out and back in).
  -h, --help          Show this help

Default: use Yet Another Magic Lamp if available, otherwise fall back to the
built-in magiclamp.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --disable) APPLY=disable; shift ;;
    --yaml) CHOICE=yaml; shift ;;
    --builtin) CHOICE=builtin; shift ;;
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

select_effect() {
  case "${CHOICE}" in
    builtin)
      EFFECT_ID="${BUILTIN_ID}"
      ;;
    yaml)
      effect_available "${YAML_ID}" || die \
  "El efecto 'Yet Another Magic Lamp' no aparece en kwin (${YAML_ID}).

  ¿Está instalado? KWin solo lo catalogue al arrancar: cierra sesion o reinicia
  la VM tras la instalacion y relanza este script."
      EFFECT_ID="${YAML_ID}"
      ;;
    auto)
      if effect_available "${YAML_ID}"; then
        EFFECT_ID="${YAML_ID}"
      else
        EFFECT_ID="${BUILTIN_ID}"
      fi
      ;;
  esac
}

minimize_ids() { printf '%s\n' "${BUILTIN_ID}" "${YAML_ID}" "squash"; }

other_minimize_ids() {
  local id
  while read -r id; do
    [[ "${id}" == "${EFFECT_ID}" ]] || printf '%s\n' "${id}"
  done < <(minimize_ids)
}

set_plugin_flag() { kwriteconfig6 --file kwinrc --group Plugins --key "${1}Enabled" "${2}"; }

if [[ -n "${DURATION}" ]] && ! [[ "${DURATION}" =~ ^[0-9]+$ ]]; then
  die "--duration debe ser un numero de milisegundos"
fi

say "Sesion de Plasma"
locate_session
command -v kwriteconfig6 >/dev/null || die "No encuentro kwriteconfig6"
pgrep -x kwin_wayland >/dev/null || die "No hay una sesion de KWin Wayland activa"

select_effect

if [[ "${APPLY}" == "enable" ]]; then
  if [[ "${EFFECT_ID}" == "${YAML_ID}" ]]; then
    say "Activando 'Yet Another Magic Lamp' ($(basename "${YAML_ID}")) y desactivando el resto (grupo exclusivo minimize)"
  else
    say "Activando el Magic Lamp integrado de kwin y desactivando el resto (grupo exclusivo minimize)"
  fi
  set_plugin_flag "${EFFECT_ID}" true
  local_effect="${EFFECT_ID}"
  while read -r id; do
    set_plugin_flag "${id}" false
  done < <(other_minimize_ids)
  if [[ -n "${DURATION}" ]]; then
    say "Duracion de la animacion: ${DURATION} ms"
    if [[ "${EFFECT_ID}" == "${YAML_ID}" ]]; then
      kwriteconfig6 --file kwinrc --group Effect-YetAnotherMagicLamp --key Duration "${DURATION}"
      kwriteconfig6 --file kwinrc --group Effect-YetAnotherMagicLamp --key StretchDuration "${DURATION}"
    else
      kwriteconfig6 --file kwinrc --group Effect-magiclamp --key AnimationDuration "${DURATION}"
    fi
  fi
  if effect_loaded "${EFFECT_ID}" || try_load "${EFFECT_ID}"; then
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
    warn "${EFFECT_ID} no se pudo cargar por una razon desconocida;"
    warn "revisa journalctl -u plasma-kwin_wayland"
  fi
  while read -r id; do
    effect_loaded "${id}" && try_unload "${id}"
  done < <(other_minimize_ids)
  run_qdbus /KWin org.kde.KWin.reconfigure >/dev/null
else
  say "Desactivando Magic Lamp (vuelvo a Squash)"
  set_plugin_flag "${EFFECT_ID}" false
  set_plugin_flag "squash" true
  if effect_loaded "${EFFECT_ID}"; then
    try_unload "${EFFECT_ID}"
  fi
  for id in "${BUILTIN_ID}" "${YAML_ID}"; do
    [[ "${id}" == "${EFFECT_ID}" ]] && continue
    if effect_loaded "${id}"; then
      try_unload "${id}"
      set_plugin_flag "${id}" false
    fi
  done
  if ! effect_loaded squash; then
    try_load squash || warn "squash no quiso volver a cargar (situacion esperada si no hay acel. 3D)"
  fi
  rm -f "${HOME}/.config/environment.d/95-kwin-force-animations.conf"
  run_qdbus /KWin org.kde.KWin.reconfigure >/dev/null
fi

sleep 2

say "Estado final"
printf '  Efecto minimizar  : %s\n' "${EFFECT_ID}"
printf '  magiclampEnabled  : %s\n' "$(kreadconfig6 --file kwinrc --group Plugins --key magiclampEnabled)"
printf '  yamlEnabled       : %s\n' "$(kreadconfig6 --file kwinrc --group Plugins --key ${YAML_ID}Enabled)"
printf '  squashEnabled     : %s\n' "$(kreadconfig6 --file kwinrc --group Plugins --key squashEnabled)"
if [[ "${EFFECT_ID}" == "${YAML_ID}" ]]; then
  printf '  Duration (YAML)   : %s\n' "$(kreadconfig6 --file kwinrc --group Effect-YetAnotherMagicLamp --key Duration)"
else
  printf '  AnimationDuration : %s\n' "$(kreadconfig6 --file kwinrc --group Effect-magiclamp --key AnimationDuration)"
fi
if effect_loaded "${EFFECT_ID}"; then
  printf '  %-17s: cargado (activo)\n' "${EFFECT_ID}"
  [[ "${APPLY}" == "enable" ]] && say "Listo. Minimiza una ventana y veras la animacion dirigida al dock."
else
  warn "${EFFECT_ID} no esta cargado en kwin"
fi
if effect_loaded squash; then
  printf '  Squash            : cargado\n'
else
  printf '  Squash            : descargado\n'
fi