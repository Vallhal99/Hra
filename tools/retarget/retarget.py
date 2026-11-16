#!/usr/bin/env python3
"""Retargeting animaci: hrdina (atlas po vrstvach) -> libovolna postava ve stejnem stylu.

1) analyze():  z vrstev atlasu (helma/telo/rukavice/kalhoty/boty) vytahne pro kazdou
               animaci pohyb casti tela (hlava, trup, 2 ruce, 2 nohy) + naklon tela.
2) retarget(): cilovy obrazek (jedna pozice) rozdeli podle sablony (JSON "kostra")
               na oblasti a hladkym polem posunu ho rozpohybuje podle hrdinovych stop.
3) vystup:     horizontalni sheet PNG + JSON (frames, fps) + kontaktni nahled + GIF.

Pouziti:  python3 -I retarget.py enemies/kostlivec.png tools/retarget/kostlivec.rig.json out_dir [Anim (D) ...]
"""
import json, sys, os, math
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ATLAS = os.path.join(ROOT, "hero", "atlas")
PARTS = ["helma", "telo", "rukavice", "kalhoty", "boty"]
FPS = {"Idle": 6, "Walk": 10, "Run": 13, "Swordslash": 12, "Attackthrust": 12, "Attackranged": 10,
       "Castspell": 10, "Attackcombo3hit": 12, "Block": 8, "Hurt": 10, "Death": 8, "Chargeup": 10, "Victory": 8}
LOOP = {"Idle", "Walk", "Run", "Chargeup"}

_cache = {}


def _layer(part):
    if part not in _cache:
        _cache[part] = (np.array(Image.open(f"{ATLAS}/nahe_{part}.png").convert("RGBA"))[:, :, 3] > 10,
                        json.load(open(f"{ATLAS}/nahe_{part}.json")))
    return _cache[part]


def frames_masks(anim):
    """{cast: [maska_framu,...]} pro animaci typu 'Walk (S)'"""
    out = {}
    for p in PARTS:
        a, j = _layer(p)
        e = j.get(anim)
        if not e:
            out[p] = None
            continue
        fw, fh = e["frame_w"], e["frame_h"]
        out[p] = [a[e["y"]:e["y"] + fh, e["x"] + i * fw: e["x"] + (i + 1) * fw] for i in range(e["frames"])]
    return out


def _centroid(m):
    ys, xs = np.nonzero(m)
    if len(xs) == 0:
        return None
    return np.array([xs.mean(), ys.mean()])


def _split2(m):
    """rozdeli masku na levou/pravou polovinu (nejvetsi mezera ve sloupcich, jinak median x)"""
    ys, xs = np.nonzero(m)
    if len(xs) == 0:
        return None, None
    cols = np.zeros(m.shape[1], bool)
    cols[xs] = True
    idx = np.nonzero(cols)[0]
    gaps = np.diff(idx)
    if len(gaps) and gaps.max() > 3:
        cut = idx[gaps.argmax()] + 0.5
    else:
        cut = np.median(xs)
    a, b = m.copy(), m.copy()
    a[:, int(math.ceil(cut)):] = False
    b[:, :int(math.ceil(cut))] = False
    return a, b


def _angle(m):
    ys, xs = np.nonzero(m)
    if len(xs) < 20:
        return 0.0
    c = np.cov(np.vstack([xs, ys]))
    w, v = np.linalg.eigh(c)
    ax = v[:, 1]
    ang = math.degrees(math.atan2(ax[0], -ax[1] if ax[1] > 0 else ax[1]))  # 0 = svisle
    return ang


