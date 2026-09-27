#!/bin/bash
# =============================================================================
#  NetBeans IDE 8.2 para Mac con Apple Silicon (M1, M2, M3, M4...)
#  Instalador automático — corre 100% nativo en ARM64, sin Rosetta.
#
#  Uso:
#    curl -fsSL https://raw.githubusercontent.com/Cookles-lsi/NetBeans-8.2-Apple-Silicon/main/instalar.sh | bash
#
#  Opciones (con curl se pasan así: ... | bash -s -- --opcion):
#    --reinstalar   Vuelve a descargar NetBeans aunque ya esté instalado
#    --desinstalar  Quita NetBeans 8.2, su acceso directo y el alias nb82
#    --ayuda        Muestra esta ayuda
#
#  Proyecto independiente, no afiliado a Apache, Oracle, Azul ni Apple.
#  Licencia MIT — https://github.com/Cookles-lsi/NetBeans-8.2-Apple-Silicon
# =============================================================================

set -euo pipefail

# --- Qué se descarga y de dónde ----------------------------------------------

# NetBeans 8.2 Java SE, ZIP "platform independent" original de Oracle (2016).
NB_URL="https://dlc-cdn.sun.com/netbeans/8.2/final/zip/netbeans-8.2-201609300101-javase.zip"
NB_SHA256="cf6f94517faa5dbedede4b8a7a6e6d5a65ca931eeae3809245ba7321bf539aea"

# Azul Zulu JDK 8 compilado para ARM64 (macOS aarch64). Versión fija y verificada.
ZULU_URL="https://cdn.azul.com/zulu/bin/zulu8.96.0.205-ca-jdk8.0.504-macosx_aarch64.tar.gz"
ZULU_SHA256="58bb3c08f2aa63d9743cf31899fa4b8c6c9effefce9479e7288c26621c3bb21b"

# --- Dónde se instala (todo dentro de tu usuario, no pide contraseña) --------

NB_DIR="$HOME/Applications/netbeans-8.2"
APP_DIR="$HOME/Applications/NetBeans 8.2.app"
JVM_DIR="$HOME/Library/Java/JavaVirtualMachines"
ZULU_DIR="$JVM_DIR/zulu-8.jdk"
ZULU_MARK="$ZULU_DIR/.instalado-por-netbeans-8.2-apple-silicon"
ZSHRC="$HOME/.zshrc"
ALIAS_START="# >>> NetBeans 8.2 Apple Silicon >>>"
ALIAS_END="# <<< NetBeans 8.2 Apple Silicon <<<"

# --- Utilidades ---------------------------------------------------------------

if [ -t 1 ]; then
  VERDE=$'\033[32m'; AMARILLO=$'\033[33m'; ROJO=$'\033[31m'; NEGRITA=$'\033[1m'; NORMAL=$'\033[0m'
else
  VERDE=""; AMARILLO=""; ROJO=""; NEGRITA=""; NORMAL=""
fi

paso()  { printf '\n%s==>%s %s%s%s\n' "$VERDE" "$NORMAL" "$NEGRITA" "$*" "$NORMAL"; }
info()  { printf '    %s\n' "$*"; }
aviso() { printf '    %s¡Ojo!%s %s\n' "$AMARILLO" "$NORMAL" "$*"; }
error() { printf '\n%sError:%s %s\n' "$ROJO" "$NORMAL" "$*" >&2; exit 1; }

TMP_DIR=""
limpiar() { if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then rm -rf "$TMP_DIR"; fi; }
trap limpiar EXIT

descargar() {
  # descargar URL ARCHIVO SHA256
  local url="$1" destino="$2" sha_esperado="$3" sha_real
  curl -fL --retry 3 --retry-delay 2 --progress-bar -o "$destino" "$url" \
    || error "No se pudo descargar $url — revisa tu conexión a internet."
  sha_real="$(shasum -a 256 "$destino" | awk '{print $1}')"
  if [ "$sha_real" != "$sha_esperado" ]; then
    error "El archivo descargado no coincide con el original (SHA-256 distinto). No se instaló nada."
  fi
  info "Descarga verificada (SHA-256 correcto)."
}

es_jdk8_arm64() {
  # Devuelve 0 si la carpeta Home dada es un JDK 8 (no JRE) nativo ARM64.
  local home="$1"
  [ -x "$home/bin/java" ] && [ -x "$home/bin/javac" ] || return 1
  grep -q '^JAVA_VERSION="1\.8' "$home/release" 2>/dev/null || return 1
  file "$home/bin/java" 2>/dev/null | grep -q 'arm64' || return 1
}

buscar_jdk8() {
  local home
  for home in "$ZULU_DIR/Contents/Home" \
              "$JVM_DIR"/*/Contents/Home \
              /Library/Java/JavaVirtualMachines/*/Contents/Home; do
    if [ -d "$home" ] && es_jdk8_arm64 "$home"; then
      printf '%s\n' "$home"
      return 0
    fi
  done
  return 1
}

