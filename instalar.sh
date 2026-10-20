#!/bin/bash
# Videos con Claude — instalador para Mac.
#
# Una línea, desde la Terminal:
#   curl -fsSL https://raw.githubusercontent.com/prcontreras23/videos-para-claude/main/instalar.sh | bash
# O, con el repo ya bajado:
#   bash instalar.sh
#
# Instala, paso por paso, todo lo que hace falta para hacer videos
# con Claude Code: Homebrew, Node, Python, ffmpeg, whisper y su modelo, Claude Code,
# los plugins y skills de video, los MCP, y la carpeta del proyecto lista para trabajar.
# Lo que ya está instalado se respeta; se puede correr otra vez sin problema.

set -u
REPO="prcontreras23/videos-para-claude"
DESTINO="${VIDEOS_DIR:-$HOME/videos}"
TOTAL=9

# Ningún comando de `claude` debe heredar la terminal como entrada (Bun falla con
# EINVAL kqueue); las preguntas se leen de /dev/tty.
exec < /dev/null

verde() { printf "  \033[32m✓\033[0m %s\n" "$1"; }
rojo()  { printf "  \033[31m✗\033[0m %s\n" "$1"; }
gris()  { printf "  \033[2m%s\033[0m\n" "$1"; }
paso()  { printf "\n\033[1mPaso %s de %s — %s\033[0m\n" "$1" "$TOTAL" "$2"; }
tiene() { command -v "$1" >/dev/null 2>&1; }
pregunta() { # pregunta "texto" → respuesta en $R (Enter = vacío)
  printf "  %s " "$1"; R=""; read -r R < /dev/tty 2>/dev/null || R=""; }
si() { pregunta "$1 [Enter = sí, n = no]"; [ "$R" != "n" ] && [ "$R" != "N" ]; }
ruta() {
  for d in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin" "$HOME/.claude/local"; do
    case ":$PATH:" in *":$d:"*) ;; *) [ -d "$d" ] && PATH="$d:$PATH";; esac
  done
  export PATH
}
FALLAS=()
falla() { rojo "$1"; FALLAS+=("$1"); }

printf "\n\033[1mVideos con Claude\033[0m — instalador para Mac\n"
gris "Se instala en: $DESTINO"

# ─────────────────────────────────────────────── 1. La computadora y el paquete
paso 1 "Revisar la computadora"
[ "$(uname)" = "Darwin" ] || { rojo "Este instalador es para Mac. En Windows use instalar-windows.ps1."; exit 1; }
ARQ="$(uname -m)"
verde "macOS $(sw_vers -productVersion) ($ARQ)"
LIBRE_GB=$(df -g "$HOME" | awk 'NR==2{print $4}')
if [ "${LIBRE_GB:-0}" -lt 6 ]; then
  rojo "Quedan ${LIBRE_GB} GB libres; hacen falta unos 6 GB (modelo de voz, Chrome, dependencias)."
  si "¿Sigo de todos modos?" || exit 1
else
  verde "${LIBRE_GB} GB libres"
fi

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
if [ -n "$AQUI" ] && [ -d "$AQUI/plantilla" ]; then
  FUENTE="$AQUI"
else
  FUENTE="$HOME/.videos-claude-fuente"
  gris "Bajando el paquete de GitHub..."
  rm -rf "$FUENTE"; mkdir -p "$FUENTE"
  curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/main" | tar -xz -C "$FUENTE" --strip-components=1 \
    || { rojo "No se pudo bajar el paquete. Revise el internet e intente otra vez."; exit 1; }
fi
verde "Paquete listo"

# ─────────────────────────────────────────────── 2. Homebrew
paso 2 "Homebrew (instalador de programas)"
ruta
if tiene brew; then
  verde "Homebrew ya estaba"
else
  gris "Homebrew va a pedir la contraseña de la Mac (no se ve al escribirla)."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" < /dev/tty
  ruta
  if tiene brew; then verde "Homebrew instalado"
  else
    rojo "Homebrew no quedó instalado."
    [ "$ARQ" = "x86_64" ] && gris "En Mac Intel, Homebrew ya no siempre instala; instale Node, Python y ffmpeg a mano desde sus páginas y corra esto otra vez."
    exit 1
  fi
fi