def analyze(anim):
    fm = frames_masks(anim)
    n = len(fm["telo"])
    T = {k: [] for k in ["head", "torso", "hand_a", "hand_b", "foot_a", "foot_b"]}
    ang, body = [], []
    for i in range(n):
        g = lambda p: fm[p][i] if fm[p] is not None else np.zeros_like(fm["telo"][i])
        u = np.zeros_like(fm["telo"][i])
        for p in PARTS:
            u |= g(p)
        body.append(u)
        ang.append(_angle(u))
        T["head"].append(_centroid(g("helma")))
        T["torso"].append(_centroid(g("telo")))
        ha, hb = _split2(g("rukavice"))
        fa, fb = _split2(g("boty"))
        # v profilu se ruce/nohy prekryvaji -> druha cast = totez co prvni
        T["hand_a"].append(_centroid(ha) if ha is not None else None)
        T["hand_b"].append(_centroid(hb) if hb is not None and hb.sum() > 4 else T["hand_a"][-1])
        T["foot_a"].append(_centroid(fa) if fa is not None else None)
        T["foot_b"].append(_centroid(fb) if fb is not None and fb.sum() > 4 else T["foot_a"][-1])
    # vyska hrdiny v referencnim framu
    ys, xs = np.nonzero(body[0])
    h = ys.max() - ys.min() + 1
    # chybejici stopy -> nuly
    tracks = {}
    base = anim.split(" ")[0]
    for k, v in T.items():
        arr = np.array([x if x is not None else (np.array([np.nan, np.nan])) for x in v], float)
        # dopln NaN predchozi hodnotou
        for i in range(len(arr)):
            if np.isnan(arr[i]).any():
                arr[i] = arr[i - 1] if i > 0 and not np.isnan(arr[i - 1]).any() else np.nanmean(arr, axis=0) if not np.isnan(arr).all() else [0, 0]
        ref = arr.mean(axis=0) if base in LOOP else arr[0]
        tracks[k] = (arr - ref).tolist()
    a = np.array(ang)
    a = a - (a.mean() if base in LOOP else a[0])
    # zalamani uhlu (PCA ma nejednoznacny smer)
    a = (a + 90) % 180 - 90
    return {"anim": anim, "frames": n, "hero_h": int(h), "tracks": tracks, "angle": a.tolist()}


# --------------------------------------------------------------------------- aplikace
def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def retarget(img, rig, tr, gain=1.0, pad=(14, 8, 14, 6), flip=False, use_legs=True, rotate=None, topple=0.0, clamp=0.0):
    """img: RGBA PIL (cilova postava). rig: sablona. tr: vysledek analyze(). -> seznam PIL framu"""
    w, h = img.size
    L, T, R, B = pad
    W, H = w + L + R, h + T + B
    src = np.zeros((H, W, 4), np.uint8)
    src[T:T + h, L:L + w] = np.array(img.convert("RGBA"))
    # staticky stin: tmave pixely u zeme zustanou na miste
    shy = rig.get("shadow_y")
    shadow = np.zeros_like(src)
    if shy is not None:
        m = (src[:, :, 3] > 10) & (src[:, :, :3].max(axis=2) < rig.get("shadow_max", 50)) & (np.arange(H)[:, None] >= shy + T)
        shadow[m] = src[m]
        src[m] = 0
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    lx, ly = xx - L, yy - T                      # souradnice v puvodnim obrazku
    cx = rig["cx"]
    s = rig["height"] / tr["hero_h"] * gain
    n = tr["frames"]
    fr = []
    t = tr["tracks"]
    hy = rig["hip_y"]; fy = rig["foot_y"]
    wh = 1 - smooth(rig["neck_y"] - 14, rig["neck_y"] + 8, ly)
    wb = 1 - smooth(hy - 8, hy + 50, ly)
    wl = smooth(hy - 4, fy, ly) ** rig.get("leg_pow", 1.0)
    # strany: a = vlevo v obrazku
    sl = 1 - smooth(cx - 6, cx + 6, lx)
    sr = 1 - sl
    arm_y = smooth(rig["shoulder_y"], rig["hand_y"], ly) * (1 - smooth(rig["hand_y"] + 22, rig["hand_y"] + 40, ly))
    arm_l = (1 - smooth(rig["arm_x"], rig["arm_x"] + 8, lx)) * arm_y
    arm_r = smooth(2 * cx - rig["arm_x"] - 8, 2 * cx - rig["arm_x"], lx) * arm_y
    sgn = -1 if flip else 1
    for i in range(n):
        d = lambda k: np.array(t[k][i]) * s * np.array([sgn, 1.0])
        def cl(v):
            if clamp:
                n_ = float(np.hypot(*v))
                return v * (clamp / n_) if n_ > clamp else v
            return v
        Dt, Dh = cl(d("torso")), cl(d("head"))
        Da, Db = cl(d("hand_a")), cl(d("hand_b"))
        Fa, Fb = cl(d("foot_a")), cl(d("foot_b"))
        if not use_legs:
            Fa = Fb = Dt * 0.6
        if flip:
            Da, Db, Fa, Fb = Db, Da, Fb, Fa
        out = []
        D = []
        for c in range(2):
            body = Dt[c] + wh * (Dh[c] - Dt[c])
            body = body * (1 - arm_l - arm_r) + arm_l * Da[c] + arm_r * Db[c] if True else body
            legs = sl * Fa[c] + sr * Fb[c]
            D.append(body * (1 - wl) + legs * wl)
        dx, dy = D
        ang = math.radians(tr["angle"][i]) * gain if (rig.get("rotate", False) if rotate is None else rotate) else 0.0
        if topple:
            u = i / max(1, n - 1)
            e = u * u * (3 - 2 * u)
            ang = math.radians(topple * e)
            dx = dx * 0.0; dy = dy * 0.0
        sxp, syp = lx - dx, ly - dy
        if ang:
            px, py = cx, rig["foot_y"]
            c, sn = math.cos(-ang), math.sin(-ang)
            rx, ry = sxp - px, syp - py
            sxp, syp = px + rx * c - ry * sn, py + rx * sn + ry * c
        ix = np.rint(sxp).astype(int) + L
        iy = np.rint(syp).astype(int) + T
        ok = (ix >= 0) & (ix < W) & (iy >= 0) & (iy < H)
        o = np.zeros((H, W, 4), np.uint8)
        o[ok] = src[iy[ok], ix[ok]]
        im = Image.fromarray(shadow)
        im.alpha_composite(Image.fromarray(o))
        fr.append(im)
    return fr


