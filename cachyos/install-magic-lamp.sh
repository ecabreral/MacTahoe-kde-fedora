#!/usr/bin/env bash
# Instala el efecto KWin "Yet Another Magic Lamp" (macOS-style minimize).
# Via AUR (paru/yay) si hay helper; si no, compila desde el fuente del fork.
# Uso: ./install-magic-lamp.sh
set -euo pipefail

AUR_PKG="kwin-effects-yet-another-magic-lamp-reloaded-git"
SRC_URL="https://github.com/koryboc/kwin-effects-yet-another-magic-lamp-reloaded"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m    %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
run_root() { if [[ "$(id -u)" -eq 0 ]]; then "$@"; else sudo "$@"; fi }

if pacman -Q "${AUR_PKG/-git/}" >/dev/null 2>&1 \
   || ls /usr/lib/qt6/plugins/kwin/effects/plugins/*yetanothermagiclamp* >/dev/null 2>&1; then
  say "El efecto ya esta instalado"
  exit 0
fi

install_via_helper() {
  local helper="$1"
  if command -v "${helper}" >/dev/null 2>&1; then
    say "Instalando ${AUR_PKG} con ${helper}"
    "${helper}" -S --noconfirm "${AUR_PKG}"
    return 0
  fi
  return 1
}

if install_via_helper paru || install_via_helper yay; then
  :
else
  say "Sin helper AUR; compilo desde el fuente (${SRC_URL})"
  BUILD="${HOME}/.cache/mactahoe/kwin-effects-yet-another-magic-lamp-reloaded"
  say "Instalando dependencias de compilacion"
  run_root pacman -S --noconfirm --needed \
    base-devel cmake ninja extra-cmake-modules \
    qt6-base qt6-declarative qt6-svg kwin kconfigwidgets kcoreaddons \
    kdeclarative kglobalaccel kpeople kservice ktextwidgets kwidgetsaddons kcmutils kwindowsystem
  if [[ -d "${BUILD}" ]]; then
    git -C "${BUILD}" pull --ff-only || true
  else
    git clone --depth 1 "${SRC_URL}" "${BUILD}"
  fi
  cmake -S "${BUILD}" -B "${BUILD}/build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr
  cmake --build "${BUILD}/build"
  run_root cmake --install "${BUILD}/build"
fi

say "Efecto instalado."
say "IMPORTANTE: cierra sesion y vuelve a entrar (o reinicia) para que KWin catalogue"
say "el plugin; luego ejecuta: ./setup-magic-lamp.sh --yaml"