quitar_alias() {
  [ -f "$ZSHRC" ] || return 0
  grep -qF "$ALIAS_START" "$ZSHRC" || return 0
  local tmp
  tmp="$(mktemp)"
  sed "/^$ALIAS_START\$/,/^$ALIAS_END\$/d" "$ZSHRC" > "$tmp" && cat "$tmp" > "$ZSHRC"
  rm -f "$tmp"
}

# --- Opciones -----------------------------------------------------------------

REINSTALAR=0
DESINSTALAR=0
for arg in "$@"; do
  case "$arg" in
    --reinstalar)  REINSTALAR=1 ;;
    --desinstalar) DESINSTALAR=1 ;;
    -h|--ayuda|--help)
      sed -n '2,16p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//' \
        || echo "Uso: bash instalar.sh [--reinstalar | --desinstalar]"
      exit 0 ;;
    *) error "Opción desconocida: $arg (usa --ayuda)" ;;
  esac
done

printf '%sNetBeans IDE 8.2 para Apple Silicon%s\n' "$NEGRITA" "$NORMAL"

# --- Revisiones previas -------------------------------------------------------

[ "$(uname -s)" = "Darwin" ] || error "Este script es solo para macOS."
if [ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" != "1" ]; then
  error "Esta Mac no tiene chip Apple Silicon. Para Mac con Intel usa el instalador oficial de NetBeans 8.2."
fi
if [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" = "1" ]; then
  aviso "Tu Terminal está corriendo con Rosetta. No pasa nada: todo lo que se instala es ARM64 nativo."
fi
for cmd in curl shasum unzip tar file xattr; do
  command -v "$cmd" >/dev/null 2>&1 || error "Falta el comando '$cmd' en tu sistema."
done

# --- Desinstalar --------------------------------------------------------------

if [ "$DESINSTALAR" = "1" ]; then
  paso "Desinstalando NetBeans 8.2"
  if [ -d "$NB_DIR" ]; then rm -rf "$NB_DIR"; info "Quitado: $NB_DIR"; fi
  if [ -d "$APP_DIR" ]; then rm -rf "$APP_DIR"; info "Quitado: $APP_DIR"; fi
  quitar_alias && info "Quitado el alias nb82 de ~/.zshrc (si existía)."
  if [ -f "$ZULU_MARK" ]; then
    rm -rf "$ZULU_DIR"; info "Quitado el JDK 8 que instaló este script."
  else
    info "El JDK 8 no se tocó (no lo instaló este script)."
  fi
  info "Tus proyectos (~/NetBeansProjects) y tu configuración no se borraron."
  printf '\n%sListo.%s\n' "$VERDE" "$NORMAL"
  exit 0
fi

TMP_DIR="$(mktemp -d)"

# --- 1. JDK 8 nativo ARM64 ----------------------------------------------------

paso "1/4  Buscando un JDK 8 nativo para Apple Silicon"
if JDK_HOME="$(buscar_jdk8)"; then
  info "Encontrado: $JDK_HOME"
else
  info "No hay ninguno. Descargando Azul Zulu JDK 8 (ARM64, ~100 MB)..."
  descargar "$ZULU_URL" "$TMP_DIR/zulu.tar.gz" "$ZULU_SHA256"
  tar -xzf "$TMP_DIR/zulu.tar.gz" -C "$TMP_DIR"
  EXTRAIDO="$(find "$TMP_DIR" -maxdepth 1 -type d -name 'zulu8*macosx_aarch64' | head -n 1)"
  [ -n "$EXTRAIDO" ] && [ -x "$EXTRAIDO/Contents/Home/bin/java" ] \
    || error "El JDK descargado no tiene la estructura esperada."
  mkdir -p "$JVM_DIR"
  rm -rf "$ZULU_DIR"
  mv "$EXTRAIDO" "$ZULU_DIR"
  touch "$ZULU_MARK"
  xattr -dr com.apple.quarantine "$ZULU_DIR" 2>/dev/null || true
  JDK_HOME="$ZULU_DIR/Contents/Home"
  es_jdk8_arm64 "$JDK_HOME" || error "El JDK instalado no pasó la verificación ARM64."
  info "Instalado en: $ZULU_DIR"
fi

# --- 2. NetBeans 8.2 ----------------------------------------------------------

paso "2/4  Instalando NetBeans 8.2"
if [ -x "$NB_DIR/bin/netbeans" ] && [ "$REINSTALAR" = "0" ]; then
  info "Ya estaba instalado en $NB_DIR — solo se revisa la configuración."
  info "(Para bajarlo de nuevo desde cero usa --reinstalar)"
else
  LIBRE_KB="$(df -k "$HOME" | awk 'NR==2 {print $4}')"
  if [ -n "$LIBRE_KB" ] && [ "$LIBRE_KB" -lt 1048576 ]; then
    error "Necesitas al menos 1 GB libre en disco."
  fi
  info "Descargando el ZIP original de NetBeans 8.2 (~190 MB)..."
  descargar "$NB_URL" "$TMP_DIR/netbeans.zip" "$NB_SHA256"
  info "Descomprimiendo..."
  unzip -q "$TMP_DIR/netbeans.zip" -d "$TMP_DIR"
  [ -x "$TMP_DIR/netbeans/bin/netbeans" ] || error "El ZIP no tiene la estructura esperada."
  mkdir -p "$HOME/Applications"
  if [ -e "$NB_DIR" ]; then
    RESPALDO="$NB_DIR.respaldo-$(date +%Y%m%d-%H%M%S)"
    mv "$NB_DIR" "$RESPALDO"
    aviso "Ya había una carpeta netbeans-8.2; se guardó como respaldo en $RESPALDO"
  fi
  mv "$TMP_DIR/netbeans" "$NB_DIR"
  info "Instalado en: $NB_DIR"
fi
xattr -dr com.apple.quarantine "$NB_DIR" 2>/dev/null || true
chmod +x "$NB_DIR/bin/netbeans"

# --- 3. Apuntar NetBeans al JDK 8 ---------------------------------------------

paso "3/4  Configurando NetBeans para usar el JDK 8 ARM64"
CONF="$NB_DIR/etc/netbeans.conf"
[ -f "$CONF" ] || error "No se encontró $CONF"
CONF_TMP="$TMP_DIR/netbeans.conf"
sed "s|^#*netbeans_jdkhome=.*|netbeans_jdkhome=\"$JDK_HOME\"|" "$CONF" > "$CONF_TMP"
if ! grep -q '^netbeans_jdkhome=' "$CONF_TMP"; then
  printf 'netbeans_jdkhome="%s"\n' "$JDK_HOME" >> "$CONF_TMP"
fi
cat "$CONF_TMP" > "$CONF"
info "netbeans_jdkhome=\"$JDK_HOME\""

# --- 4. Acceso directo y alias ------------------------------------------------

paso "4/4  Creando el acceso directo y el comando nb82"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$NB_DIR/nb/netbeans.icns" "$APP_DIR/Contents/Resources/netbeans.icns" 2>/dev/null || true
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>                <string>NetBeans 8.2</string>
  <key>CFBundleDisplayName</key>         <string>NetBeans 8.2</string>
  <key>CFBundleIdentifier</key>          <string>io.github.cookles-lsi.netbeans82</string>
  <key>CFBundleVersion</key>             <string>8.2</string>
  <key>CFBundleShortVersionString</key>  <string>8.2</string>
  <key>CFBundlePackageType</key>         <string>APPL</string>
  <key>CFBundleExecutable</key>          <string>netbeans82</string>
  <key>CFBundleIconFile</key>            <string>netbeans</string>
  <key>LSUIElement</key>                 <true/>
</dict>
</plist>
PLIST
cat > "$APP_DIR/Contents/MacOS/netbeans82" <<LAUNCHER
#!/bin/bash
# Abre NetBeans 8.2 y se cierra enseguida (NetBeans aparece con su propio icono en el Dock).
nohup "$NB_DIR/bin/netbeans" >/dev/null 2>&1 &
LAUNCHER
chmod +x "$APP_DIR/Contents/MacOS/netbeans82"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$APP_DIR" >/dev/null 2>&1 || true
info "Acceso directo: $APP_DIR (búscalo en Spotlight como \"NetBeans 8.2\")"

quitar_alias
if grep -qE "^[[:space:]]*alias nb82=" "$ZSHRC" 2>/dev/null; then
  info "Ya tenías un alias nb82 propio en ~/.zshrc; no se modificó."
else
  {
    printf '%s\n' "$ALIAS_START"
    printf "alias nb82='\"%s/bin/netbeans\"'\n" "$NB_DIR"
    printf '%s\n' "$ALIAS_END"
  } >> "$ZSHRC"
  info "Comando nb82 agregado a ~/.zshrc (abre una Terminal nueva para usarlo)."
fi

# --- Listo --------------------------------------------------------------------

printf '\n%s✔ NetBeans 8.2 quedó instalado y corriendo nativo en ARM64.%s\n\n' "$VERDE" "$NORMAL"
info "Ábrelo con Spotlight (Cmd+Espacio → \"NetBeans 8.2\") o escribiendo nb82 en la Terminal."
info "La primera vez tarda un poco en abrir mientras crea su configuración."
info "Comprueba que es nativo con:  file \"$JDK_HOME/bin/java\"   (debe decir arm64)"
echo
