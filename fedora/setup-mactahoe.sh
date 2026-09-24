#!/usr/bin/env bash
# Provision a Fedora KDE Plasma 6 machine with the MacTahoe-kde theme.
# Meant to run inside the target machine, as the regular user, inside (or against) a Plasma session.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ICON_REPO_URL="https://codeload.github.com/vinceliuice/MacTahoe-icon-theme/tar.gz/refs/heads/main"
ICON_CACHE="${HOME}/.cache/mactahoe/MacTahoe-icon-theme"
BACKUP_DIR="${HOME}/.local/state/mactahoe/backups"
APPLY_LAYOUT=1
ENABLE_SSH=0
INSTALL_ICONS=1
VARIANT="-Dark"
BUNDLE_DIR=""
OFFLINE=0
ICON_FILE_NAMES=( "MacTahoe-icon-theme.tar.gz" "MacTahoe-icon-theme.tar" )

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTION]...

  -v, --variant VARIANT   Theme variant: dark or light (Default: dark)
      --bundle DIR        Use files from a local bundle instead of downloading
      --offline           Never use the network; warn if something is missing
      --no-layout         Keep the current panels instead of applying the macOS layout
      --no-icons          Skip installing the MacTahoe icon/cursor theme
      --enable-ssh        Install and enable sshd (sudo)
      --reboot            Reboot when finished
  -h, --help              Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--variant)
      case "${2:-}" in
        dark) VARIANT="-Dark" ;;
        light) VARIANT="-Light" ;;
        *) echo "Unknown variant: ${2:-}"; exit 1 ;;
      esac
      shift 2
      ;;
    --no-layout) APPLY_LAYOUT=0; shift ;;
    --no-icons) INSTALL_ICONS=0; shift ;;
    --bundle) BUNDLE_DIR="$2"; shift 2 ;;
    --offline) OFFLINE=1; shift ;;
    --enable-ssh) ENABLE_SSH=1; shift ;;
    --reboot) REBOOT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

PLASMA_THEME="MacTahoe${VARIANT}"
LOOKFEEL_ID="com.github.vinceliuice.MacTahoe${VARIANT}"
KVANTUM_THEME="MacTahoe"
[[ "${VARIANT}" == "-Dark" ]] && KVANTUM_THEME="MacTahoeDark"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m    %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

detect_bundle() {
  local parent
  [[ -z "${BUNDLE_DIR}" ]] || return 0
  parent="$(cd "${REPO_ROOT}/.." 2>/dev/null && pwd)"
  [[ -n "${parent}" && -d "${parent}" ]] || return 0
  if ls "${parent}"/kvantum-*.rpm >/dev/null 2>&1; then
    BUNDLE_DIR="${parent}"
    return 0
  fi
  for name in "${ICON_FILE_NAMES[@]}"; do
    if [[ -f "${parent}/${name}" ]]; then
      BUNDLE_DIR="${parent}"
      return 0
    fi
  done
}

detect_bundle
[[ -n "${BUNDLE_DIR}" ]] && say "Bundle local detectado en ${BUNDLE_DIR}"

find_bundle_icons() {
  local name
  [[ -n "${BUNDLE_DIR}" ]] || return 1
  for name in "${ICON_FILE_NAMES[@]}"; do
    if [[ -f "${BUNDLE_DIR}/${name}" ]]; then
      printf '%s' "${BUNDLE_DIR}/${name}"
      return 0
    fi
  done
  return 1
}

