// Copia ligera para WhatsApp: volumen parejo (−16 LUFS), H.264 crf 25, arranque rápido.
// Uso: node scripts/whatsapp.mjs "out/Video v1.mp4"   → "out/Video v1 (WhatsApp).mp4"
import { spawnSync } from "node:child_process";
const ent = process.argv[2];
if (!ent) { console.error('Uso: node scripts/whatsapp.mjs "out/Video.mp4"'); process.exit(1); }
const sal = ent.replace(/\.mp4$/i, "") + " (WhatsApp).mp4";
const r = spawnSync("ffmpeg", ["-v", "error", "-y", "-i", ent, "-af", "loudnorm=I=-16:TP=-1.5:LRA=11",
  "-c:v", "libx264", "-preset", "slow", "-crf", "25", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
  "-c:a", "aac", "-b:a", "160k", sal], { stdio: "inherit" });
if (r.status === 0) console.log("listo:", sal);
process.exit(r.status ?? 1);
