# Parte la toma continua de ElevenLabs en las frases del guion y saca tiempos por palabra.
# Uso: python3 scripts/partir_voz.py <toma.mp3> <whisper.json> <carpeta_voz> <voz.json con "texto">
import json, os, subprocess, sys, unicodedata, difflib, re
import numpy as np

mp3, wj, OUT, vozjson = sys.argv[1:5]
os.makedirs(OUT, exist_ok=True)
SR = 48000
vz = json.load(open(vozjson))
TEXTO = vz["texto"]

def norm(s):
    s = unicodedata.normalize("NFD", s.lower())
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    return re.sub(r"[^a-z0-9]", "", s)

# tokens del guion
toks = []  # (seg, idx, norm)
for si, t in enumerate(TEXTO):
    for wi, w in enumerate(t.split()):
        toks.append((si, wi, norm(w)))

# palabras de whisper (un segmento por palabra con -ml 1); se parten las que traen varias
ws = []
# whisper (-ml 1) entrega piezas de palabra: las que no empiezan con espacio se pegan a la anterior
crudo = []
for s in json.load(open(wj))["transcription"]:
    t = s["text"]
    if not t.strip(): continue
    a, b = s["offsets"]["from"] / 1000, s["offsets"]["to"] / 1000
    if crudo and not t.startswith(" ") and not re.match(r"^[¿¡«\"]", t):
        crudo[-1][0] += t; crudo[-1][2] = b
    else:
        crudo.append([t, a, b])
for txt, a, b in crudo:
    txt = txt.strip()
    partes = [p for p in re.split(r"[\s./]+", txt) if norm(p)]
    if not partes: continue
    for k, p in enumerate(partes):
        ws.append((norm(p), a + (b - a) * k / len(partes), a + (b - a) * (k + 1) / len(partes)))

A = [t[2] for t in toks]
B = [w[0] for w in ws]
sm = difflib.SequenceMatcher(a=A, b=B, autojunk=False)
tiempo = [None] * len(toks)
for blk in sm.get_matching_blocks():
    for k in range(blk.size):
        w = ws[blk.b + k]
        tiempo[blk.a + k] = (w[1], w[2])
# interpolar los que no casaron
idx = [i for i, t in enumerate(tiempo) if t]
for i in range(len(toks)):
    if tiempo[i] is None:
        p = max([j for j in idx if j < i], default=None)
        n = min([j for j in idx if j > i], default=None)
        t0 = tiempo[p][1] if p is not None else 0
        t1 = tiempo[n][0] if n is not None else t0 + 0.4
        # repartir entre los huecos consecutivos
        run = [j for j in range((p if p is not None else -1) + 1, n if n is not None else len(toks))]
        k = run.index(i)
        d = (t1 - t0) / len(run)
        tiempo[i] = (t0 + k * d, t0 + (k + 1) * d)
faltan = len(toks) - len(idx)
print("palabras sin casar (interpoladas):", faltan, [toks[i][2] for i in range(len(toks)) if i not in idx])

raw = subprocess.run(["ffmpeg", "-v", "error", "-i", mp3, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"], capture_output=True, check=True).stdout
a = np.frombuffer(raw, dtype=np.float32)
hop = int(0.01 * SR)
env = np.array([np.sqrt(np.mean(a[i:i + hop] ** 2)) for i in range(0, len(a) - hop, hop)])

def valle(t0, t1):
    i0, i1 = int(t0 * 100), max(int(t0 * 100) + 1, int(t1 * 100))
    return (i0 + int(np.argmin(env[i0:i1]))) / 100

# cortes entre frases: el punto más silencioso entre la última palabra de una y la primera de la otra
primeras = {}; ultimas = {}
for (si, wi, _), tt in zip(toks, tiempo):
    primeras.setdefault(si, tt[0]); ultimas[si] = tt[1]
cortes = [0.0]
for si in range(1, len(TEXTO)):
    cortes.append(valle(ultimas[si - 1] - 0.1, primeras[si] + 0.05))
cortes.append(len(a) / SR)

umbral = env.max() * 0.02
pal = {}; dur = {}; ini = {}  # ini: dónde empieza cada frase dentro de la toma completa
for si in range(len(TEXTO)):
    c0, c1 = cortes[si], cortes[si + 1]
    # recortar silencio en los bordes
    i0, i1 = int(c0 * 100), int(c1 * 100)
    voz = np.where(env[i0:i1] > umbral)[0]
    s0 = max(c0, (i0 + voz[0]) / 100 - 0.06) if len(voz) else c0
    s1 = min(c1, (i0 + voz[-1]) / 100 + 0.18) if len(voz) else c1
    seg = a[int(s0 * SR):int(s1 * SR)].copy()
    f = int(0.006 * SR); seg[:f] *= np.linspace(0, 1, f); seg[-f:] *= np.linspace(1, 0, f)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ac", "1", "-ar", str(SR), "-i", "-", "-c:a", "pcm_s16le",
                    f"{OUT}/{si:02d}.wav"], input=seg.tobytes(), check=True)
    pal[si] = [{"w": w, "t": round(max(0, tt[0] - s0), 3), "d": round(tt[1] - tt[0], 3)}
               for (s, wi, _), tt, w in zip([x for x in toks if x[0] == si], [tiempo[i] for i, x in enumerate(toks) if x[0] == si], TEXTO[si].split())]
    dur[si] = round(len(seg) / SR, 3)
    ini[si] = round(s0, 3)
json.dump({"texto": TEXTO, "palabras": pal, "dur": dur, "ini": ini, "total": round(len(a) / SR, 3)}, open(f"{OUT}/voz.json", "w"), ensure_ascii=False)
print(dur, round(sum(dur.values()), 2))
for si in range(len(TEXTO)):
    print(si, " ".join(f"{p['w']}@{p['t']}" for p in pal[si]))
