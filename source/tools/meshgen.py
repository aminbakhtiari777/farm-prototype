"""Generates the smooth procedural placeholder meshes (OBJ) used by v2.

Run:  python3 tools/meshgen.py   (numpy only)
Output: assets/models/procedural/*.obj

All meshes are authored in the local space of the node that holds them
(e.g. arm meshes hang down from the shoulder pivot), so the procedural
animation in the Visual scripts keeps working. Models face +Z.
"""
import os
import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "models", "procedural")


# ---------------------------------------------------------------- utilities
def smooth_interp(keys, n):
    """Catmull-Rom-ish smooth resampling of keyframe rows -> n rows."""
    keys = np.asarray(keys, dtype=float)
    t_key = np.linspace(0, 1, len(keys))
    t = np.linspace(0, 1, n)
    out = np.zeros((n, keys.shape[1]))
    for c in range(keys.shape[1]):
        # monotone cubic (PCHIP-like) via numpy: use np.interp on a densified cosine blend
        out[:, c] = _pchip(t_key, keys[:, c], t)
    return out


def _pchip(x, y, xi):
    h = np.diff(x)
    d = np.diff(y) / h
    m = np.zeros_like(y)
    m[0], m[-1] = d[0], d[-1]
    for k in range(1, len(y) - 1):
        if d[k - 1] * d[k] <= 0:
            m[k] = 0
        else:
            w1, w2 = 2 * h[k] + h[k - 1], h[k] + 2 * h[k - 1]
            m[k] = (w1 + w2) / (w1 / d[k - 1] + w2 / d[k])
    idx = np.clip(np.searchsorted(x, xi) - 1, 0, len(x) - 2)
    t = (xi - x[idx]) / h[idx]
    h00 = 2 * t**3 - 3 * t**2 + 1
    h10 = t**3 - 2 * t**2 + t
    h01 = -2 * t**3 + 3 * t**2
    h11 = t**3 - t**2
    return h00 * y[idx] + h10 * h[idx] * m[idx] + h01 * y[idx + 1] + h11 * h[idx] * m[idx + 1]


def superellipse(theta, rx, rz, p):
    c, s = np.cos(theta), np.sin(theta)
    return rx * np.sign(c) * np.abs(c) ** (2.0 / p), rz * np.sign(s) * np.abs(s) ** (2.0 / p)


class Mesh:
    def __init__(self):
        self.v = []
        self.f = []

    def grid(self, P, close_u=True, pole_start=None, pole_end=None):
        """P: (rows, cols, 3) ring grid. Rings wrap around (close_u)."""
        rows, cols, _ = P.shape
        base = len(self.v)
        mid = rows // 2
        self.probe = (base + mid * cols, base + mid * cols + 1, base + (mid + 1) * cols + 1,
                      P[mid].mean(axis=0))
        self.v.extend(P.reshape(-1, 3).tolist())
        idx = lambda r, c: base + r * cols + (c % cols)
        cmax = cols if close_u else cols - 1
        for r in range(rows - 1):
            for c in range(cmax):
                a, b, cc, d = idx(r, c), idx(r, c + 1), idx(r + 1, c + 1), idx(r + 1, c)
                self.f.append((a, b, cc))
                self.f.append((a, cc, d))
        if pole_start is not None:
            p = len(self.v)
            self.v.append(list(pole_start))
            for c in range(cmax):
                self.f.append((p, idx(0, c + 1), idx(0, c)))
        if pole_end is not None:
            p = len(self.v)
            self.v.append(list(pole_end))
            for c in range(cmax):
                self.f.append((p, idx(rows - 1, c), idx(rows - 1, c + 1)))
        return self

    def fix_winding(self, inside_point):
        """Make faces point away from inside_point (works for star-shaped meshes)."""
        V = np.asarray(self.v)
        fixed = []
        for a, b, c in self.f:
            n = np.cross(V[b] - V[a], V[c] - V[a])
            centre = (V[a] + V[b] + V[c]) / 3
            if np.dot(n, centre - np.asarray(inside_point)) < 0:
                fixed.append((a, c, b))
            else:
                fixed.append((a, b, c))
        self.f = fixed
        return self

    def write(self, name):
        V = np.asarray(self.v, dtype=float)
        F = np.asarray(self.f, dtype=int)
        N = np.zeros_like(V)
        fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
        for k in range(3):
            np.add.at(N, F[:, k], fn)
        N /= np.linalg.norm(N, axis=1, keepdims=True) + 1e-12
        os.makedirs(OUT, exist_ok=True)
        path = os.path.join(OUT, name + ".obj")
        with open(path, "w") as fh:
            fh.write("# procedural placeholder mesh: %s\n" % name)
            for x, y, z in V:
                fh.write("v %.5f %.5f %.5f\n" % (x, y, z))
            for x, y, z in N:
                fh.write("vn %.4f %.4f %.4f\n" % (x, y, z))
            for x, y, z in V:  # planar UVs (materials mostly use triplanar)
                fh.write("vt %.4f %.4f\n" % (x * 2 + 0.5, y * 2 + 0.5))
            for a, b, c in F + 1:
                fh.write("f %d/%d/%d %d/%d/%d %d/%d/%d\n" % (a, a, a, b, b, b, c, c, c))
        print("wrote", name, len(V), "verts", len(F), "tris")


