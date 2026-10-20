# Videos con Claude — instrucciones

Proyecto Remotion para hacer videos con Claude Code: tutoriales, promos, videos con
subtítulos, piezas verticales para WhatsApp o redes, u horizontales para proyectar.
Trae solo las herramientas; cada video se arma desde cero en su carpeta de `src/`.

## Herramientas

| Herramienta | Para qué |
|---|---|
| Remotion (`npx remotion`) | composición, vista previa (`npm run dev`) y render |
| Chrome de Remotion (`npx remotion browser ensure`) | fotografiar páginas web para el video (`scripts/capturar.mjs`) |
| `whisper-cli` + `models/ggml-*.bin` | tiempos por palabra de la voz (`scripts/transcribir.mjs`) |
| `ffmpeg` | convertir audio y video, copia ligera para WhatsApp (`scripts/whatsapp.mjs`) |
| Python 3 + numpy | partir y recortar una toma de voz (`scripts/partir_voz.py`, `scripts/recortar_voz.py`) |
| Plugin `remotion` y skills `remotion-*` | consultar `remotion-best-practices` antes de tocar animación, audio o render |
| Plugin `watch` (`/watch`) | revisar el MP4 renderizado (fotogramas + transcripción) antes de entregarlo |
| ElevenLabs (web en Chrome, o el MCP `elevenlabs` si se instaló) | la voz |
| MCP `whisper` | transcribir audios sueltos desde la conversación |
| Higgsfield (si se instaló) | clips animados con IA; último recurso, cuesta créditos |

## Flujo de un video

1. **Guion primero.** Frases cortas, una idea por frase. Se le muestra a la persona y
   **no se sigue sin su aprobación**. Guardarlo en `guiones/AAAA-MM-DD — <tema>.md`.
2. **Carpeta del video.** `src/<video>/` con su composición, registrada en `src/Root.tsx`.
   Para el segundo video en adelante, copiar la carpeta del más reciente y adaptarla.
3. **Material.** Fotos, logos y clips en `public/<video>/`. Si hay que mostrar una página web,
   preparar una copia local con datos de ejemplo y fotografiarla con
   `node scripts/capturar.mjs <config.json>` (ver el encabezado del script). Nunca usar
   datos reales de personas ni iniciar sesión en sistemas reales para capturar.
   Si falta un logo o una foto, pedírsela a la persona; no inventarla.
4. **Voz — una toma continua.** Generar el guion completo de una vez en ElevenLabs y usar la
   toma entera como una sola pista. **Nunca** partir la voz en frases pegadas con pausas
   fijas: suena cortado. Para corregir una frase, grabar solo esa e insertarla en un
   silencio, o quitarla con `recortar_voz.py`.
   - `ffmpeg -i toma.mp3 public/<video>/voz/completa.wav`
   - `node scripts/transcribir.mjs public/<video>/voz/completa.wav tmp/<video>-whisper`
   - Crear `tmp/<video>-voz.json` con `{"texto": ["frase 1", "frase 2", …]}` (el guion aprobado)
   - `python3 scripts/partir_voz.py public/<video>/voz/completa.wav tmp/<video>-whisper.json tmp/<video>-voz tmp/<video>-voz.json`
   - Copiar `tmp/<video>-voz/voz.json` a `src/<video>-voz.json`: trae el inicio de cada frase
     y el tiempo de cada palabra.
5. **Línea de tiempo anclada a la voz.** Cambios de escena, textos, toques y zooms se ubican
   con los tiempos de las palabras del `voz.json`, no con segundos puestos a mano.
6. **Vista previa:** `npm run dev`. **Render:**
   `npx remotion render <Id> "out/<Título> v1.mp4" --concurrency=6`
7. **Revisar** con `/watch out/<archivo>.mp4`: que voz e imagen coincidan, que no haya textos
   cortados ni pantallas vacías.
8. **Copia para WhatsApp:** `node scripts/whatsapp.mjs "out/<Título> v1.mp4"`
   (volumen parejo a −16 LUFS, H.264).

## Estilo

- Español con tildes y signos de apertura. Tono claro y natural, sin frases de afiche.
- Música de fondo que baja cuando se habla; efectos cortos en `public/sfx/`
  (`toque`, `pop`, `whoosh`, `tecla`, `exito`).
- Cada versión nueva lleva `v2`, `v3`… en el nombre; no se pisan las anteriores.

## Convenciones

- En Windows, `python3` se escribe `py -3` y las rutas llevan `\`; lo demás es igual.
- `out/`, `tmp/` y `models/` no se versionan.
- La primera vez, `npx remotion render Prueba out/prueba.mp4` confirma que todo funciona.
- No borrar originales de voz: las tomas quedan en `public/<video>/voz/`.
