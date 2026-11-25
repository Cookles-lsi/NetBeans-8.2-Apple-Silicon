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
#    --solo-icono   Solo instala/actualiza el icono que cambia con el aspecto de macOS
#    --sin-icono    Instala sin el icono adaptable (deja el icono original)
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

# Azul Zulu JDK 8 con JavaFX incluido, compilado para ARM64 (macOS aarch64).
# Versión fija y verificada.
ZULU_URL="https://cdn.azul.com/zulu/bin/zulu8.96.0.205-ca-fx-jdk8.0.504-macosx_aarch64.tar.gz"
ZULU_SHA256="300feca3a32385d5181021c30ffd88aeaa392c83e21565ca72759f73f26d8770"

# --- Dónde se instala (todo dentro de tu usuario, no pide contraseña) --------

NB_DIR="$HOME/Applications/netbeans-8.2"
APP_DIR="$HOME/Applications/NetBeans 8.2.app"
JVM_DIR="$HOME/Library/Java/JavaVirtualMachines"
ZULU_DIR="$JVM_DIR/zulu-8-fx.jdk"
MARCA=".instalado-por-netbeans-8.2-apple-silicon"
ZULU_MARK="$ZULU_DIR/$MARCA"
# Carpeta que usaba la primera versión del script (JDK sin JavaFX).
ZULU_DIR_VIEJO="$JVM_DIR/zulu-8.jdk"
ZSHRC="$HOME/.zshrc"
ALIAS_START="# >>> NetBeans 8.2 Apple Silicon >>>"
ALIAS_END="# <<< NetBeans 8.2 Apple Silicon <<<"
# Icono adaptable (Liquid Glass): se regenera al cambiar el aspecto de macOS.
ICONO_DIR="$NB_DIR/icono"
AGENTE="io.github.cookles-lsi.netbeans82.icono"
AGENTE_PLIST="$HOME/Library/LaunchAgents/$AGENTE.plist"

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

es_jdk8_fx_arm64() {
  # Devuelve 0 si la carpeta Home dada es un JDK 8 (no JRE) nativo ARM64 con JavaFX.
  local home="$1"
  [ -x "$home/bin/java" ] && [ -x "$home/bin/javac" ] || return 1
  grep -q '^JAVA_VERSION="1\.8' "$home/release" 2>/dev/null || return 1
  file "$home/bin/java" 2>/dev/null | grep -q 'arm64' || return 1
  [ -f "$home/jre/lib/ext/jfxrt.jar" ] || return 1
}