# ─────────────────────────────────────────────── 3. Herramientas
paso 3 "Node, Python, ffmpeg, git y whisper"
FALTAN=()
tiene node        || FALTAN+=(node)
tiene git         || FALTAN+=(git)
tiene ffmpeg      || FALTAN+=(ffmpeg)
tiene whisper-cli || FALTAN+=(whisper-cpp)
PY_OK=0
if tiene python3 && python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)' 2>/dev/null; then PY_OK=1; fi
[ $PY_OK = 1 ] || FALTAN+=(python@3.12)
if [ ${#FALTAN[@]} -gt 0 ]; then
  gris "Instalando: ${FALTAN[*]} (puede tardar unos minutos)..."
  brew install "${FALTAN[@]}" >/dev/null 2>&1 || brew install "${FALTAN[@]}"
  ruta
fi
if tiene node && [ "$(node -p 'process.versions.node.split(".")[0]')" -lt 18 ]; then
  gris "Node es viejo; actualizando..."; brew upgrade node >/dev/null 2>&1 || brew install node >/dev/null 2>&1; ruta
fi
for h in node npm git ffmpeg whisper-cli python3; do
  if tiene "$h"; then verde "$h"; else falla "$h no quedó instalado"; fi
done
PY=python3
[ -x /opt/homebrew/bin/python3.12 ] && [ $PY_OK = 0 ] && PY=/opt/homebrew/bin/python3.12
[ -x /usr/local/bin/python3.12 ] && [ $PY_OK = 0 ] && PY=/usr/local/bin/python3.12

# ─────────────────────────────────────────────── 4. Claude Code
paso 4 "Claude Code"
if tiene claude; then
  verde "Claude Code ya estaba ($(claude --version 2>/dev/null | head -1))"
else
  gris "Instalando Claude Code (instalador oficial)..."
  curl -fsSL https://claude.ai/install.sh | bash >/dev/null 2>&1
  ruta
  if tiene claude; then verde "Claude Code instalado"
  else falla "Claude Code no quedó instalado: https://claude.com/claude-code"; fi
fi
# El PATH de las terminales nuevas
for rc in "$HOME/.zshrc" "$HOME/.bash_profile"; do
  [ -f "$rc" ] || [ "$rc" = "$HOME/.zshrc" ] || continue
  grep -q '.local/bin' "$rc" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
done

# ─────────────────────────────────────────────── 5. Plugins y skills
paso 5 "Plugins y skills de video para Claude"
if tiene claude; then
  for m in anthropics/claude-plugins-official remotion-dev/claude-code-plugin bradautomates/claude-video; do
    claude plugin marketplace add "$m" >/dev/null 2>&1
  done
  for p in remotion@remotion watch@claude-video frontend-design@claude-plugins-official; do
    if claude plugin install "$p" >/dev/null 2>&1 || claude plugin list 2>/dev/null | grep -q "${p%@*}"; then
      verde "plugin ${p%@*}"
    else falla "plugin ${p%@*}"; fi
  done
  gris "Skills de Remotion (remotion-dev/skills)..."
  if npx -y skills add remotion-dev/skills -g -a claude-code -s '*' -y --copy >/dev/null 2>&1; then verde "skills remotion-*"
  else falla "skills de Remotion"; fi
else
  falla "Sin Claude Code no se pueden poner los plugins; corra el instalador otra vez cuando esté."
fi

# ─────────────────────────────────────────────── 6. MCP y servicios opcionales
paso 6 "MCP y servicios (voz, transcripción, clips)"
if tiene claude; then
  claude mcp remove whisper -s user >/dev/null 2>&1
  if claude mcp add --scope user whisper -- npx -y whisper-mcp >/dev/null 2>&1; then verde "MCP whisper (transcribir audios desde Claude)"
  else falla "MCP whisper"; fi

  echo
  gris "La voz se hace en ElevenLabs. Hay dos formas:"
  gris "  a) En la web elevenlabs.io con Claude en Chrome (no hace falta clave)."
  gris "  b) Con el MCP de ElevenLabs, que necesita una clave de API (elevenlabs.io → Developers → API Keys)."
  pregunta "Si tiene la clave de ElevenLabs, péguela aquí (Enter para saltar):"
  if [ -n "$R" ]; then
    tiene uv || brew install uv >/dev/null 2>&1; ruta
    claude mcp remove elevenlabs -s user >/dev/null 2>&1
    if claude mcp add --scope user elevenlabs -e ELEVENLABS_API_KEY="$R" -- uvx elevenlabs-mcp >/dev/null 2>&1; then verde "MCP elevenlabs"
    else falla "MCP elevenlabs"; fi
  else
    gris "Sin MCP de ElevenLabs: la voz se genera en la web."
  fi
  R=""

  echo
  if si "¿Instalo Higgsfield (clips animados con IA; es de pago y es el último recurso)?"; then
    if npm install -g @higgsfield/cli >/dev/null 2>&1 && npx -y skills add higgsfield-ai/skills -g -a claude-code -s '*' -y --copy >/dev/null 2>&1; then
      verde "Higgsfield CLI y skills (entrar luego con: higgsfield auth login)"
    else falla "Higgsfield"; fi
  fi
fi

# ─────────────────────────────────────────────── 7. Proyecto
paso 7 "Carpeta del proyecto de videos"
if [ -f "$DESTINO/package.json" ]; then
  verde "Ya existe $DESTINO; no se toca lo que hay (solo se completan dependencias)"
else
  mkdir -p "$DESTINO"
  cp -R "$FUENTE/plantilla/." "$DESTINO/"
  verde "Proyecto copiado a $DESTINO"
fi
mkdir -p "$DESTINO/models" "$DESTINO/out" "$DESTINO/tmp" "$DESTINO/guiones"
( cd "$DESTINO" && git init -q 2>/dev/null; true )
gris "Instalando Remotion (npm install)..."
if ( cd "$DESTINO" && npm install --no-audit --no-fund >/dev/null 2>&1 ); then verde "Remotion"
else falla "npm install en $DESTINO"; fi
gris "Bajando el Chrome de Remotion (para capturas y render)..."
if ( cd "$DESTINO" && npx remotion browser ensure >/dev/null 2>&1 ); then verde "Chrome de Remotion"
else falla "Chrome de Remotion"; fi
gris "numpy para los scripts de voz..."
if $PY -c 'import numpy' 2>/dev/null \
  || $PY -m pip install --user -q numpy >/dev/null 2>&1 \
  || $PY -m pip install --user -q --break-system-packages numpy >/dev/null 2>&1; then verde "numpy"
else falla "numpy (python3 -m pip install --user numpy)"; fi

# ─────────────────────────────────────────────── 8. Modelo de whisper
paso 8 "Modelo de voz a texto (whisper, español)"
if ls "$DESTINO"/models/ggml-*.bin >/dev/null 2>&1; then
  verde "Ya hay modelo: $(basename "$(ls "$DESTINO"/models/ggml-*.bin | head -1)")"
else
  gris "medium = el que se usa (1.5 GB, más preciso) · small = más liviano (466 MB)"
  pregunta "¿Cuál bajo? [Enter = medium, s = small]"
  M=medium; [ "$R" = "s" ] || [ "$R" = "S" ] && M=small
  gris "Bajando ggml-$M.bin..."
  if curl -fL --progress-bar -o "$DESTINO/models/ggml-$M.bin.part" \
       "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$M.bin" < /dev/null \
     && mv "$DESTINO/models/ggml-$M.bin.part" "$DESTINO/models/ggml-$M.bin"; then verde "Modelo $M"
  else rm -f "$DESTINO/models/ggml-$M.bin.part"; falla "Modelo de whisper"; fi
fi

# ─────────────────────────────────────────────── 9. Prueba
paso 9 "Prueba final"
if ( cd "$DESTINO" && npx remotion still Prueba out/prueba.png --frame=60 >/dev/null 2>&1 ) && [ -f "$DESTINO/out/prueba.png" ]; then
  verde "Remotion renderiza (out/prueba.png)"
else
  falla "La prueba de render no salió (cd $DESTINO && npx remotion still Prueba out/prueba.png)"
fi
whisper-cli --help >/dev/null 2>&1 && verde "whisper responde" || falla "whisper-cli no responde"

echo
if [ ${#FALLAS[@]} -eq 0 ]; then
  printf "\033[1;32mTodo quedó instalado.\033[0m\n"
else
  printf "\033[1;33mQuedó instalado, con %s pendiente(s):\033[0m\n" "${#FALLAS[@]}"
  for f in "${FALLAS[@]}"; do echo "  - $f"; done
  echo "  Puede correr el instalador otra vez; lo que ya está no se repite."
fi
cat <<FIN

Para empezar:
  cd "$DESTINO" && claude

  Y pídale el video que quiere: un tutorial, una promo, un video con subtítulos…
  Claude sigue el método de CLAUDE.md: guion → material → voz → render.

  Vista previa:  cd "$DESTINO" && npm run dev
  Para la voz en la web: instale Claude en Chrome (https://claude.ai/chrome) y entre a elevenlabs.io.

FIN
