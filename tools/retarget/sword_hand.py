#!/usr/bin/env python3
"""Nastroj: spocita pro kazdy frame (Idle/Walk/Run x smer) pozici ruky s mecem z vrstvy rukavic
a ulozi hero/sword_hand.json  {"Walk (S)": [[x,y],...]}  (pixely ve framu 148x254).
Vybira tu ruku (blob rukavic), ktera je v prvnim framu nejblize kotve SWORD[dir] z hero_sprite.gd,
a pak ji sleduje (nejblizsi blob k predchozi pozici). --preview vykresli nahled s mecem."""
import json, sys, os, math
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
import retarget as R

# kotvy: dx od stredu framu, y (z hero_sprite.gd SWORD) - nacteno primo ze zdroje
src = open(os.path.join(R.ROOT, "hero", "hero_sprite.gd"), encoding="utf-8").read()
import re
sw = {}
for m in re.finditer(r'"([A-Z]{1,2})":\s*\[([-\d\.]+),\s*([-\d\.]+),\s*([-\d\.]+),\s*([-\d\.]+),\s*(\d)\]', src):
    sw[m.group(1)] = [float(m.group(i)) for i in range(2, 7)]

def label(mask):
    """4-souvisle komponenty -> seznam (plocha, centroid, maska)"""
    H, W = mask.shape
    seen = np.zeros_like(mask, bool)
    out = []
    for y0, x0 in zip(*np.nonzero(mask)):
        if seen[y0, x0]:
            continue
        st = [(y0, x0)]
        seen[y0, x0] = True
        pts = []
        while st:
            y, x = st.pop()
            pts.append((y, x))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                yy, xx = y + dy, x + dx
                if 0 <= yy < H and 0 <= xx < W and mask[yy, xx] and not seen[yy, xx]:
                    seen[yy, xx] = True
                    st.append((yy, xx))
        a = np.array(pts)
        out.append((len(pts), np.array([a[:, 1].mean(), a[:, 0].mean()])))
    return out


def blobs(frame_masks, i):
    """ruce = mensi komponenty v kalhoty|rukavice (hlavni kalhoty = nejvetsi komponenta)"""
    m = frame_masks["kalhoty"][i] | frame_masks["rukavice"][i]
    comps = label(m)
    if not comps:
        return []
    comps.sort(key=lambda c: -c[0])
    hands = [c[1] for c in comps[1:] if c[0] >= 12]
    return hands or [comps[0][1]]

res = {}
BATTLE = ["Swordslash", "Attackcombo3hit", "Attackthrust", "Castspell", "Attackranged", "Block", "Victory"]
SHOULDER = np.array([72.0, 105.0])   # ramenni kloub hrdiny v profilu (W) v pixelech framu
jobs = [(a, d) for a in ["Idle", "Walk", "Run"] for d in ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]]
jobs += [(a, "W") for a in BATTLE]
for anim, d in jobs:
    if True:
        key = f"{anim} ({d})"
        try:
            fm = R.frames_masks(key)
        except Exception:
            continue
        if fm.get("rukavice") is None:
            continue
        cfg = sw.get(d)
        if cfg is None:
            continue
        w = 148
        anchor = np.array([w / 2 + cfg[0], cfg[1]])
        track, prev = [], None
        for fi in range(len(fm["rukavice"])):
            bl = blobs(fm, fi)
            if not bl:
                track.append(list(prev) if prev is not None else anchor.tolist())
                continue
            ref = prev if prev is not None else anchor
            c = min(bl, key=lambda p: np.hypot(*(p - ref)))
            row = [round(float(c[0]), 1), round(float(c[1]), 1)]
            if anim in BATTLE:   # cepel pokracuje smerem od ramene k ruce (predlokti)
                v = c - SHOULDER
                row.append(round(math.degrees(math.atan2(v[0], -v[1])), 1))
            track.append(row)
            prev = np.array(track[-1][:2])
        if anim in BATTLE and len(track) > 2:
            a = np.array(track, float)
            for i in range(1, len(a)):          # skok ruky > 28 px = spatny blob -> vezmi predchozi
                if np.hypot(*(a[i, :2] - a[i - 1, :2])) > 28:
                    a[i] = a[i - 1]
            k = a.copy()                       # vyhlazeni uhlu a pozice (3 framy)
            for i in range(1, len(a) - 1):
                k[i] = (a[i - 1] + 2 * a[i] + a[i + 1]) / 4
            track = [[round(float(v), 1) for v in r] for r in k]
        res[key] = track
json.dump(res, open(os.path.join(R.ROOT, "hero", "sword_hand.json"), "w"))
print(len(res), "animaci ->", "hero/sword_hand.json")
if "--preview" in sys.argv:
    key = "Walk (S)"
    fm = R.frames_masks(key)
    n = len(fm["telo"])
    sheet = Image.new("RGBA", (148 * n, 254), (70, 72, 90, 255))
    dr = ImageDraw.Draw(sheet)
    for i in range(n):
        for p, col in zip(R.PARTS, [(200, 160, 120), (120, 160, 220), (255, 255, 0), (80, 80, 200), (150, 60, 60)]):
            m = fm[p][i]
            ys, xs = np.nonzero(m)
            for x, y in zip(xs, ys):
                sheet.putpixel((i * 148 + x, y), col + (255,))
        hx, hy = res[key][i]
        dr.ellipse([i * 148 + hx - 3, hy - 3, i * 148 + hx + 3, hy + 3], outline=(255, 0, 0, 255))
    sheet.save("/tmp/rt/hand_preview.png")