buscar_jdk8() {
  local home
  for home in "$ZULU_DIR/Contents/Home" \
              "$JVM_DIR"/*/Contents/Home \
              /Library/Java/JavaVirtualMachines/*/Contents/Home; do
    if [ -d "$home" ] && es_jdk8_fx_arm64 "$home"; then
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

# --- Icono adaptable ----------------------------------------------------------
# Dibuja el cubo de NetBeans al estilo de macOS Tahoe (por omisión, transparente
# o tintado; claro u oscuro) y lo cambia solo cuando cambias el aspecto del Mac.
# Usa solo herramientas que trae macOS (JavaScript for Automation, sips,
# iconutil y launchd): no hace falta Xcode.

quitar_icono() {
  launchctl bootout "gui/$(id -u)/$AGENTE" 2>/dev/null || true
  rm -f "$AGENTE_PLIST"
  if [ -f "$ICONO_DIR/actualizar.sh" ]; then
    bash "$ICONO_DIR/actualizar.sh" --quitar || true
  fi
  rm -rf "$ICONO_DIR"
}

instalar_icono() {
  mkdir -p "$ICONO_DIR" "$(dirname "$AGENTE_PLIST")"
  cat > "$ICONO_DIR/icono.js" <<'ICONO_JS'
// Dibuja el icono de NetBeans al estilo Liquid Glass de macOS.
// Uso: osascript -l JavaScript icono.js SALIDA.png ESTILO MODO [R G B]
//   ESTILO: normal | transparente | tintado     MODO: claro | oscuro
//   R G B (0-1): color del tintado
ObjC.import('AppKit');

function run(argv) {
  const [salida, estilo, modo] = argv;
  const tinte = argv.length >= 6 ? argv.slice(3, 6).map(Number) : [0.0, 0.48, 1.0];
  const oscuro = modo === 'oscuro';
  const S = 1024;

  const rep = $.NSBitmapImageRep.alloc.initWithBitmapDataPlanesPixelsWidePixelsHighBitsPerSampleSamplesPerPixelHasAlphaIsPlanarColorSpaceNameBytesPerRowBitsPerPixel(
    null, S, S, 8, 4, true, false, $.NSCalibratedRGBColorSpace, 0, 0);
  const ctx = $.NSGraphicsContext.graphicsContextWithBitmapImageRep(rep);
  $.NSGraphicsContext.saveGraphicsState;
  $.NSGraphicsContext.setCurrentContext(ctx);
  ctx.setImageInterpolation($.NSImageInterpolationHigh);

  const col = (c, a = 1) => $.NSColor.colorWithSRGBRedGreenBlueAlpha(c[0], c[1], c[2], a);
  const mezcla = (a, b, t) => [0, 1, 2].map(i => a[i] + (b[i] - a[i]) * t);
  const luz = c => 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
  const P = (x, y) => $.NSMakePoint(x, S - y); // coordenadas con el origen arriba
  const poligono = pts => {
    const p = $.NSBezierPath.bezierPath;
    p.moveToPoint(P(...pts[0]));
    pts.slice(1).forEach(q => p.lineToPoint(P(...q)));
    p.closePath;
    return p;
  };
  const sombra = (dy, blur, a) => {
    const s = $.NSShadow.alloc.init;
    s.shadowOffset = $.NSMakeSize(0, -dy);
    s.shadowBlurRadius = blur;
    s.shadowColor = $.NSColor.colorWithSRGBRedGreenBlueAlpha(0, 0, 0, a);
    s.set;
  };
  const degradado = (path, arriba, abajo) => {
    const g = $.NSGradient.alloc.initWithStartingColorEndingColor(arriba, abajo);
    g.drawInBezierPathAngle(path, -90);
  };

  // --- Fondo de cristal (rejilla de iconos de macOS: 824 px centrado) ---
  const marco = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(100, 100, 824, 824), 185, 185);
  let fondo;
  if (estilo === 'transparente') {
    fondo = oscuro ? [[0.10, 0.10, 0.12, 0.62], [0.02, 0.02, 0.03, 0.78]]
                   : [[1, 1, 1, 0.62], [0.90, 0.91, 0.94, 0.45]];
  } else if (estilo === 'tintado') {
    fondo = oscuro ? [[...mezcla(tinte, [0, 0, 0], 0.72), 0.85], [...mezcla(tinte, [0, 0, 0], 0.88), 0.92]]
                   : [[...mezcla(tinte, [1, 1, 1], 0.25), 1], [...mezcla(tinte, [0, 0, 0], 0.10), 1]];
  } else {
    fondo = oscuro ? [[0.25, 0.26, 0.30, 1], [0.09, 0.09, 0.11, 1]]
                   : [[0.99, 0.99, 1.00, 1], [0.84, 0.86, 0.90, 1]];
  }
  $.NSGraphicsContext.saveGraphicsState;
  sombra(10, 28, estilo === 'transparente' ? 0.18 : 0.30);
  col(fondo[0].slice(0, 3), Math.max(fondo[0][3], 0.05)).setFill;
  marco.fill;
  $.NSGraphicsContext.restoreGraphicsState;
  $.NSGraphicsContext.saveGraphicsState;
  $.NSGraphicsContext.currentContext.setCompositingOperation($.NSCompositingOperationCopy);
  degradado(marco, col(fondo[0].slice(0, 3), fondo[0][3]), col(fondo[1].slice(0, 3), fondo[1][3]));
  $.NSGraphicsContext.restoreGraphicsState;
  // brillo superior
  const brillo = estilo === 'normal' && !oscuro ? 0.55 : 0.12;
  $.NSGraphicsContext.saveGraphicsState;
  marco.addClip;
  const brilloRect = $.NSBezierPath.bezierPathWithRect($.NSMakeRect(100, S - 470, 824, 370));
  degradado(brilloRect, col([1, 1, 1], brillo), col([1, 1, 1], 0));
  $.NSGraphicsContext.restoreGraphicsState;

  // --- Cubo de NetBeans (vectorial) ---
  const k = 0.86, c0 = 512;
  const t = ([x, y]) => [c0 + (x - c0) * k, c0 + (y - c0) * k];
  const T = [512, 156], UR = [821, 334], LR = [821, 689], B = [512, 867], LL = [203, 689], UL = [203, 334];
  const it = [512, 293], iur = [700, 403], ilr = [700, 620], ib = [512, 730], ill = [323, 620], iul = [323, 403], ic = [512, 512];
  const caras = [
    [[UL, T, it, iul],   [0.713, 0.800, 0.381]],
    [[T, UR, iur, it],   [0.758, 0.848, 0.410]],
    [[UR, LR, ilr, iur], [0.258, 0.495, 0.799]],
    [[LR, B, ib, ilr],   [0.362, 0.633, 0.906]],
    [[B, LL, ill, ib],   [0.882, 0.321, 0.451]],
    [[LL, UL, iul, ill], [0.664, 0.199, 0.318]],
    [[iul, it, iur, ic], [0.959, 0.970, 0.915]],
    [[iul, ic, ib, ill], [1.000, 1.000, 1.000]],
    [[ic, iur, ilr, ib], [0.850, 0.887, 0.918]],
  ];
  const colorCara = c => {
    if (estilo === 'normal') return c;
    const L = luz(c);
    if (estilo === 'transparente') {
      const g = oscuro ? 0.30 + 0.62 * L : 0.28 + 0.60 * L;
      return [g, g, g];
    }
    return oscuro ? mezcla(tinte, [1, 1, 1], 0.15 + 0.80 * L) : mezcla([1, 1, 1], tinte, 0.55 * (1 - L));
  };
  const hex = poligono([T, UR, LR, B, LL, UL].map(t));
  $.NSGraphicsContext.saveGraphicsState;
  sombra(18, 36, oscuro ? 0.45 : 0.25);
  col([0.5, 0.5, 0.5]).setFill;
  hex.fill;
  $.NSGraphicsContext.restoreGraphicsState;
  for (const [pts, c] of caras) {
    const p = poligono(pts.map(t));
    col(colorCara(c)).setFill;
    p.fill;
    col(colorCara(c)).setStroke; // tapa las juntas del antialiasing
    p.lineWidth = 1.2;
    p.stroke;
  }
  // reflejo de cristal sobre el cubo
  $.NSGraphicsContext.saveGraphicsState;
  hex.addClip;
  degradado($.NSBezierPath.bezierPathWithRect($.NSMakeRect(0, S - 560, S, 400)), col([1, 1, 1], 0.25), col([1, 1, 1], 0));
  $.NSGraphicsContext.restoreGraphicsState;

  // --- Borde de cristal ---
  $.NSGraphicsContext.saveGraphicsState;
  marco.addClip;
  marco.lineWidth = 10;
  const borde = $.NSGradient.alloc.initWithColors(
    $([col([1, 1, 1], 0.95), col([1, 1, 1], 0.08), col([1, 1, 1], 0.45)]));
  // pinta el gradiente solo dentro del trazo del borde
  const trazo = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(100, 100, 824, 824), 185, 185);
  trazo.appendBezierPath($.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(105, 105, 814, 814), 180, 180).bezierPathByReversingPath);
  borde.drawInBezierPathAngle(trazo, -90);
  $.NSGraphicsContext.restoreGraphicsState;

  $.NSGraphicsContext.restoreGraphicsState;
  const png = rep.representationUsingTypeProperties($.NSBitmapImageFileTypePNG, $());
  if (!png.writeToFileAtomically(salida, true)) throw new Error('No se pudo escribir ' + salida);
}
ICONO_JS
  cat > "$ICONO_DIR/actualizar.sh" <<'ACTUALIZAR_SH'
