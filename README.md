# Videos con Claude

Instala en una Mac o una PC con Windows las herramientas para hacer videos con Claude Code
y Remotion, y deja una carpeta de proyecto lista para trabajar.

## Instalar

**Mac** — abrir la Terminal y pegar:

```bash
curl -fsSL https://raw.githubusercontent.com/prcontreras23/videos-para-claude/main/instalar.sh | bash
```

**Windows** — abrir PowerShell y pegar:

```powershell
irm https://raw.githubusercontent.com/prcontreras23/videos-para-claude/main/instalar-windows.ps1 | iex
```

Con el repo ya bajado también sirve doble clic en `Instalar en Mac.command` o `Instalar en Windows.bat`.

## Qué instala, paso por paso

| Paso | Qué | Para qué |
|---|---|---|
| 1 | Revisión de la computadora | sistema y espacio libre (hacen falta ~6 GB) |
| 2 | Homebrew (Mac) · Git, Node, Python 3.12 y ffmpeg con winget (Windows) | programas base |
| 3 | Node, Python, ffmpeg, git y whisper.cpp (Mac) · whisper.cpp oficial de GitHub (Windows) | render, audio y voz a texto |
| 4 | Claude Code (instalador oficial) | |
| 5 | Plugins `remotion`, `watch` y `frontend-design`; skills `remotion-*` | Claude sabe Remotion y puede ver el video terminado |
| 6 | MCP `whisper`; MCP `elevenlabs` (opcional, con clave de API); Higgsfield (opcional) | transcribir, voz, clips con IA |
| 7 | Proyecto en `~/videos` (Mac) o `%USERPROFILE%\videos` (Windows), `npm install`, Chrome de Remotion, numpy | |
| 8 | Modelo de whisper en español: `medium` (1.5 GB) o `small` (466 MB) | |
| 9 | Prueba: renderiza un cuadro de la composición `Prueba` | |

Lo que ya está instalado no se repite. Se puede correr otra vez si algo quedó pendiente.
Otra carpeta: `VIDEOS_DIR=/ruta bash instalar.sh` (Mac) o `$env:VIDEOS_DIR="C:\ruta"` antes del comando (Windows).

## Después de instalar

```bash
cd ~/videos
claude
```

Y pedirle el video que se quiere. El método está en `CLAUDE.md` del proyecto: guion
aprobado → material → voz en ElevenLabs (una toma continua) → tiempos por palabra con
whisper → render → revisión con `/watch` → copia para WhatsApp.

## Lo que queda por cuenta de cada persona

- **Voz:** cuenta en [ElevenLabs](https://elevenlabs.io). Sin clave de API, se genera en la web
  con [Claude en Chrome](https://claude.ai/chrome).
- **Higgsfield** (opcional): `higgsfield auth login` con su propia cuenta.

## Qué trae el proyecto

- `src/Prueba.tsx` — composición mínima para comprobar que todo renderiza.
- `public/sfx/` — efectos cortos (toque, pop, whoosh, tecla, éxito).
- `scripts/capturar.mjs` — fotografía una página web local escena por escena.
- `scripts/transcribir.mjs` — tiempos por palabra con whisper.
- `scripts/partir_voz.py` y `scripts/recortar_voz.py` — ubican cada frase en la toma continua
  y quitan frases sin cortar la voz.
- `scripts/whatsapp.mjs` — copia ligera para WhatsApp (−16 LUFS, H.264).
