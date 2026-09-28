#!/usr/bin/env python3
"""Generates the item icon set (SVG, 64x64 design units rendered at 128 px).

Run from the project root:  python3 tools/icons/gen_icons.py
Every icon shares the same outline color and light direction (top-left) so the set
reads as one family. Crop drawings are reused on the seed packets.
"""
import math
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "art", "icons", "items")
OL = "#2b2118"  # outline


def svg(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" '
            f'viewBox="0 0 64 64">{body}</svg>\n')


def stroke(w=2.0):
    return f'stroke="{OL}" stroke-width="{w}" stroke-linejoin="round" stroke-linecap="round"'


# --- Crops -----------------------------------------------------------------------

def wheat_head(x, y, angle, length=22, grains=5):
    """Grain head along a stalk ending at (x, y) pointing at `angle` degrees."""
    parts = []
    rad = math.radians(angle)
    dx, dy = math.sin(rad), -math.cos(rad)
    for i in range(grains):
        t = i / grains
        cx = x - dx * length * (1 - t) * 0.9
        cy = y - dy * length * (1 - t) * 0.9
        for side in (-1, 1):
            rot = angle + side * 28
            ox = cx + dy * side * 2.6 * -1
            oy = cy + dx * side * 2.6
            parts.append(f'<ellipse cx="{ox:.1f}" cy="{oy:.1f}" rx="2.6" ry="4.6" '
                         f'transform="rotate({rot:.0f} {ox:.1f} {oy:.1f})" fill="#e8b83a" {stroke(1.2)}/>')
    parts.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="2.4" ry="4.4" transform="rotate({angle} {x:.1f} {y:.1f})" '
                 f'fill="#f2cc55" {stroke(1.2)}/>')
    return "".join(parts)


def crop_wheat():
    body = []
    stalks = [(-14, 24, 30), (0, 32, 26), (14, 40, 30)]
    for ang, top_x, top_y in stalks:
        rad = math.radians(ang)
        bx, by = 32, 60
        tx, ty = top_x, top_y - 8
        body.append(f'<path d="M{bx} {by} L{tx} {ty + 18}" stroke="#9c7a2a" stroke-width="2.4" fill="none" stroke-linecap="round"/>')
    body.append(wheat_head(24, 12, -14))
    body.append(wheat_head(32, 8, 0))
    body.append(wheat_head(40, 12, 14))
    body.append(f'<path d="M26 50 Q32 46 38 50 L37 54 Q32 51 27 54 Z" fill="#c9a34a" {stroke(1.4)}/>')
    return "".join(body)


def crop_carrot():
    return (
        f'<path d="M29 18 C27 10 22 6 16 5 C20 10 23 15 26 20 Z" fill="#5da83a" {stroke(1.6)}/>'
        f'<path d="M33 18 C33 9 36 4 41 2 C39 8 37 14 36 20 Z" fill="#6cbc45" {stroke(1.6)}/>'
        f'<path d="M36 20 C40 13 46 10 52 10 C47 14 43 18 39 22 Z" fill="#5da83a" {stroke(1.6)}/>'
        f'<path d="M20 24 C25 17 40 16 45 23 C43 36 36 50 30 60 C28 62 26 61 26 59 C23 46 20 34 20 24 Z" fill="#f28c28" {stroke()}/>'
        '<path d="M38 22 C42 24 42 30 40 36 C37 45 33 53 30 58 C33 48 37 36 38 22 Z" fill="#d0661a"/>'
        '<path d="M24 26 C26 22 30 21 33 22 C29 24 26 27 25 31 Z" fill="#ffb366"/>'
        f'<path d="M24 32 L30 33 M27 42 L33 42 M26 51 L31 50 M36 28 L40 29" stroke="#b5561a" stroke-width="1.6" stroke-linecap="round"/>'
    )