#!/bin/bash
# Cambia el icono de NetBeans según el aspecto de macOS (claro/oscuro y estilo
# de iconos: por omisión, transparente o tintado). Lo ejecuta solo un agente de
# launchd cada vez que cambian las preferencias globales.
#   --forzar   regenera y aplica aunque el aspecto no haya cambiado
#   --quitar   deja los iconos como estaban y quita la configuración del Dock
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/NetBeans 8.2.app"
APACHE="/Applications/Apache NetBeans.app"
SOPORTE="$HOME/Library/Application Support/NetBeans"
INICIO="# >>> icono NetBeans 8.2 Apple Silicon >>>"
FIN="# <<< icono NetBeans 8.2 Apple Silicon <<<"
FORZAR=0; QUITAR=0
for a in "$@"; do
  case "$a" in --forzar) FORZAR=1 ;; --quitar) QUITAR=1 ;; esac
done

# Carpetas de configuración de usuario de cada NetBeans instalado.
carpetas_usuario() {
  printf '%s\n' "$SOPORTE/8.2"
  local conf="$APACHE/Contents/Resources/netbeans/etc/netbeans.conf" v
  if [ -f "$conf" ]; then
    v="$(sed -n 's|^netbeans_default_userdir=".*/\([^/"]*\)"|\1|p' "$conf" | head -n 1)"
    [ -n "$v" ] && printf '%s\n' "$SOPORTE/$v"
  fi
}

quitar_bloque() {
  local conf="$1/etc/netbeans.conf" tmp
  [ -f "$conf" ] && grep -qF "$INICIO" "$conf" || return 0
  tmp="$(mktemp)"
  sed "/^$INICIO\$/,/^$FIN\$/d" "$conf" > "$tmp" && cat "$tmp" > "$conf"
  rm -f "$tmp"
  [ -s "$conf" ] || rm -f "$conf"
}

# NetBeans lee <userdir>/etc/netbeans.conf después del suyo, y en Java gana el
# último -Xdock:icon: así el icono del Dock cambia sin tocar la app.
poner_bloque() {
  quitar_bloque "$1"
  mkdir -p "$1/etc"
  {
    printf '%s\n' "$INICIO"
    printf 'netbeans_default_options="${netbeans_default_options} \\"-J-Xdock:icon=%s/netbeans.icns\\""\n' "$DIR"
    printf '%s\n' "$FIN"
  } >> "$1/etc/netbeans.conf"
}

poner_icono_finder() { # PNG (vacío = quitar) APP
  [ -d "$2" ] || return 0
  osascript -l JavaScript -e 'ObjC.import("AppKit");
    function run(a) {
      const img = a[0] ? $.NSImage.alloc.initWithContentsOfFile(a[0]) : null;
      return $.NSWorkspace.sharedWorkspace.setIconForFileOptions(img, a[1], 0) ? "ok" : "no";
    }' "$1" "$2" 2>/dev/null | grep -q ok
}

if [ "$QUITAR" = "1" ]; then
  while IFS= read -r d; do quitar_bloque "$d"; done < <(carpetas_usuario)
  poner_icono_finder "" "$APACHE" || true
  poner_icono_finder "" "$APP" || true
  rm -f "$DIR/actual.txt"
  exit 0
fi

# --- Qué aspecto tiene el Mac ahora ---
tema="$(defaults read -g AppleIconAppearanceTheme 2>/dev/null || true)"
interfaz="$(defaults read -g AppleInterfaceStyle 2>/dev/null || true)"
case "$tema" in
  *Clear*)  estilo=transparente ;;
  *Tinted*) estilo=tintado ;;
  *)        estilo=normal ;;