def loft_y(keys, rows=24, seg=28, power=2.0, cap_start=True, cap_end=True):
    """Vertical loft. keys: [y, rx, rz, cx, cz] rows (any order of y)."""
    K = smooth_interp(keys, rows)
    th = np.linspace(0, 2 * np.pi, seg, endpoint=False)
    P = np.zeros((rows, seg, 3))
    for i, (y, rx, rz, cx, cz) in enumerate(K):
        x, z = superellipse(th, rx, rz, power)
        P[i, :, 0], P[i, :, 1], P[i, :, 2] = x + cx, y, z + cz
    m = Mesh().grid(P, pole_start=(K[0, 3], K[0, 0], K[0, 4]) if cap_start else None,
                    pole_end=(K[-1, 3], K[-1, 0], K[-1, 4]) if cap_end else None)
    return m, K


def loft_z(keys, rows=32, seg=28, power=2.0):
    """Horizontal loft along Z. keys: [z, rx, ry, cx, cy]."""
    K = smooth_interp(keys, rows)
    th = np.linspace(0, 2 * np.pi, seg, endpoint=False)
    P = np.zeros((rows, seg, 3))
    for i, (z, rx, ry, cx, cy) in enumerate(K):
        x, y = superellipse(th, rx, ry, power)
        P[i, :, 0], P[i, :, 1], P[i, :, 2] = x + cx, y + cy, z
    return Mesh().grid(P, pole_start=(K[0, 3], K[0, 4], K[0, 0]), pole_end=(K[-1, 3], K[-1, 4], K[-1, 0])), K


def orient(m):
    """Grid winding is consistent by construction; flip everything if it faces inward."""
    a, b, c, ring_centre = m.probe
    V = np.asarray(m.v)
    n = np.cross(V[b] - V[a], V[c] - V[a])
    if np.dot(n, (V[a] + V[b] + V[c]) / 3 - ring_centre) < 0:
        m.f = [(x, z, y) for x, y, z in m.f]
    return m


def finish(m, name):
    orient(m).write(name)


# Simple 3D value noise for organic displacement.
class Noise3:
    def __init__(self, seed):
        rng = np.random.default_rng(seed)
        self.dirs = rng.normal(size=(48, 3))
        self.dirs /= np.linalg.norm(self.dirs, axis=1, keepdims=True)
        self.phase = rng.uniform(0, 2 * np.pi, 48)
        self.scale = rng.uniform(0.7, 1.3, 48)

    def __call__(self, P, freq):
        P = np.asarray(P)
        acc = np.zeros(len(P))
        for d, ph, s in zip(self.dirs, self.phase, self.scale):
            acc += np.sin(P @ d * freq * s + ph)
        return acc / np.sqrt(len(self.dirs) / 2)


