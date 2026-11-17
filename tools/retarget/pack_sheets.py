#!/usr/bin/env python3
"""Zabali Aseprite-like sheety (frames + frameTags se smery) do hry:
   <vystup>/<postava>_<Anim>.png  radky = smery, sloupce = framy
   <vystup>/<postava>.json        {Anim: {w,h,frames,dirs:[..],fps}}
Pouziti: pack_sheets.py <vstupni_slozka_postavy> <jmeno> <vystup> [Prefix=Anim prejmenovani]
Slozka postavy ma podslozky <Anim>/*_sheet.png + *_sheet.json"""
import sys, os, json, glob
from PIL import Image

def pack(src, name, out, rename=None):
    rename = rename or {}
    meta = {}
    for d in sorted(os.listdir(src)):
        dd = os.path.join(src, d)
        js = [f for f in glob.glob(dd + "/*_sheet.json") if "kopie" not in f]
        if not os.path.isdir(dd) or not js:
            continue
        j = json.load(open(js[0]))
        im = Image.open(js[0][:-4] + "png").convert("RGBA")
        fr = j["frames"]
        fr = [fr[k] for k in sorted(fr, key=lambda s: int(s.split()[-1].split(".")[0]))] if isinstance(fr, dict) else fr
        if isinstance(fr[0], (list, tuple)):  # [(name, data)]
            fr = [f[1] for f in fr]
        tags = j["meta"]["frameTags"]
        w, h = fr[0]["frame"]["w"], fr[0]["frame"]["h"]
        n = tags[0]["to"] - tags[0]["from"] + 1
        sheet = Image.new("RGBA", (w * n, h * len(tags)), (0, 0, 0, 0))
        for r, t in enumerate(tags):
            for k in range(n):
                f = fr[t["from"] + k]["frame"]
                sheet.paste(im.crop((f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"])), (k * w, r * h))
        an = rename.get(d, d.replace(" ", ""))
        sheet.save(f"{out}/{name}_{an}.png")
        dur = fr[0].get("duration", 100)
        meta[an] = {"w": w, "h": h, "frames": n, "dirs": [t["name"] for t in tags], "fps": round(1000 / dur, 1)}
        print(name, an, sheet.size, meta[an]["dirs"], meta[an]["fps"])
    json.dump(meta, open(f"{out}/{name}.json", "w"), indent=1)

if __name__ == "__main__":
    pack(sys.argv[1], sys.argv[2], sys.argv[3], dict(a.split("=") for a in sys.argv[4:]))
