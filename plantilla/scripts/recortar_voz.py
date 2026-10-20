# Quita trozos de una toma continua cortando en los silencios entre frases y
# rehace el voz.json (texto, palabras, ini, total) para la composición.
# Uso: recortar_voz.py <completa.wav> <voz.json> <salida.wav> <salida.json> <corte>...
#   corte = "seg" (frase entera) o "seg:w0-w1" (palabras w0..w1 de esa frase)
import json, subprocess, sys
import numpy as np

wav, vj, owav, ojson, *cortes = sys.argv[1:]
SR = 48000
raw = subprocess.run(["ffmpeg", "-v", "error", "-i", wav, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"], capture_output=True, check=True).stdout
a = np.frombuffer(raw, dtype=np.float32)
hop = int(0.01 * SR)
env = np.array([np.sqrt(np.mean(a[i:i + hop] ** 2)) for i in range(0, len(a) - hop, hop)])
v = json.load(open(vj))
T, P, I = v["texto"], v["palabras"], v["ini"]
n = len(T)

def abs_w(s, w):  # inicio y fin absolutos de la palabra w de la frase s
    p = P[str(s)][w]; return I[str(s)] + p["t"], I[str(s)] + p["t"] + p["d"]

def valle(t0, t1):
    i0, i1 = int(t0 * 100), max(int(t0 * 100) + 1, int(t1 * 100))
    return (i0 + int(np.argmin(env[i0:i1]))) / 100

quitar = []      # (t0, t1) absolutos
quitar_pal = {}  # seg -> set de palabras quitadas
for c in cortes:
    if ":" in c:
        s, r = c.split(":"); s = int(s); w0, w1 = map(int, r.split("-"))
        t0 = valle(abs_w(s, w0 - 1)[1] - 0.05, abs_w(s, w0)[0] + 0.03)
        t1 = valle(abs_w(s, w1)[1] - 0.05, abs_w(s, w1 + 1)[0] + 0.03)
        quitar.append((t0, t1)); quitar_pal[s] = set(range(w0, w1 + 1))
    else:
        s = int(c)
        t0 = I[str(s)]
        t1 = I[str(s + 1)] if s + 1 < n else len(a) / SR
        quitar.append((t0, t1)); quitar_pal[s] = None
quitar.sort()
unidos = []  # cortes contiguos se juntan en uno
for q in quitar:
    if unidos and q[0] <= unidos[-1][1] + 0.01: unidos[-1] = (unidos[-1][0], max(unidos[-1][1], q[1]))
    else: unidos.append(q)
quitar = unidos

def nuevo_t(t):  # tiempo en la toma recortada
    d = 0
    for q0, q1 in quitar:
        if t >= q1: d += q1 - q0
        elif t > q0: return q0 - d
    return t - d

partes, prev = [], 0
for q0, q1 in quitar:
    partes.append(a[int(prev * SR):int(q0 * SR)]); prev = q1
partes.append(a[int(prev * SR):])
f = int(0.01 * SR)
for k in range(len(partes) - 1):  # fundido corto en cada empalme
    partes[k] = partes[k].copy(); partes[k][-f:] *= np.linspace(1, 0, f)
    partes[k + 1] = partes[k + 1].copy(); partes[k + 1][:f] *= np.linspace(0, 1, f)
b = np.concatenate(partes)
subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ac", "1", "-ar", str(SR), "-i", "-", "-c:a", "pcm_s16le", owav], input=b.tobytes(), check=True)

texto, pal, ini = [], {}, {}
for s in range(n):
    if s in quitar_pal and quitar_pal[s] is None: continue
    k = len(texto)
    ws = T[s].split()
    keep = [i for i in range(len(ws)) if not (quitar_pal.get(s) and i in quitar_pal[s])]
    texto.append(" ".join(ws[i] for i in keep))
    s0 = nuevo_t(I[str(s)])
    ini[str(k)] = round(s0, 3)
    pal[str(k)] = [{"w": ws[i], "t": round(nuevo_t(I[str(s)] + P[str(s)][i]["t"]) - s0, 3), "d": P[str(s)][i]["d"]} for i in keep]
json.dump({"texto": texto, "palabras": pal, "ini": ini, "total": round(len(b) / SR, 3)}, open(ojson, "w"), ensure_ascii=False)
print("cortes", [(round(x, 2), round(y, 2)) for x, y in quitar], "total", round(len(b) / SR, 2))
for k, t in enumerate(texto): print(k, ini[str(k)], t)
