// Tiempos por palabra de una toma de voz con whisper.cpp (español).
// Uso: node scripts/transcribir.mjs <audio> <salida sin extensión>   → <salida>.json
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

process.chdir(path.join(path.dirname(fileURLToPath(import.meta.url)), ".."));
const [audio, salida] = process.argv.slice(2);
if (!audio || !salida) { console.error("Uso: node scripts/transcribir.mjs <audio> <salida>"); process.exit(1); }
const modelo = fs.readdirSync("models").filter((f) => f.startsWith("ggml-") && f.endsWith(".bin")).sort().reverse()[0];
if (!modelo) { console.error("No hay modelo en models/. Vuelva a correr el instalador."); process.exit(1); }
fs.mkdirSync("tmp", { recursive: true });
const run = (cmd, args) => { const r = spawnSync(cmd, args, { stdio: "inherit" }); if (r.status !== 0) process.exit(r.status ?? 1); };
run("ffmpeg", ["-v", "error", "-y", "-i", audio, "-ar", "16000", "-ac", "1", "tmp/audio16.wav"]);
run("whisper-cli", ["-m", path.join("models", modelo), "-l", "es", "-f", "tmp/audio16.wav", "-ml", "1", "-oj", "-of", salida]);
console.log(`listo: ${salida}.json`);