esac
case "$tema" in
  *Dark*)  modo=oscuro ;;
  *Light*) modo=claro ;;
  *) if [ "$interfaz" = "Dark" ]; then modo=oscuro; else modo=claro; fi ;;
esac
# Color del tintado: el color de acento del sistema.
case "$(defaults read -g AppleAccentColor 2>/dev/null || echo 4)" in
  -1) tinte="0.56 0.56 0.58" ;;  # grafito
  0)  tinte="1.00 0.23 0.19" ;;  # rojo
  1)  tinte="1.00 0.58 0.00" ;;  # naranja
  2)  tinte="1.00 0.78 0.00" ;;  # amarillo
  3)  tinte="0.16 0.76 0.33" ;;  # verde
  5)  tinte="0.69 0.32 0.87" ;;  # morado
  6)  tinte="1.00 0.18 0.40" ;;  # rosa
  *)  tinte="0.00 0.48 1.00" ;;  # azul
esac
clave="$estilo-$modo"
[ "$estilo" = "tintado" ] && clave="$clave-$(printf '%s' "$tinte" | tr ' .' '-_')"

if [ "$FORZAR" = "0" ] && [ "$(cat "$DIR/actual.txt" 2>/dev/null)" = "$clave" ]; then
  exit 0
fi

# --- Generar el icono (se guarda para no repetirlo) ---
mkdir -p "$DIR/variantes"
png="$DIR/variantes/$clave.png"
icns="$DIR/variantes/$clave.icns"
if [ "$FORZAR" = "1" ] || [ ! -f "$icns" ]; then
  # shellcheck disable=SC2086
  osascript -l JavaScript "$DIR/icono.js" "$png" "$estilo" "$modo" $tinte || exit 1
  set_dir="$(mktemp -d)/netbeans.iconset"
  mkdir -p "$set_dir"
  for s in 16 32 128 256 512; do
    sips -z "$s" "$s" "$png" --out "$set_dir/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$png" --out "$set_dir/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$set_dir" -o "$icns" || exit 1
  rm -rf "$(dirname "$set_dir")"