def crop_potato():
    return (
        f'<ellipse cx="32" cy="34" rx="22" ry="16" transform="rotate(-18 32 34)" fill="#c89a5b" {stroke()}/>'
        '<path d="M50 30 C52 40 44 49 32 51 C22 53 14 48 12 42 C22 47 40 45 50 30 Z" fill="#a87a3e"/>'
        '<ellipse cx="24" cy="28" rx="8" ry="4.5" transform="rotate(-25 24 28)" fill="#e2bf85"/>'
        '<ellipse cx="38" cy="30" rx="1.8" ry="1.3" fill="#7a5328"/>'
        '<ellipse cx="28" cy="40" rx="1.8" ry="1.3" fill="#7a5328"/>'
        '<ellipse cx="44" cy="38" rx="1.5" ry="1.1" fill="#7a5328"/>'
        '<ellipse cx="20" cy="36" rx="1.4" ry="1.0" fill="#7a5328"/>'
    )


def crop_tomato():
    return (
        f'<circle cx="32" cy="37" r="21" fill="#e8412f" {stroke()}/>'
        '<path d="M50 30 C54 44 44 57 30 57 C22 57 15 52 13 45 C22 54 44 52 50 30 Z" fill="#c02c1f"/>'
        '<ellipse cx="23" cy="28" rx="7" ry="4" transform="rotate(-30 23 28)" fill="#ff8a73"/>'
        f'<path d="M32 20 L27 13 L30 19 L22 17 L29 22 L24 27 L32 23 L40 27 L35 22 L42 17 L34 19 L37 13 Z" fill="#4f9a2e" {stroke(1.4)}/>'
        f'<path d="M32 20 L33 9" stroke="#3f7a24" stroke-width="2.6" stroke-linecap="round"/>'
    )


def crop_corn():
    kernels = []
    for row in range(8):
        for col in range(3):
            x = 26 + col * 4.6 + (row % 2) * 1.2
            y = 14 + row * 5.2
            kernels.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="4" height="4.4" rx="1.6" fill="#f7d14a" stroke="#c99a1e" stroke-width="0.8"/>')
    return (
        '<g transform="rotate(22 32 34)">'
        f'<ellipse cx="32" cy="33" rx="10" ry="23" fill="#f2c230" {stroke()}/>'
        + "".join(kernels) +
        f'<path d="M22 30 C16 42 18 54 30 62 C26 50 25 40 27 30 Z" fill="#5da83a" {stroke(1.6)}/>'
        f'<path d="M42 30 C48 42 46 54 34 62 C38 50 39 40 37 30 Z" fill="#6cbc45" {stroke(1.6)}/>'
        '</g>'
    )


def crop_eggplant():
    return (
        f'<path d="M22 26 C14 36 16 54 28 58 C40 62 52 54 50 40 C48 30 40 26 36 20 C32 16 26 20 22 26 Z" fill="#6b3fa0" {stroke()}/>'
        '<path d="M48 38 C50 50 42 58 30 57 C40 55 46 48 48 38 Z" fill="#4e2a7a"/>'
        '<ellipse cx="25" cy="36" rx="4" ry="8" transform="rotate(20 25 36)" fill="#9a6fd0"/>'
        f'<path d="M24 22 C28 14 38 14 40 22 C36 20 34 24 32 26 C30 22 27 21 24 22 Z" fill="#4f8a2e" {stroke(1.6)}/>'
        f'<path d="M32 18 C33 12 36 8 40 6" stroke="#3f7a24" stroke-width="3" fill="none" stroke-linecap="round"/>'
    )