def displaced_sphere(radii, centre, seed, amp_lo, f_lo, amp_hi=0.0, f_hi=0.0, rows=28, seg=40, flatten_bottom=None):
    noise = Noise3(seed)
    th = np.linspace(0, 2 * np.pi, seg, endpoint=False)
    ph = np.linspace(0.08, np.pi - 0.08, rows)
    P = np.zeros((rows, seg, 3))
    for i, p in enumerate(ph):
        P[i, :, 0] = np.sin(p) * np.cos(th)
        P[i, :, 1] = np.cos(p)
        P[i, :, 2] = np.sin(p) * np.sin(th)
    U = P.reshape(-1, 3)
    d = 1 + amp_lo * noise(U, f_lo) + amp_hi * noise(U * 1.7 + 3, f_hi)
    Q = U * d[:, None] * np.asarray(radii)
    if flatten_bottom is not None:
        Q[:, 1] = np.maximum(Q[:, 1], flatten_bottom)
    Q += np.asarray(centre)
    P = Q.reshape(rows, seg, 3)
    top = np.asarray(centre) + np.array([0, radii[1] * (1 + amp_lo * noise(np.array([[0, 1, 0]]), f_lo)[0]), 0])
    bot = np.asarray(centre) + np.array([0, -radii[1], 0])
    if flatten_bottom is not None:
        bot[1] = max(bot[1], flatten_bottom + centre[1])
    m = Mesh().grid(P, pole_start=top, pole_end=bot)
    return m