install_kvantum() {
  if rpm -q kvantum >/dev/null 2>&1; then
    say "kvantum ya instalado"
    return 0
  fi
  local rpms=()
  if [[ -n "${BUNDLE_DIR}" ]]; then
    shopt -s nullglob
    rpms=("${BUNDLE_DIR}"/kvantum-*.rpm)
    shopt -u nullglob
  fi
  if [[ ${#rpms[@]} -gt 0 ]]; then
    say "Instalando kvantum desde el bundle (local)"
    if run_root dnf install -y --disablerepo='*' "${rpms[@]}" || run_root rpm -Uvh --replacepkgs "${rpms[@]}"; then
      if rpm -q kvantum >/dev/null 2>&1; then
        return 0
      fi
    fi
    warn "No se pudo instalar kvantum desde el bundle"
  fi
  if [[ "${OFFLINE}" -eq 1 ]]; then
    warn "Modo offline: sigo sin kvantum (luego: sudo dnf install kvantum)"
    return 0
  fi
  say "Instalando kvantum desde los repos (sudo)"
  run_root dnf install -y kvantum || warn "kvantum no se pudo instalar; el resto del tema se aplica igual"
}

install_icon_theme() {
  if [[ -d "${HOME}/.local/share/icons/MacTahoe" ]]; then
    say "Iconos MacTahoe ya instalados"
    return 0
  fi
  local tarball flags="z"
  mkdir -p "${ICON_CACHE}"
  if tarball="$(find_bundle_icons)"; then
    say "Instalando iconos y cursores desde el bundle"
    [[ "${tarball}" == *.tar.gz ]] || flags=""
    tar x"${flags}"f "${tarball}" -C "${ICON_CACHE}" --strip-components=1
  else
    if [[ "${OFFLINE}" -eq 1 ]]; then
      warn "Modo offline y sin tarball de iconos: omito iconos y cursores"
      return 0
    fi
    say "Descargando MacTahoe icon theme"
    curl -fsSL "${ICON_REPO_URL}" -o "${ICON_CACHE}.tar.gz"
    tar xzf "${ICON_CACHE}.tar.gz" -C "${ICON_CACHE}" --strip-components=1
  fi
  ( cd "${ICON_CACHE}" && ./install.sh >/dev/null ) || warn "Fallo el instalador de iconos"
  [[ -d "${HOME}/.local/share/icons/MacTahoe" ]] || warn "No quedaron instalados los iconos MacTahoe"
}

run_root() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

locate_session() {
  local uid runtime wayland
  uid="$(id -u)"
  runtime="/run/user/${uid}"
  [[ -d "${runtime}" ]] || die "No hay sesion grafica en ${runtime}; inicia sesion en KDE antes de ejecutar el script"
  export XDG_RUNTIME_DIR="${runtime}"
  export DBUS_SESSION_BUS_ADDRESS="unix:path=${runtime}/bus"
  wayland="$(ls -d ${runtime}/wayland-* 2>/dev/null | grep -v '\.lock$' | head -1)"
  if [[ -n "${wayland}" ]]; then
    export WAYLAND_DISPLAY="$(basename "${wayland}")"
    export QT_QPA_PLATFORM=wayland
  fi
  export XDG_CURRENT_DESKTOP=KDE
  export DISPLAY="${DISPLAY:-:0}"
  [[ -S "${runtime}/bus" ]] || die "No hay bus de sesion (${runtime}/bus)"
}

plasma_shell_pid() { pgrep -x plasmashell | head -1; }

evaluate_plasma_script() {
  gdbus call --session --dest org.kde.plasmashell --object-path /PlasmaShell \
    --method org.kde.PlasmaShell.evaluateScript "$1" 2>/dev/null | sed -E "s/^\('(.*)',\)$/\1/"
}

kwin_reconfigure() {
  gdbus call --session --dest org.kde.KWin --object-path /KWin --method org.kde.KWin.reconfigure >/dev/null 2>&1 || true
}

kwin_script() {
  gdbus call --session --dest org.kde.KWin --object-path /Scripting --method org.kde.kwin.Scripting.loadScript >/dev/null 2>&1 || true
}

restart_shell() {
  if systemctl --user restart plasma-plasmashell.service >/dev/null 2>&1; then
    return 0
  fi
  kquitapp6 plasmashell >/dev/null 2>&1 || true
  sleep 2
  plasma_shell_pid >/dev/null || setsid plasmashell >/dev/null 2>&1 &
}

say "Sesion de Plasma"
locate_session
command -v plasmashell >/dev/null || die "No encuentro plasmashell; esto no es una sesion KDE"
PLASMA_VERSION="$(plasmashell --version 2>/dev/null | awk '{print $NF}')"
say "Plasma ${PLASMA_VERSION} detectado"
[[ -d "${HOME}/.local/share/plasma/look-and-feel" || -d /usr/share/plasma/look-and-feel ]] || die "No hay directorios de Global Themes"

say "Backup de la configuracion actual"
mkdir -p "${BACKUP_DIR}"
STAMP="$(date +%Y%m%d-%H%M%S)"
tar czf "${BACKUP_DIR}/kde-${STAMP}.tar.gz" -C "${HOME}" .config .local/share/plasma .config/Kvantum 2>/dev/null || true
say "Backup en ${BACKUP_DIR}/kde-${STAMP}.tar.gz"

if [[ "${OFFLINE}" -eq 1 ]]; then
  say "Modo offline activo: no se usa la red"
fi

if [[ "${ENABLE_SSH}" -eq 1 ]]; then
  say "Instalando y activando sshd"
  run_root dnf install -y openssh-server
  run_root systemctl enable --now sshd
  run_root firewall-cmd --permanent --add-service=ssh || true
  run_root firewall-cmd --reload || true
fi

if [[ "${INSTALL_ICONS}" -eq 1 ]]; then
  install_kvantum
  install_icon_theme
fi

say "Instalando el tema ${PLASMA_THEME}"
( cd "${REPO_ROOT}" && ./install.sh )

say "Aplicando Global Theme ${LOOKFEEL_ID}"
lookandfeeltool -a "${LOOKFEEL_ID}" >/dev/null 2>&1 || warn "lookandfeeltool devolvio un error; aplico las claves manualmente"

DEFAULTS_FILE="${HOME}/.local/share/plasma/look-and-feel/${LOOKFEEL_ID}/contents/defaults"
[[ -f "${DEFAULTS_FILE}" ]] || die "No esta instalado el look-and-feel ${LOOKFEEL_ID}"

say "Escribiendo las claves de defaults"
current_file=""
current_group=""
while IFS= read -r line; do
  case "${line}" in
    \[*\]\[*\])
      inner="${line#[}"
      current_file="${inner%%]*}"
      rest="${inner#*][}"
      current_group="${rest%]}"
      ;;
    *=*)
      key="${line%%=*}"
      value="${line#*=}"
      [[ -n "${current_file}" && -n "${current_group}" ]] || continue
      kwriteconfig6 --file "${current_file}" --group "${current_group}" --key "${key}" "${value}"
      ;;
  esac
done < "${DEFAULTS_FILE}"
kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle "$( [[ "${VARIANT}" == "-Dark" ]] && echo kvantum-dark || echo kvantum )"
kwriteconfig6 --file kdeglobals --group General --key ColorScheme "$( [[ "${VARIANT}" == "-Dark" ]] && echo MacTahoeDark || echo MacTahoeLight )"

say "Ajustando Kvantum (${KVANTUM_THEME})"
mkdir -p "${HOME}/.config/Kvantum"
printf '[General]\ntheme=%s\n' "${KVANTUM_THEME}" > "${HOME}/.config/Kvantum/kvantum.kvconfig"

if [[ "${APPLY_LAYOUT}" -eq 1 ]]; then
  say "Aplicando el layout macOS (panel superior + dock)"
  cp "${HOME}/.config/plasma-org.kde.plasma.desktop-appletsrc" "${BACKUP_DIR}/appletsrc-${STAMP}" 2>/dev/null || true
  LAYOUT_FILE="${HOME}/.local/share/plasma/look-and-feel/${LOOKFEEL_ID}/contents/layouts/org.kde.plasma.desktop-layout.js"
  [[ -f "${LAYOUT_FILE}" ]] || die "No encuentro ${LAYOUT_FILE}"
  REMOVAL='var ps=panels(); for (var i=0;i<ps.length;i++){ ps[i].remove(); } print("borrados="+ps.length);'
  evaluate_plasma_script "${REMOVAL}"
  sleep 2
  evaluate_plasma_script "$(cat "${LAYOUT_FILE}")"
  sleep 3
fi

say "Fondo de pantalla (relleno completo)"
WALLPAPER_DIR="${HOME}/.local/share/wallpapers/${PLASMA_THEME}/contents/images"
if compgen -G "${WALLPAPER_DIR}"/*.jpeg >/dev/null; then
  WALLPAPER="$(ls -1 "${WALLPAPER_DIR}"/*.jpeg | head -1)"
  evaluate_plasma_script "var ds=desktops(); for (var i=0;i<ds.length;i++){ ds[i].wallpaperPlugin=\"org.kde.image\"; ds[i].currentConfigGroup=[\"Wallpaper\",\"org.kde.image\",\"General\"]; ds[i].writeConfig(\"Image\",\"file://${WALLPAPER}\"); ds[i].writeConfig(\"FillMode\",2); } print(\"wallpapers=\"+ds.length);"
else
  warn "No hay fondo en ${WALLPAPER_DIR}"
fi

say "Recargando KWin y plasmashell"
kwin_reconfigure
restart_shell
sleep 6

say "Estado final"
printf '  Global theme      : %s\n' "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)"
printf '  Tema Plasma       : %s\n' "$(kreadconfig6 --file plasmarc --group Theme --key name)"
printf '  Esquema de color  : %s\n' "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)"
printf '  Iconos / cursores : %s / %s\n' "$(kreadconfig6 --file kdeglobals --group Icons --key Theme)" "$(kreadconfig6 --file kcminputrc --group Mouse --key cursorTheme)"
printf '  Decoracion kwin   : %s / %s\n' "$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key library)" "$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme)"
printf '  Estilo Qt         : %s (Kvantum: %s)\n' "$(kreadconfig6 --file kdeglobals --group KDE --key widgetStyle)" "$(grep -h '^theme=' "${HOME}/.config/Kvantum/kvantum.kvconfig" 2>/dev/null)"
pgrep -x plasmashell >/dev/null && printf '  plasmashell       : activo\n' || warn "plasmashell no esta corriendo"
evaluate_plasma_script 'var ps=panels(); var o="  Paneles           : "+ps.length; for (var i=0;i<ps.length;i++){ o+=" ["+ps[i].location+" h="+ps[i].height+"]"; } print(o);'

say "Listo. Para volver atras: ./uninstall.sh y restaura ${BACKUP_DIR}/kde-${STAMP}.tar.gz"

if [[ "${REBOOT:-0}" -eq 1 ]]; then
  say "Reiniciando"
  run_root reboot
fi