def crop_strawberry():
    seeds = []
    pts = [(24, 32), (32, 30), (40, 32), (22, 40), (30, 39), (38, 40), (44, 38), (27, 47), (35, 47), (31, 54)]
    for x, y in pts:
        seeds.append(f'<ellipse cx="{x}" cy="{y}" rx="1.1" ry="1.7" fill="#ffe27a"/>')
    return (
        f'<path d="M14 30 C14 22 24 20 32 24 C40 20 50 22 50 30 C50 42 40 54 32 60 C24 54 14 42 14 30 Z" fill="#e33b3b" {stroke()}/>'
        '<path d="M48 32 C47 44 39 53 32 58 C38 50 44 42 48 32 Z" fill="#b82424"/>'
        '<ellipse cx="22" cy="30" rx="4" ry="2.6" transform="rotate(-25 22 30)" fill="#ff8080"/>'
        + "".join(seeds) +
        f'<path d="M32 26 L24 20 L20 24 L22 18 L16 16 L26 16 L28 10 L32 16 L36 10 L38 16 L48 16 L42 18 L44 24 L40 20 Z" fill="#4f9a2e" {stroke(1.4)}/>'
    )


def crop_pumpkin():
    return (
        f'<ellipse cx="32" cy="38" rx="25" ry="19" fill="#f08a24" {stroke()}/>'
        f'<ellipse cx="32" cy="38" rx="14" ry="19" fill="#f59a33" {stroke(1.4)}/>'
        f'<ellipse cx="32" cy="38" rx="5" ry="19" fill="#ffae4a" {stroke(1.2)}/>'
        '<path d="M52 34 C56 46 46 56 32 57 C44 54 50 46 52 34 Z" fill="#c8661a" opacity="0.8"/>'
        f'<path d="M30 20 C29 14 31 9 36 6 L38 9 C35 11 34 15 35 20 Z" fill="#6b4a2a" {stroke(1.5)}/>'
        f'<path d="M36 12 C42 8 48 10 50 14 C45 14 41 14 37 16 Z" fill="#4f9a2e" {stroke(1.3)}/>'
    )


CROPS = {
    "wheat": crop_wheat,
    "carrot": crop_carrot,
    "potato": crop_potato,
    "tomato": crop_tomato,
    "corn": crop_corn,
    "eggplant": crop_eggplant,
    "strawberry": crop_strawberry,
    "pumpkin": crop_pumpkin,
}

PACKET_COLORS = {
    "wheat": "#d9a93a", "carrot": "#e8812a", "potato": "#9a7040", "tomato": "#d8402f",
    "corn": "#e0b52a", "eggplant": "#7a4fb0", "strawberry": "#d8354a", "pumpkin": "#e87b22",
}


def seed_packet(crop):
    band = PACKET_COLORS[crop]
    return (
        f'<path d="M14 12 L50 12 L50 58 L14 58 Z" fill="#ecdcb4" {stroke()}/>'
        f'<path d="M14 12 L50 12 L50 20 L14 20 Z" fill="#d9c08a" {stroke(1.6)}/>'
        '<path d="M16 16 L48 16" stroke="#b89a60" stroke-width="1" stroke-dasharray="2 2"/>'
        f'<rect x="17" y="24" width="30" height="27" rx="3" fill="#fff8e4" stroke="{band}" stroke-width="2.4"/>'
        f'<g transform="translate(18.5 24.5) scale(0.42)">{CROPS[crop]()}</g>'
        f'<path d="M14 52 L50 52 L50 58 L14 58 Z" fill="{band}" {stroke(1.6)}/>'
        '<circle cx="42" cy="44" r="1.3" fill="#8a6a3a"/><circle cx="45" cy="47" r="1.1" fill="#8a6a3a"/>'
    )


# --- Tools -----------------------------------------------------------------------

def handle(x1, y1, x2, y2, w=5.0):
    return (f'<path d="M{x1} {y1} L{x2} {y2}" stroke="{OL}" stroke-width="{w + 2.5}" stroke-linecap="round"/>'
            f'<path d="M{x1} {y1} L{x2} {y2}" stroke="#a8743f" stroke-width="{w}" stroke-linecap="round"/>'
            f'<path d="M{x1 + 0.8} {y1 - 1.2} L{x2 + 0.8} {y2 - 1.2}" stroke="#c9955c" stroke-width="1.4" stroke-linecap="round"/>')