# ---------------------------------------------------------------- farmer
def farmer():
    # Shirt torso, in Body space (Body pivot = hips, world y 0.92). [y, rx, rz, cx, cz]
    m, _ = loft_y([
        [-0.04, 0.135, 0.100, 0, 0.000],
        [0.08, 0.150, 0.108, 0, 0.000],
        [0.18, 0.150, 0.106, 0, 0.004],
        [0.30, 0.170, 0.114, 0, 0.012],
        [0.40, 0.188, 0.118, 0, 0.010],
        [0.47, 0.196, 0.110, 0, 0.000],
        [0.52, 0.172, 0.098, 0, -0.008],
        [0.565, 0.110, 0.082, 0, -0.010],
        [0.60, 0.060, 0.058, 0, -0.008],
    ], rows=30, seg=36, power=2.2)
    finish(m, "farmer_torso")

    # Overalls lower part (waist to crotch), slightly larger than the shirt.
    m, _ = loft_y([
        [-0.15, 0.090, 0.080, 0, 0.0],
        [-0.10, 0.158, 0.118, 0, 0.0],
        [0.02, 0.163, 0.120, 0, 0.0],
        [0.12, 0.158, 0.114, 0, 0.004],
        [0.17, 0.157, 0.113, 0, 0.005],
    ], rows=14, seg=36, power=2.4, cap_end=False)
    finish(m, "farmer_overalls_hips")

    # Leg (Hip pivot space, hangs down). Denim.
    m, _ = loft_y([
        [0.06, 0.050, 0.050, 0, 0],
        [0.02, 0.088, 0.092, 0, 0],
        [-0.12, 0.084, 0.088, 0, 0.004],
        [-0.30, 0.068, 0.070, 0, 0.004],
        [-0.42, 0.060, 0.063, 0, 0.0],
        [-0.52, 0.064, 0.068, 0, -0.006],
        [-0.68, 0.054, 0.056, 0, 0.0],
        [-0.76, 0.052, 0.054, 0, 0.0],
        [-0.79, 0.030, 0.030, 0, 0.0],
    ], rows=24, seg=24)
    finish(m, "farmer_leg")

    # Boot (Hip space): shaft + foot, one smooth piece along Z.
    m, _ = loft_z([
        [-0.075, 0.020, 0.030, 0, -0.835],
        [-0.065, 0.055, 0.050, 0, -0.825],
        [-0.030, 0.062, 0.058, 0, -0.815],
        [0.030, 0.058, 0.040, 0, -0.840],
        [0.110, 0.050, 0.032, 0, -0.850],
        [0.150, 0.036, 0.026, 0, -0.853],
        [0.165, 0.010, 0.010, 0, -0.855],
    ], rows=20, seg=24, power=2.6)
    finish(m, "farmer_boot")
    m, _ = loft_y([
        [-0.86, 0.060, 0.064, 0, -0.01],
        [-0.80, 0.062, 0.066, 0, -0.005],
        [-0.70, 0.060, 0.064, 0, 0.0],
        [-0.68, 0.058, 0.062, 0, 0.0],
    ], rows=8, seg=24, cap_start=False, cap_end=False)
    finish(m, "farmer_boot_shaft")

    # Upper arm with deltoid in a shirt sleeve (Shoulder pivot space).
    m, _ = loft_y([
        [0.050, 0.022, 0.022, -0.004, 0],
        [0.034, 0.054, 0.058, -0.004, 0],
        [0.00, 0.062, 0.064, 0.0, 0],
        [-0.08, 0.056, 0.058, 0.0, 0],
        [-0.20, 0.050, 0.052, 0.0, 0],
        [-0.29, 0.049, 0.050, 0.0, 0],
        [-0.31, 0.036, 0.036, 0.0, 0],
    ], rows=20, seg=24)
    finish(m, "farmer_upper_arm")
    # Forearm (skin) - wrist tapers into the hand.
    m, _ = loft_y([
        [-0.25, 0.040, 0.040, 0, 0],
        [-0.29, 0.047, 0.048, 0, 0.002],
        [-0.36, 0.046, 0.044, 0, 0.004],
        [-0.46, 0.036, 0.032, 0, 0.004],
        [-0.535, 0.028, 0.025, 0, 0.004],
        [-0.56, 0.022, 0.020, 0, 0.004],
    ], rows=16, seg=20)
    finish(m, "farmer_forearm")
    # Palm (Hand node space): flat in X (thickness), wide in Z.
    m, _ = loft_y([
        [0.005, 0.016, 0.022, 0, 0],
        [-0.015, 0.021, 0.034, 0, 0.002],
        [-0.045, 0.022, 0.041, 0, 0.003],
        [-0.070, 0.019, 0.040, 0, 0.002],
        [-0.080, 0.012, 0.030, 0, 0.0],
    ], rows=12, seg=20, power=2.4)
    finish(m, "farmer_palm")
    # Neck (Body space).
    m, _ = loft_y([
        [0.54, 0.062, 0.058, 0, -0.012],
        [0.60, 0.054, 0.052, 0, -0.008],
        [0.66, 0.050, 0.050, 0, -0.004],
        [0.71, 0.048, 0.050, 0, 0.0],
    ], rows=10, seg=24, cap_start=False, cap_end=False)
    finish(m, "farmer_neck")

    # Hair shell (HeadPivot space). Head ellipsoid: centre (0, .11, 0), radii (.12, .135, .12).
    noise = Noise3(7)
    rows, seg = 34, 48
    th = np.linspace(0, 2 * np.pi, seg, endpoint=False)  # angle around Y; th=pi/2 -> +Z (face)
    ph = np.linspace(0.02, 0.86 * np.pi, rows)
    P = np.zeros((rows, seg, 3))
    for i, p in enumerate(ph):
        sx, sy, sz = np.sin(p) * np.cos(th), np.cos(p) * np.ones(seg), np.sin(p) * np.sin(th)
        U = np.stack([sx, sy, sz], axis=1)
        front = np.clip(sz, 0, 1)               # 1 at the face
        side = np.abs(sx)
        # Hairline height (unit-sphere y) where hair ends: high at the forehead, low at the nape.
        hairline = 0.6 * front ** 1.5 + (-0.05) * side - 0.45 * np.clip(-sz, 0, 1)
        hairline += 0.12 * front * np.clip(sx, 0, 1)  # side parting asymmetry
        inside = sy < hairline
        clump = 0.06 * noise(U, 5.0) + 0.025 * noise(U, 13.0)
        volume = 1.10 + 0.07 * np.clip(sy, 0, 1) + clump
        volume += 0.05 * front * np.clip(sy - 0.3, 0, 1) * (1 + np.clip(sx, -1, 1))  # quiff / swoop
        r = np.where(inside, 0.93, volume)
        P[i, :, 0] = sx * 0.12 * r
        P[i, :, 1] = sy * 0.135 * r + 0.11
        P[i, :, 2] = sz * 0.12 * r - 0.006
    m = Mesh().grid(P, pole_start=(0, 0.11 + 0.135 * 1.17, -0.006), pole_end=None)
    finish(m, "farmer_hair")