fi

# --- Aplicar ---
cp "$icns" "$DIR/netbeans.icns"                       # el que usa el Dock al abrir NetBeans
[ -d "$APP" ] && cp "$icns" "$APP/Contents/Resources/netbeans.icns"
poner_icono_finder "$png" "$APP" || true
poner_icono_finder "$png" "$APACHE" || true          # macOS puede no permitirlo en /Applications
while IFS= read -r d; do poner_bloque "$d"; done < <(carpetas_usuario)
printf '%s\n' "$clave" > "$DIR/actual.txt"
killall Dock 2>/dev/null || true
echo "Icono de NetBeans: $clave"
ACTUALIZAR_SH
  chmod +x "$ICONO_DIR/actualizar.sh"
  cat > "$AGENTE_PLIST" <<AGENTE_XML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>             <string>$AGENTE</string>
  <key>ProgramArguments</key>  <array><string>/bin/bash</string><string>$ICONO_DIR/actualizar.sh</string></array>
  <key>WatchPaths</key>        <array><string>$HOME/Library/Preferences/.GlobalPreferences.plist</string></array>
  <key>RunAtLoad</key>         <true/>
  <key>StandardOutPath</key>   <string>$ICONO_DIR/registro.txt</string>
  <key>StandardErrorPath</key> <string>$ICONO_DIR/registro.txt</string>
</dict>
</plist>
AGENTE_XML
  bash "$ICONO_DIR/actualizar.sh" --forzar >/dev/null || return 1
  launchctl bootout "gui/$(id -u)/$AGENTE" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$AGENTE_PLIST" 2>/dev/null || return 1
  info "Icono actual: $(cat "$ICONO_DIR/actual.txt" 2>/dev/null)"
  info "Cambia solo al cambiar el aspecto (Ajustes del Sistema → Apariencia)."
  if [ -d "/Applications/Apache NetBeans.app" ]; then
    info "Apache NetBeans también usará este icono en el Dock."
  fi
}

# --- Opciones -----------------------------------------------------------------

REINSTALAR=0
DESINSTALAR=0
SOLO_ICONO=0
SIN_ICONO=0
for arg in "$@"; do
  case "$arg" in
    --reinstalar)  REINSTALAR=1 ;;
    --desinstalar) DESINSTALAR=1 ;;
    --solo-icono)  SOLO_ICONO=1 ;;
    --sin-icono)   SIN_ICONO=1 ;;
    -h|--ayuda|--help)
      sed -n '2,18p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//' \
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
for cmd in curl shasum unzip tar file xattr osascript sips iconutil launchctl; do
  command -v "$cmd" >/dev/null 2>&1 || error "Falta el comando '$cmd' en tu sistema."
done

# --- Desinstalar --------------------------------------------------------------

