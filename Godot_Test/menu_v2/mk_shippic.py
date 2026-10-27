"""Склейка двух снимков (чёрный и белый фон) в PNG с прозрачностью: python3 mk_shippic.py чёрный.png белый.png выход.png"""
import sys, numpy as np
from PIL import Image
b = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(np.float32); w = np.asarray(Image.open(sys.argv[2]).convert("RGB")).astype(np.float32)
a = np.clip(1.0 - (w - b).mean(axis=2) / 255.0, 0.0, 1.0)
col = np.where(a[..., None] > 0.01, b / np.maximum(a[..., None], 0.01), 0.0)
rgba = np.dstack([np.clip(col, 0, 255), a * 255.0]).astype(np.uint8)
im = Image.fromarray(rgba, "RGBA"); bb = im.getbbox(); im = im.crop(bb)
box = (680, 460); k = min(box[0] / im.width, box[1] / im.height); im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
out = Image.new("RGBA", box, (0, 0, 0, 0)); out.paste(im, ((box[0] - im.width) // 2, (box[1] - im.height) // 2), im); out.save(sys.argv[3]); print(bb, out.size)
