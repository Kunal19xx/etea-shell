#!/usr/bin/env python3
# Draw the night sky of the lock's skyward scene: flat bands, the Milky Way as heaped star
# clouds with pockets of dust, and a few thousand pinpricks. Pure vector, nothing blurred.
# The constellation isn't here: the lock draws it live, one star per letter.
#
#   skyward-sky.py [out.svg]   (default: assets/lock/skyward/sky.svg)
#
# The same seed draws the same sky every time.
import math
import random
import sys

random.seed(11)
W, H = 1920, 1080
out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">']
def f(v): return f"{v:.1f}".rstrip("0").rstrip(".")

# Sky in flat steps, each a gentle bowl, darkest at the top
bands = ["#030820", "#040A25", "#050D2B", "#061031", "#081438", "#0A1840"]
for i, col in enumerate(bands):
    top = i * 165 - 40
    if i == 0:
        out.append(f'<rect x="0" y="0" width="{W}" height="{H}" fill="{col}"/>')
        continue
    out.append(f'<path d="M0 {f(top+60)} Q{W/2} {f(top-50)} {W} {f(top+60)} L{W} {H} L0 {H} Z" fill="{col}"/>')

# A smooth closed outline through points, Catmull-Rom turned into cubic Béziers
def smooth(pts):
    n = len(pts); d = f"M{f(pts[0][0])} {f(pts[0][1])}"
    for i in range(n):
        p0, p1, p2, p3 = pts[i-1], pts[i], pts[(i+1) % n], pts[(i+2) % n]
        c1 = (p1[0] + (p2[0]-p0[0])/6, p1[1] + (p2[1]-p0[1])/6)
        c2 = (p2[0] - (p3[0]-p1[0])/6, p2[1] - (p3[1]-p1[1])/6)
        d += f" C{f(c1[0])} {f(c1[1])} {f(c2[0])} {f(c2[1])} {f(p2[0])} {f(p2[1])}"
    return d + " Z"

# The Milky Way rises behind them and leans away from her arm
A, B = (1010, 1140), (230, -80)
L = math.hypot(B[0]-A[0], B[1]-A[1]); ux, uy = (B[0]-A[0])/L, (B[1]-A[1])/L; nx, ny = -uy, ux

# Star clouds: irregular blobs heaped along the band, four tones from the edge to the core
def blob(cx, cy, r, stretch, seed):
    rnd = random.Random(seed); n = rnd.randint(9, 13); pts = []
    for k in range(n):
        t = 2*math.pi*k/n + rnd.uniform(-0.2, 0.2)
        rr = r * rnd.uniform(0.6, 1.15)
        ax, ay = math.cos(t)*rr*stretch, math.sin(t)*rr
        pts.append((cx + ux*ax + nx*ay, cy + uy*ax + ny*ay))  # stretched along the band
    return smooth(pts)
def heap(count, spread, rmin, rmax, col, seed, t0=0.0, t1=1.0, side=0.0):
    rnd = random.Random(seed); d = ""
    for i in range(count):
        t = rnd.uniform(t0, t1)
        off = rnd.gauss(side, spread)
        cx, cy = A[0] + ux*L*t + nx*off, A[1] + uy*L*t + ny*off
        d += blob(cx, cy, rnd.uniform(rmin, rmax), rnd.uniform(1.4, 2.6), seed*1000 + i) + " "
    out.append(f'<path d="{d}" fill="{col}"/>')
heap(46, 110, 70, 150, "#0A1745", 1)
heap(40, 70, 45, 105, "#0E1D51", 2, 0.03, 0.97)
heap(34, 42, 25, 62, "#13255E", 3, 0.08, 0.85)
heap(22, 22, 12, 34, "#1A306D", 4, 0.15, 0.7)
# Dust: dark pockets, mostly on one side of the core
heap(18, 26, 10, 30, "#0B1847", 5, 0.05, 0.8, side=-14)
heap(10, 18, 6, 16, "#0C1A4A", 6, 0.3, 0.75, side=20)

# Thousands of pinpricks, crowding along the Milky Way
buckets = {}
def star(x, y, r, col):
    buckets.setdefault((col, r), []).append((x, y))
cols = ["#FFFFFF", "#D6E2FF", "#B9CBFF", "#FFEBD0", "#8EA2D8", "#6F82B8"]
weights = [3, 3, 2, 1, 4, 5]
for i in range(2600):
    # Thinner towards the ground
    x, y = random.uniform(0, W), H * (random.random() ** 1.25)
    star(x, y, random.choice([0.5, 0.6, 0.6, 0.8, 0.8, 1.0, 1.2]), random.choices(cols, weights)[0])
for i in range(2400):
    t = random.random(); d = random.gauss(0, 120)
    x, y = A[0] + ux*L*t + nx*d, A[1] + uy*L*t + ny*d
    if 0 <= x <= W and 0 <= y <= H:
        star(x, y, random.choice([0.4, 0.5, 0.5, 0.6, 0.8]), random.choices(cols, [4, 4, 2, 1, 3, 3])[0])
for i in range(34):
    star(random.uniform(0, W), H * random.random() ** 1.4, random.choice([1.5, 1.7, 2.0]), random.choice(cols[:4]))
for (col, r), pts in buckets.items():
    d = " ".join(f"M{f(x-r)} {f(y)}a{r} {r} 0 1 0 {f(2*r)} 0a{r} {r} 0 1 0 {f(-2*r)} 0" for x, y in pts)
    out.append(f'<path d="{d}" fill="{col}"/>')

out.append("</svg>")
path = sys.argv[1] if len(sys.argv) > 1 else "assets/lock/skyward/sky.svg"
open(path, "w").write("\n".join(out))