if [ "$DESINSTALAR" = "1" ]; then
  paso "Desinstalando NetBeans 8.2"
  quitar_icono
  if [ -d "$NB_DIR" ]; then rm -rf "$NB_DIR"; info "Quitado: $NB_DIR"; fi
  if [ -d "$APP_DIR" ]; then rm -rf "$APP_DIR"; info "Quitado: $APP_DIR"; fi
  quitar_alias && info "Quitado el alias nb82 de ~/.zshrc (si existía)."
  JDK_QUITADO=0
  for dir in "$ZULU_DIR" "$ZULU_DIR_VIEJO"; do
    if [ -f "$dir/$MARCA" ]; then
      rm -rf "$dir"; info "Quitado el JDK 8 que instaló este script: $dir"; JDK_QUITADO=1
    fi
  done
  [ "$JDK_QUITADO" = "1" ] || info "El JDK 8 no se tocó (no lo instaló este script)."
  info "Tus proyectos (~/NetBeansProjects) y tu configuración no se borraron."
  printf '\n%sListo.%s\n' "$VERDE" "$NORMAL"
  exit 0
fi

if [ "$SOLO_ICONO" = "1" ]; then
  [ -x "$NB_DIR/bin/netbeans" ] || error "NetBeans 8.2 no está instalado; corre el instalador sin --solo-icono."
  paso "Instalando el icono adaptable"
  instalar_icono || error "No se pudo instalar el icono adaptable."
  info "Cierra y vuelve a abrir NetBeans para ver el icono nuevo en el Dock."
  printf '\n%sListo.%s\n' "$VERDE" "$NORMAL"
  exit 0
fi

TMP_DIR="$(mktemp -d)"

# --- 1. JDK 8 nativo ARM64 ----------------------------------------------------

paso "1/5  Buscando un JDK 8 nativo para Apple Silicon con JavaFX"
if JDK_HOME="$(buscar_jdk8)"; then
  info "Encontrado: $JDK_HOME"
else
  info "No hay ninguno con JavaFX. Descargando Azul Zulu JDK 8 + JavaFX (ARM64, ~160 MB)..."
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
  es_jdk8_fx_arm64 "$JDK_HOME" || error "El JDK instalado no pasó la verificación (ARM64 + JavaFX)."
  info "Instalado en: $ZULU_DIR"
  if [ -f "$ZULU_DIR_VIEJO/$MARCA" ]; then
    rm -rf "$ZULU_DIR_VIEJO"
    info "Quitado el JDK 8 sin JavaFX que instaló una versión anterior de este script."
  fi
fi

# --- 2. NetBeans 8.2 ----------------------------------------------------------

paso "2/5  Instalando NetBeans 8.2"
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

paso "3/5  Configurando NetBeans para usar el JDK 8 ARM64"
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

paso "4/5  Creando el acceso directo y el comando nb82"
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
  if grep -E "^[[:space:]]*alias nb82=" "$ZSHRC" | grep -q -- "--jdkhome"; then
    aviso "Tu alias nb82 trae --jdkhome, y eso ignora la configuración de este script."
    info "Para que use el JDK con JavaFX, cambia la línea del alias en ~/.zshrc por:"
    info "alias nb82='\"$NB_DIR/bin/netbeans\"'"
  fi
else
  {
    printf '%s\n' "$ALIAS_START"
    printf "alias nb82='\"%s/bin/netbeans\"'\n" "$NB_DIR"
    printf '%s\n' "$ALIAS_END"
  } >> "$ZSHRC"
  info "Comando nb82 agregado a ~/.zshrc (abre una Terminal nueva para usarlo)."
fi

# --- 5. Icono adaptable ------------------------------------------------------

paso "5/5  Icono que cambia con el aspecto de macOS"
if [ "$SIN_ICONO" = "1" ]; then
  quitar_icono
  info "Omitido (--sin-icono): se queda el icono original de NetBeans."
elif ! instalar_icono; then
  aviso "No se pudo instalar el icono adaptable; NetBeans funciona igual con su icono original."
fi

# --- Listo --------------------------------------------------------------------

printf '\n%s✔ NetBeans 8.2 quedó instalado, con JavaFX y corriendo nativo en ARM64.%s\n\n' "$VERDE" "$NORMAL"
info "Ábrelo con Spotlight (Cmd+Espacio → \"NetBeans 8.2\") o escribiendo nb82 en la Terminal."
info "La primera vez tarda un poco en abrir mientras crea su configuración."
info "Comprueba que es nativo con:  file \"$JDK_HOME/bin/java\"   (debe decir arm64)"
echo