def tool_hoe():
    return (
        handle(10, 58, 44, 14)
        + f'<path d="M40 11 L47 6 L50 10 L45 15 Z" fill="#6b737a" {stroke(1.6)}/>'
        + f'<path d="M46 8 L60 20 L57 30 L50 23 L44 14 Z" fill="#aab4bc" {stroke()}/>'
        + '<path d="M56 22 L57 28 L51 22 Z" fill="#7d878f"/>'
    )


def tool_watering_can():
    return (
        f'<path d="M40 30 L58 16 L61 19 L45 36 Z" fill="#8fa3ae" {stroke()}/>'
        f'<ellipse cx="59" cy="16.5" rx="3" ry="4.5" transform="rotate(40 59 16.5)" fill="#b8c9d2" {stroke(1.6)}/>'
        f'<path d="M12 28 C12 24 16 22 20 22 L38 22 C42 22 45 24 45 28 L44 52 C44 56 41 58 37 58 L20 58 C16 58 13 56 13 52 Z" fill="#9fb3bf" {stroke()}/>'
        '<path d="M38 24 C41 24 43 26 43 29 L42 52 C42 55 40 56 37 56 L33 56 C38 52 39 38 38 24 Z" fill="#7d919c"/>'
        '<path d="M16 26 L20 26 L19 52 L16 52 Z" fill="#c9d8e0"/>'
        f'<path d="M18 22 C18 10 38 10 38 22" fill="none" stroke="{OL}" stroke-width="6" stroke-linecap="round"/>'
        '<path d="M18 22 C18 10 38 10 38 22" fill="none" stroke="#8fa3ae" stroke-width="3.2" stroke-linecap="round"/>'
        f'<rect x="12" y="34" width="33" height="4" fill="#7d919c" {stroke(1.2)}/>'
    )


def tool_scythe():
    return (
        f'<path d="M14 60 C20 44 28 26 36 12" stroke="{OL}" stroke-width="7.5" fill="none" stroke-linecap="round"/>'
        '<path d="M14 60 C20 44 28 26 36 12" stroke="#a8743f" stroke-width="5" fill="none" stroke-linecap="round"/>'
        f'<path d="M22 36 L30 38" stroke="{OL}" stroke-width="6" stroke-linecap="round"/>'
        '<path d="M22 36 L30 38" stroke="#8a5a30" stroke-width="3.4" stroke-linecap="round"/>'
        f'<path d="M34 10 C44 4 56 6 62 16 C54 12 46 12 38 16 Z" fill="#c3ccd3" {stroke()}/>'
        '<path d="M40 13 C48 10 55 11 60 15 C53 13 46 13 41 15 Z" fill="#eef3f6"/>'
    )


def tool_pickaxe():
    return (
        handle(12, 58, 40, 20)
        + f'<path d="M12 22 C22 10 42 4 58 10 C44 10 34 14 26 22 L40 26 C48 20 54 16 60 16 C52 10 30 10 12 22 Z" fill="#9aa3ab" {stroke()}/>'
        + f'<path d="M34 12 L44 18 L40 24 L30 18 Z" fill="#6b737a" {stroke(1.6)}/>'
        + '<path d="M16 20 C24 13 36 9 48 9 C38 11 28 15 20 21 Z" fill="#c7cfd5"/>'
    )


def tool_axe():
    return (
        handle(14, 58, 42, 12)
        + f'<path d="M36 8 L44 12 L40 20 L32 16 Z" fill="#6b737a" {stroke(1.6)}/>'
        + f'<path d="M42 10 C48 6 56 6 60 10 C60 20 56 28 50 30 L40 20 Z" fill="#aab4bc" {stroke()}/>'
        + '<path d="M54 10 C58 12 58 20 54 26 C56 20 56 14 54 10 Z" fill="#e3e9ed"/>'
    )