# ---------------------------------------------------------------- sheep
def sheep():
    # Wool body along Z (Rig space): rump at -Z, chest/neck rising at +Z. [z, rx, ry, cx, cy]
    m, K = loft_z([
        [-0.56, 0.05, 0.05, 0, 0.63],
        [-0.50, 0.20, 0.22, 0, 0.63],
        [-0.36, 0.28, 0.29, 0, 0.63],
        [-0.10, 0.30, 0.30, 0, 0.63],
        [0.15, 0.30, 0.30, 0, 0.64],
        [0.36, 0.26, 0.27, 0, 0.67],
        [0.48, 0.17, 0.20, 0, 0.72],
        [0.54, 0.05, 0.08, 0, 0.74],
    ], rows=40, seg=48, power=2.3)
    V = np.asarray(m.v)
    noise = Noise3(3)
    centre_axis = np.stack([np.zeros(len(V)), np.interp(V[:, 2], K[:, 0], K[:, 4]), V[:, 2]], axis=1)
    radial = V - centre_axis
    radial[:, 2] *= 0.25
    radial /= np.linalg.norm(radial, axis=1, keepdims=True) + 1e-9
    bump = 0.022 * noise(V, 16.0) + 0.012 * noise(V * 1.3 + 2, 34.0) + 0.03 * noise(V, 6.0)
    belly = np.clip((0.42 - V[:, 1]) / 0.15, 0, 1)  # flatter, tighter wool under the belly
    m.v = (V + radial * (bump * (1 - 0.6 * belly))[:, None]).tolist()
    finish(m, "sheep_body")

    # Head along Z (HeadPivot space): wide cranium tapering into a soft muzzle.
    m, _ = loft_z([
        [0.03, 0.020, 0.020, 0, 0.050],
        [0.05, 0.068, 0.078, 0, 0.050],
        [0.10, 0.085, 0.092, 0, 0.045],
        [0.17, 0.076, 0.082, 0, 0.022],
        [0.24, 0.058, 0.064, 0, -0.005],
        [0.30, 0.050, 0.054, 0, -0.025],
        [0.335, 0.040, 0.040, 0, -0.035],
        [0.35, 0.010, 0.010, 0, -0.038],
    ], rows=24, seg=32, power=2.2)
    finish(m, "sheep_head")
    # Leg (Leg pivot space): thicker, with a knee and a slim pastern.
    m, _ = loft_y([
        [0.0, 0.060, 0.062, 0, 0],
        [-0.10, 0.056, 0.058, 0, 0],
        [-0.20, 0.046, 0.048, 0, 0.004],
        [-0.24, 0.050, 0.050, 0, 0.004],
        [-0.33, 0.040, 0.040, 0, 0.004],
        [-0.37, 0.040, 0.042, 0, 0.008],
    ], rows=14, seg=16, cap_start=False)
    finish(m, "sheep_leg")


# ---------------------------------------------------------------- nature
def nature():
    for i in range(4):
        m = displaced_sphere((1.0, 0.82, 1.0), (0, 0, 0), seed=20 + i, amp_lo=0.16, f_lo=2.2,
                             amp_hi=0.06, f_hi=6.5, rows=18, seg=26)
        finish(m, "canopy_blob_%d" % (i + 1))
    for i in range(2):
        rng = np.random.default_rng(40 + i)
        h = 1.0
        bend = rng.uniform(-0.06, 0.06, 2)
        keys = []
        for y, r in [(0.0, 0.16), (0.04, 0.115), (0.12, 0.09), (0.45, 0.075), (0.8, 0.06), (1.0, 0.05)]:
            keys.append([y * h, r * rng.uniform(0.95, 1.05), r * rng.uniform(0.95, 1.05), bend[0] * y * y, bend[1] * y * y])
        m, _ = loft_y(keys, rows=16, seg=14, cap_start=False)
        # Root flare bumps
        V = np.asarray(m.v)
        ang = np.arctan2(V[:, 2], V[:, 0])
        low = np.clip(1 - V[:, 1] / 0.15, 0, 1)
        f = 1 + 0.35 * low * np.clip(np.cos(ang * 5 + i), 0, 1)
        V[:, 0] *= f
        V[:, 2] *= f
        m.v = V.tolist()
        finish(m, "trunk_%d" % (i + 1))


if __name__ == "__main__":
    farmer()
    sheep()
    nature()
