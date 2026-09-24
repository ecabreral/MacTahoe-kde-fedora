#!/usr/bin/env bash
# Build a self-contained bundle (theme + icon theme + kvantum rpms) to copy into a Fedora KDE machine.
# Runs on the host that has this repository checked out.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

FEDORA_VERSION="${FEDORA_VERSION:-44}"
KVANTUM_VERSION="${KVANTUM_VERSION:-1.1.6}"
RPM_RELEASE="${RPM_RELEASE:-1}"
VARIANT="dark"
VERSION="${VERSION:-1.1.0}"
CACHE_DIR="${CACHE_DIR:-${HOME}/.cache/mactahoe-bundle}"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/dist}"
WORK_NAME="MacTahoe-kde-bundle"

ICON_REPO_URL="https://codeload.github.com/vinceliuice/MacTahoe-icon-theme/tar.gz/refs/heads/main"
ICON_FILE="MacTahoe-icon-theme.tar.gz"
FEDORA_BASE="https://dl.fedoraproject.org/pub/fedora/linux/releases"
KVANTUM_PKGS=( "kvantum" "kvantum-data" )

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTION]...

  --fedora VERSION   Fedora release for the kvantum rpms (Default: ${FEDORA_VERSION})
  --kvantum VERSION  kvantum version to fetch (Default: ${KVANTUM_VERSION})
  --version VERSION  Bundle version used in the file name (Default: ${VERSION})
  --out-dir DIR      Where to write the tarball (Default: ${OUT_DIR})
  --cache-dir DIR    Reuse downloaded files (Default: ${CACHE_DIR})
  --no cache         Ignore cached downloads and fetch everything again
  -h, --help         Show this help
EOF
}

FORCE_DOWNLOAD=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fedora) FEDORA_VERSION="$2"; shift 2 ;;
    --kvantum) KVANTUM_VERSION="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --cache-dir) CACHE_DIR="$2"; shift 2 ;;
    --no-cache) FORCE_DOWNLOAD=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m    %s\033[0m\n' "$*"; }

mkdir -p "${CACHE_DIR}" "${OUT_DIR}"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT
BUNDLE="${WORK_DIR}/${WORK_NAME}"
mkdir -p "${BUNDLE}/MacTahoe-kde"

say "Empaquetando el repo (tema con los parches locales)"
rsync -a --exclude .git --exclude .obsidian --exclude dist \
  "${REPO_ROOT}/" "${BUNDLE}/MacTahoe-kde/"

say "Descargando MacTahoe icon theme"
if [[ -f "${CACHE_DIR}/${ICON_FILE}" && "${FORCE_DOWNLOAD}" -eq 0 ]]; then
  cp "${CACHE_DIR}/${ICON_FILE}" "${BUNDLE}/${ICON_FILE}"
  warn "usando copia en cache"
else
  curl -fsSL "${ICON_REPO_URL}" -o "${BUNDLE}/${ICON_FILE}"
  cp "${BUNDLE}/${ICON_FILE}" "${CACHE_DIR}/${ICON_FILE}"
fi

say "Descargando kvantum ${KVANTUM_VERSION} para Fedora ${FEDORA_VERSION}"
K_DIR="k"
for pkg in "${KVANTUM_PKGS[@]}"; do
  arch="x86_64"
  [[ "${pkg}" == "kvantum-data" ]] && arch="noarch"
  rpm="${pkg}-${KVANTUM_VERSION}-${RPM_RELEASE}.fc${FEDORA_VERSION}.${arch}.rpm"
  url="${FEDORA_BASE}/${FEDORA_VERSION}/Everything/x86_64/os/Packages/${K_DIR}/${rpm}"
  if [[ -f "${CACHE_DIR}/${rpm}" && "${FORCE_DOWNLOAD}" -eq 0 ]]; then
    cp "${CACHE_DIR}/${rpm}" "${BUNDLE}/${rpm}"
  else
    curl -fsSL "${url}" -o "${BUNDLE}/${rpm}" || {
      warn "no se pudo descargar ${url}"
      warn "revisa --fedora/--kvantum o usa kvantum desde los repos de la maquina destino"
      exit 1
    }
    cp "${BUNDLE}/${rpm}" "${CACHE_DIR}/${rpm}"
  fi
done

say "Generando sumas de verificacion"
( cd "${BUNDLE}" && find . -maxdepth 1 -type f -printf '%f\n' | sort | xargs sha256sum > SHA256SUMS.txt )

cat > "${BUNDLE}/install.sh" <<'EOF'
#!/usr/bin/env bash
# Instalador del bundle: ejecuta TODO usando solo los ficheros locales.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
exec ./MacTahoe-kde/fedora/setup-mactahoe.sh --bundle "$(pwd)" "$@"
EOF
chmod +x "${BUNDLE}/install.sh"

cat > "${BUNDLE}/INSTALL.md" <<'INNER_EOF'
# MacTahoe-kde bundle VERSION_PLACEHOLDER

Instalacion en un solo comando (usa solo los ficheros del bundle):

```bash
tar xzf ~/MacTahoe-kde-bundle-VERSION_PLACEHOLDER.tar.gz
cd MacTahoe-kde-bundle
./install.sh                       # tema oscuro + layout macOS
# variantes utiles:
#   ./install.sh -v light           # tema claro
#   ./install.sh --no-layout        # no toca tus paneles
#   ./install.sh --offline          # prohible cualquier descarga
```

Que hace: instala kvantum desde los rpm incluidos, instala iconos y cursores desde el tarball
incluido, aplica el tema, el Global Theme, las claves de Plasma 6.6, Kvantum, el layout macOS
(panel superior 44 px + dock inferior 64 px), el fondo sin franjas y recarga la sesion.

Si prefieres hacerlo a mano, los pasos equivalente son:

```bash
sudo dnf install -y ./kvantum-*.rpm
mkdir -p ~/.cache/mactahoe/MacTahoe-icon-theme
tar xzf MacTahoe-icon-theme.tar.gz -C ~/.cache/mactahoe/MacTahoe-icon-theme --strip-components=1
( cd ~/.cache/mactahoe/MacTahoe-icon-theme && ./install.sh )
( cd MacTahoe-kde && ./install.sh )
lookandfeeltool -a com.github.vinceliuice.MacTahoe-Dark
```

Verificacion:

```bash
kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage
kreadconfig6 --file kdeglobals --group Icons --key Theme
kreadconfig6 --file plasmarc --group Theme --key name
kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme
```

El manual completo con todas las claves, rollback y solucion de problemas esta en
\`MacTahoe-kde/fedora/README.md\`.
INNER_EOF
sed -i "s/VERSION_PLACEHOLDER/${VERSION}/g" "${BUNDLE}/INSTALL.md"

OUT_FILE="${OUT_DIR}/MacTahoe-kde-bundle-${VERSION}.tar.gz"
say "Creando ${OUT_FILE}"
tar czf "${OUT_FILE}" -C "${WORK_DIR}" "${WORK_NAME}"
sha256sum "${OUT_FILE}" > "${OUT_DIR}/MacTahoe-kde-bundle-${VERSION}.sha256"

say "Bundle listo"
echo "  fichero : ${OUT_FILE}"
echo "  tamaño  : $(du -h "${OUT_FILE}" | awk '{print $1}')"
echo "  sha256  : $(awk '{print $1}' "${OUT_DIR}/MacTahoe-kde-bundle-${VERSION}.sha256")"
echo
echo "Envíalo con:"
echo "  scp ${OUT_FILE} usuario@IP:~/"
echo "  # o: rsync -av ${OUT_FILE} usuario@IP:~/"