def tool_milk_pail():
    return (
        f'<path d="M14 24 C14 8 50 8 50 24" fill="none" stroke="{OL}" stroke-width="5"/>'
        '<path d="M14 24 C14 8 50 8 50 24" fill="none" stroke="#8e9aa3" stroke-width="2.6"/>'
        f'<path d="M12 24 L52 24 L47 58 L17 58 Z" fill="#aab6bf" {stroke()}/>'
        f'<ellipse cx="32" cy="24" rx="20" ry="5" fill="#f5f5f0" {stroke(1.8)}/>'
        '<path d="M44 28 L49 28 L45 56 L41 56 Z" fill="#8a969f"/>'
        f'<path d="M14 36 L50 36 M16 48 L48 48" stroke="#7d8a94" stroke-width="2.4"/>'
    )


def tool_shears():
    return (
        f'<path d="M30 30 L56 6 L58 9 L36 34 Z" fill="#c3ccd3" {stroke()}/>'
        f'<path d="M34 30 L8 6 L6 9 L28 34 Z" fill="#aab4bc" {stroke()}/>'
        f'<circle cx="32" cy="32" r="2.6" fill="#6b737a" {stroke(1.4)}/>'
        f'<ellipse cx="22" cy="48" rx="8" ry="10" fill="none" stroke="{OL}" stroke-width="6"/>'
        '<ellipse cx="22" cy="48" rx="8" ry="10" fill="none" stroke="#d8453a" stroke-width="3.4"/>'
        f'<ellipse cx="42" cy="48" rx="8" ry="10" fill="none" stroke="{OL}" stroke-width="6"/>'
        '<ellipse cx="42" cy="48" rx="8" ry="10" fill="none" stroke="#d8453a" stroke-width="3.4"/>'
    )


def tool_brush():
    bristles = "".join(f'<path d="M{18 + i * 4} 40 L{17 + i * 4} 54" stroke="#f0e2c0" stroke-width="2.4" stroke-linecap="round"/>' for i in range(8))
    return (
        f'<rect x="14" y="40" width="36" height="16" rx="3" fill="#d9c69a" {stroke()}/>' + bristles +
        f'<path d="M12 28 C12 22 16 20 22 20 L42 20 C48 20 52 22 52 28 L52 38 C52 41 50 42 47 42 L17 42 C14 42 12 41 12 38 Z" fill="#a8743f" {stroke()}/>'
        '<path d="M16 24 L46 24" stroke="#c9955c" stroke-width="2" stroke-linecap="round"/>'
        f'<path d="M18 30 L46 30 M18 35 L46 35" stroke="#8a5a30" stroke-width="1.4"/>'
    )


def tool_pitchfork():
    return (
        handle(14, 60, 34, 24, 4.5)
        + f'<path d="M26 30 C24 22 32 14 42 16 L46 20 C38 18 32 22 34 30 Z" fill="#9aa3ab" {stroke(1.6)}/>'
        + f'<path d="M36 18 L48 4 M40 21 L55 9 M43 25 L60 16" stroke="{OL}" stroke-width="4.2" stroke-linecap="round"/>'
        + '<path d="M36 18 L48 4 M40 21 L55 9 M43 25 L60 16" stroke="#c3ccd3" stroke-width="2.2" stroke-linecap="round"/>'
    )


# --- Resources -------------------------------------------------------------------

def log(cx, cy, r, length, angle=0):
    return (
        f'<g transform="rotate({angle} {cx} {cy})">'
        f'<rect x="{cx - length}" y="{cy - r}" width="{length}" height="{2 * r}" fill="#8a5a30" {stroke()}/>'
        f'<path d="M{cx - length + 3} {cy - r + 3} L{cx - 3} {cy - r + 3}" stroke="#6b4422" stroke-width="1.6"/>'
        f'<path d="M{cx - length + 6} {cy + 2} L{cx - 6} {cy + 2}" stroke="#6b4422" stroke-width="1.4"/>'
        f'<ellipse cx="{cx}" cy="{cy}" rx="{r * 0.55}" ry="{r}" fill="#e2b97a" {stroke()}/>'
        f'<ellipse cx="{cx}" cy="{cy}" rx="{r * 0.33}" ry="{r * 0.6}" fill="none" stroke="#b58a4c" stroke-width="1.2"/>'
        f'<ellipse cx="{cx}" cy="{cy}" rx="{r * 0.12}" ry="{r * 0.22}" fill="#b58a4c"/>'
        '</g>'
    )


