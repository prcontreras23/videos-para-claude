// Fotografía una página web local escena por escena con el Chrome de Remotion.
// Cada escena se abre como <maqueta>?e=<escena>; la página pone su estado según ese
// parámetro. Si la página deja posiciones de elementos en <pre id="RECTS">{…}</pre>
// (y "alto" para páginas largas), se guardan en el JSON de rects para ubicar toques,
// resaltes y zooms en el video.
// Uso: node scripts/capturar.mjs scripts/<video>/capturas.json [escena …]
// capturas.json: { "maqueta": "tmp/<video>/index.html", "salida": "public/<video>",
//   "rects": "src/<video>-rects.json", "ancho": 390, "alto": 844, "escala": 3,
//   "fijas": ["escenas que no se alargan"], "escenas": ["inicio", "paso1", …] }
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

process.chdir(path.join(path.dirname(fileURLToPath(import.meta.url)), ".."));
const cfg = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));

const buscar = (dir) => {
  if (!fs.existsSync(dir)) return null;
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) { const r = buscar(p); if (r) return r; }
    else if (/^chrome-headless-shell(\.exe)?$/.test(e.name)) return p;
  }
  return null;
};
const CH = buscar("node_modules/.remotion/chrome-headless-shell");
if (!CH) { console.error("Falta el Chrome de Remotion. Corra: npx remotion browser ensure"); process.exit(1); }

const URL0 = pathToFileURL(path.resolve(cfg.maqueta)).href;
const opc = ["--headless", "--disable-gpu", "--lang=es-DO", "--allow-file-access-from-files", "--hide-scrollbars", "--virtual-time-budget=15000"];
const chrome = (args) => spawnSync(CH, [...opc, ...args], { encoding: "utf8", maxBuffer: 64 << 20 }).stdout || "";
const rectsDe = (dom) => { const m = dom.match(/<pre id="RECTS"[^>]*>([\s\S]*?)<\/pre>/); try { return m ? JSON.parse(m[1]) : null; } catch { return null; } };

fs.mkdirSync(cfg.salida, { recursive: true });
const { ancho: w, alto: h } = cfg;
const nuevos = {};
for (const e of process.argv.slice(3).length ? process.argv.slice(3) : cfg.escenas) {
  const url = `${URL0}?e=${e}`;
  let r = rectsDe(chrome([`--window-size=${w},${h}`, "--dump-dom", url]));
  let alto = h;
  if (!cfg.fijas?.includes(e) && r?.alto > h) { alto = r.alto; r = rectsDe(chrome([`--window-size=${w},${alto}`, "--dump-dom", url])); }
  chrome([`--force-device-scale-factor=${cfg.escala ?? 3}`, `--window-size=${w},${alto}`, `--screenshot=${path.resolve(cfg.salida, e + ".png")}`, url]);
  nuevos[e] = r;
  console.log(e, alto);
}
const viejo = fs.existsSync(cfg.rects) ? JSON.parse(fs.readFileSync(cfg.rects, "utf8")) : {};
fs.writeFileSync(cfg.rects, JSON.stringify({ ...viejo, ...nuevos }, null, 0));