def sheet(frames):
    w, h = frames[0].size
    s = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.paste(f, (i * w, 0))
    return s


def contact(frames, path, bg=(70, 72, 90, 255), zoom=2):
    w, h = frames[0].size
    s = Image.new("RGBA", (w * len(frames), h), bg)
    for i, f in enumerate(frames):
        s.alpha_composite(f, (i * w, 0))
    s = s.resize((s.width * zoom // 2, s.height * zoom // 2), Image.NEAREST) if zoom != 2 else s
    s.save(path)


def gif(frames, path, fps):
    fs = []
    for f in frames:
        b = Image.new("RGBA", f.size, (70, 72, 90, 255))
        b.alpha_composite(f)
        fs.append(b.convert("P", palette=Image.ADAPTIVE))
    fs[0].save(path, save_all=True, append_images=fs[1:], duration=int(1000 / fps), loop=0, disposal=2)


if __name__ == "__main__":
    png, rigf, outd = sys.argv[1:4]
    anims = sys.argv[4:] or ["Idle (S)", "Walk (S)"]
    rig = json.load(open(rigf))
    os.makedirs(outd, exist_ok=True)
    img = Image.open(png)
    meta = {}
    for a in anims:
        tr = analyze(a)
        base = a.split(" ")[0]
        name = rig.get("names", {}).get(base, base)
        opts = rig.get("anims", {}).get(base, {})
        fr = retarget(img, rig, tr, gain=opts.get("gain", 1.0), flip=opts.get("flip", False), use_legs=opts.get("legs", True), rotate=opts.get("rotate"), topple=opts.get("topple", 0.0), clamp=opts.get("clamp", 0.0), pad=tuple(opts.get("pad", (14, 8, 14, 6))))
        sheet(fr).save(f"{outd}/{os.path.splitext(os.path.basename(png))[0]}_{name}.png")
        contact(fr, f"{outd}/contact_{name}.png")
        gif(fr, f"{outd}/{name}.gif", FPS.get(base, 10))
        meta[name] = {"frames": len(fr), "fps": FPS.get(base, 10), "w": fr[0].width, "h": fr[0].height, "loop": base in LOOP}
        print(a, "->", name, len(fr), "frames, hero_h", tr["hero_h"])
    json.dump(meta, open(f"{outd}/{os.path.splitext(os.path.basename(png))[0]}_anims.json", "w"), indent=1)