def res_wood():
    return log(50, 46, 9, 40) + log(46, 28, 9, 36) + log(58, 30, 7, 8)


def res_stone():
    return (
        f'<path d="M8 50 L14 34 L26 28 L36 36 L34 52 L20 56 Z" fill="#8d8984" {stroke()}/>'
        '<path d="M14 34 L26 28 L24 38 L12 42 Z" fill="#b3aea8"/>'
        f'<path d="M28 44 L36 26 L50 22 L58 34 L56 50 L40 54 Z" fill="#9c9791" {stroke()}/>'
        '<path d="M36 26 L50 22 L48 32 L34 36 Z" fill="#c4bfb8"/>'
        '<path d="M56 50 L40 54 L42 46 L56 42 Z" fill="#78736d"/>'
    )


def res_iron_ore():
    return (
        f'<path d="M8 46 L16 24 L34 14 L52 20 L58 40 L46 56 L20 58 Z" fill="#5f5c5a" {stroke()}/>'
        '<path d="M16 24 L34 14 L32 26 L14 34 Z" fill="#7d7a77"/>'
        f'<path d="M26 30 L32 26 L36 32 L30 36 Z" fill="#c8793a" {stroke(1.2)}/>'
        f'<path d="M40 38 L46 34 L50 40 L44 44 Z" fill="#d18a4a" {stroke(1.2)}/>'
        f'<path d="M20 44 L25 41 L28 46 L22 49 Z" fill="#dfe4e8" {stroke(1.2)}/>'
        f'<path d="M40 22 L44 20 L46 25 L42 27 Z" fill="#dfe4e8" {stroke(1.2)}/>'
    )


def res_hay():
    lines = "".join(f'<path d="M{12 + i * 5} 22 L{11 + i * 5} 50" stroke="#c9a23a" stroke-width="1.4"/>' for i in range(8))
    return (
        f'<rect x="8" y="18" width="48" height="36" rx="6" fill="#ecc85a" {stroke()}/>' + lines +
        '<path d="M10 22 L54 22" stroke="#fbe38a" stroke-width="2"/>'
        f'<path d="M22 18 L22 54 M42 18 L42 54" stroke="#9a4a2a" stroke-width="3"/>'
        f'<path d="M8 16 L4 12 M12 16 L10 10 M50 16 L54 11 M56 20 L60 17" stroke="#d9b24a" stroke-width="1.8" stroke-linecap="round"/>'
    )


ICONS = {
    "hoe": tool_hoe, "watering_can": tool_watering_can, "scythe": tool_scythe,
    "pickaxe": tool_pickaxe, "axe": tool_axe, "milk_pail": tool_milk_pail,
    "shears": tool_shears, "brush": tool_brush, "pitchfork": tool_pitchfork,
    "wood": res_wood, "stone": res_stone, "iron_ore": res_iron_ore, "hay": res_hay,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    count = 0
    for name, fn in ICONS.items():
        with open(os.path.join(OUT, f"{name}.svg"), "w") as f:
            f.write(svg(fn()))
        count += 1
    for crop, fn in CROPS.items():
        with open(os.path.join(OUT, f"{crop}.svg"), "w") as f:
            f.write(svg(fn()))
        with open(os.path.join(OUT, f"{crop}_seed.svg"), "w") as f:
            f.write(svg(seed_packet(crop)))
        count += 2
    print(f"wrote {count} icons to {os.path.normpath(OUT)}")


if __name__ == "__main__":
    main()
