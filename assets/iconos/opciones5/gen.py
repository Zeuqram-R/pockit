"""Ronda 5: pasaporte con flamenco, tablas cruzadas (la de adelante enterrada) y 3 llaveros nuevos."""
import math, json, sys, re
sys.path.insert(0, '../v4')
import importlib.util
spec = importlib.util.spec_from_file_location('fcmod', '../v4/fc.py')
# Cargamos solo las funciones (sin escribir los archivos de la v4)
src = open('../v4/fc.py').read().split('I = {}')[0]
ns = {}; exec(src, ns)
DEFS, O, P, L, HL, R, Ci, E, star, spark, shadow, dollar = (ns[k] for k in ['DEFS', 'O', 'P', 'L', 'HL', 'R', 'Ci', 'E', 'star', 'spark', 'shadow', 'dollar'])
EXTRA = '''<defs>
<linearGradient id="board2" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#7FEBDD"/><stop offset="1" stop-color="#1FA597"/></linearGradient>
<linearGradient id="board3" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#FF8DBD"/><stop offset="1" stop-color="#D51E68"/></linearGradient>
<linearGradient id="sand" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFE3A8"/><stop offset="1" stop-color="#E8B865"/></linearGradient>
<linearGradient id="metal" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".5" stop-color="#C9C1DC"/><stop offset="1" stop-color="#8A80A6"/></linearGradient>
<linearGradient id="brass" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFE7A0"/><stop offset=".55" stop-color="#E9B44C"/><stop offset="1" stop-color="#A8701E"/></linearGradient>
<linearGradient id="tag" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#5FE0D3"/><stop offset="1" stop-color="#138A80"/></linearGradient>
<linearGradient id="black" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#4A3A6A"/><stop offset="1" stop-color="#140A24"/></linearGradient>
</defs>'''
def svg(body): return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">{DEFS}{EXTRA}{body}</svg>'

def flamingo(cx, cy, s, fill, line=O, lw=5):
    # Flamenco original parado en una pata, mirando a la izquierda
    g = f'<g transform="translate({cx} {cy}) scale({s})">'
    g += f'<path d="M6 30 L6 74 M10 30 L24 50 L8 56" fill="none" stroke="{line}" stroke-width="{lw}" stroke-linecap="round" stroke-linejoin="round"/>'
    g += f'<path d="M-30 14 C-34 -6 -6 -14 22 -2 C40 6 44 22 30 30 C10 40 -24 36 -30 14 Z" fill="{fill}" stroke="{line}" stroke-width="{lw}" stroke-linejoin="round"/>'
    g += f'<path d="M-24 10 C-46 -6 -20 -26 -26 -50 C-30 -66 -12 -76 -2 -66" fill="none" stroke="{line}" stroke-width="{lw+10}" stroke-linecap="round"/>'
    g += f'<path d="M-24 10 C-46 -6 -20 -26 -26 -50 C-30 -66 -12 -76 -2 -66" fill="none" stroke="{fill}" stroke-width="10" stroke-linecap="round"/>'
    g += f'<circle cx="-4" cy="-66" r="9" fill="{fill}" stroke="{line}" stroke-width="{lw}"/>'
    g += f'<path d="M4 -70 L18 -64 L14 -52 L6 -58 Z" fill="{line}"/>'
    g += f'<path d="M-6 6 C4 0 16 4 22 12" fill="none" stroke="{line}" stroke-width="{max(2, lw-1)}" stroke-linecap="round" opacity=".5"/>'
    return g + '</g>'

I = {}
# ---------- Pasaporte con flamenco ----------
I['pasaporte_flamenco'] = ('Pasaporte', svg(
    shadow(250, 456, 170) +
    '<g transform="rotate(-8 240 260)">' +
    R(112, 70, 250, 350, 'url(#teal)', 22) + R(112, 70, 40, 350, 'url(#tealD)', 0, 0, 'opacity=".9"') + R(112, 70, 250, 350, 'none', 22) +
    Ci(250, 196, 68, 'url(#gold)', 10) + Ci(250, 196, 54, 'none', 4, 'opacity=".35"') +
    flamingo(252, 200, .82, 'url(#pink)') +
    R(176, 296, 148, 18, '#FFE08A', 9, 6) + R(196, 330, 108, 14, '#FFE08A', 7, 5, 'opacity=".8"') +
    HL('M140 100 L140 390', 6, .35) + '</g>' +
    '<g transform="rotate(14 370 360)">' + Ci(372, 362, 66, 'url(#pink)', 10, 'opacity=".96"') + Ci(372, 362, 46, 'none', 6, 'stroke-dasharray="8 8"') +
    f'<path d="{star(372, 362, 26)}" fill="#FFF4E6" stroke="{O}" stroke-width="5" stroke-linejoin="round"/></g>' + spark(436, 96)))

# ---------- Tablas cruzadas, la de adelante enterrada ----------
BOARD = 'M0 -205 C46 -200 68 -112 68 0 C68 112 48 182 0 198 C-48 182 -68 112 -68 0 C-68 -112 -46 -200 0 -205 Z'
def board(tx, ty, rot, fill, stripes, cid, scale=1, stringer='#FFF4E6'):
    out = f'<g transform="translate({tx} {ty}) rotate({rot}) scale({scale})"><clipPath id="{cid}"><path d="{BOARD}"/></clipPath>'
    out += f'<path d="{BOARD}" fill="{fill}"/><g clip-path="url(#{cid})">'
    for (y, h, c) in stripes: out += f'<rect x="-80" y="{y}" width="160" height="{h}" fill="{c}"/>'
    out += '<path d="M48 -150 C62 -80 62 60 44 150" fill="none" stroke="#FFFFFF" stroke-width="12" stroke-linecap="round" opacity=".5"/>'
    out += '<path d="M-40 -170 C-58 -80 -60 80 -42 170" fill="none" stroke="#000" stroke-width="16" opacity=".12"/></g>'
    out += L('M0 -196 L0 190', stringer, 5, .9) + f'<path d="{star(0, 40, 22)}" fill="#FFE08A" stroke="{O}" stroke-width="5" stroke-linejoin="round"/>'
    return out + f'<path d="{BOARD}" fill="none" stroke="{O}" stroke-width="12" stroke-linejoin="round"/></g>'
SAND = 'M34 496 Q52 380 170 372 Q256 362 340 372 Q458 384 478 496 Z'
I['surf_cruzadas'] = ('Tablas cruzadas', svg(
    Ci(256, 196, 150, 'url(#sun)', 12) +
    f'<g opacity=".35">{L("M110 220 L402 220 M118 254 L394 254 M136 288 L376 288", "#FFF4E6", 10)}</g>' +
    board(196, 246, -26, 'url(#board2)', [(-128, 16, '#FFF4E6'), (-106, 16, '#FF3E8A')], 'cA', scale=.92) +
    board(318, 312, 26, 'url(#board3)', [(-128, 16, '#FFE08A'), (-106, 16, '#2EC4B6')], 'cB', scale=.92) +
    P(SAND, 'url(#sand)', 12) +
    L('M120 430 L142 426 M300 412 L322 414 M380 444 L400 440 M220 448 L238 446', '#C9913E', 7, .8) +
    P('M300 372 Q318 360 336 372', 'none', 7) + spark(446, 76)))

# ---------- Llaveros ----------
def ring(cx, cy, r, grad='url(#metal)'):
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{O}" stroke-width="28"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{grad}" stroke-width="14"/>'
            + HL(f'M{cx-r*.7:.0f} {cy-r*.7:.0f} A{r} {r} 0 0 1 {cx:.0f} {cy-r:.0f}', 5, .9))
def brass_key(cx, cy, rot, s=1, bow='round'):
    g = f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">'
    g += R(-11, 36, 22, 150, 'url(#brass)', 4, 9)
    g += P('M11 118 L32 118 L32 132 L22 132 L22 146 L34 146 L34 162 L11 162 Z', 'url(#brass)', 8)
    g += R(-18, 30, 36, 16, 'url(#brass)', 4, 8)
    if bow == 'round':
        g += Ci(0, -14, 48, 'url(#brass)', 11) + Ci(0, -14, 18, '#2B1E92', 8)
    return g + L('M-4 60 L-4 170', '#FFF4E6', 4, .5) + '</g>'

# 1) Llave de motel retro
I['llavero_motel'] = ('Llave de motel', svg(
    shadow(256, 466, 160) +
    ring(256, 92, 44) +
    '<g transform="rotate(-10 256 290)">' +
    P('M256 150 L392 290 L256 430 L120 290 Z', 'url(#tag)', 12) +
    P('M256 176 L366 290 L256 404 L146 290 Z', 'none', 6, 'stroke="#FFF4E6" stroke-dasharray="2 12" opacity=".8"') +
    Ci(256, 186, 14, '#2B1E92', 8) +
    '<text x="256" y="282" text-anchor="middle" font-family="DejaVu Sans" font-weight="bold" font-size="40" fill="#FFE08A" stroke="#140A24" stroke-width="2.5">VICE</text>' +
    '<text x="256" y="334" text-anchor="middle" font-family="DejaVu Sans" font-weight="bold" font-size="44" fill="#FFF4E6" stroke="#140A24" stroke-width="2.5">86</text>' +
    HL('M190 236 L246 180', 8, .5) + '</g>' +
    L('M282 112 L360 150', O, 10) + brass_key(396, 210, 28, .78) + spark(440, 82)))

# 2) Llavero de lujo: control de carro deportivo + flamenco de esmalte + medalla
def sport_fob(cx, cy, rot, s=1):
    g = f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">'
    g += P('M-46 -86 Q0 -110 46 -86 L58 60 Q0 100 -58 60 Z', 'url(#black)', 12)
    g += P('M-30 -70 Q0 -86 30 -70 L36 -10 Q0 4 -36 -10 Z', 'none', 5, 'stroke="#FFE08A" opacity=".8"')
    g += f'<path d="{star(0, -40, 16)}" fill="url(#pink)" stroke="{O}" stroke-width="4" stroke-linejoin="round"/>'
    g += Ci(-20, 26, 11, '#2EC4B6', 5) + Ci(20, 26, 11, '#FF3E8A', 5) + R(-14, 48, 28, 10, '#FFE08A', 5, 4)
    return g + HL('M-34 -60 L-38 40', 6, .35) + '</g>'
I['llavero_lujo'] = ('Llavero de lujo', svg(
    shadow(256, 466, 180) +
    ring(256, 92, 48, 'url(#brass)') +
    L('M222 132 L172 214', O, 10) + L('M256 140 L260 208', O, 10) + L('M292 132 L348 214', O, 10) +
    Ci(160, 306, 92, 'url(#gold)', 12) + Ci(160, 306, 72, 'none', 5, 'opacity=".35"') + flamingo(164, 312, 1.05, 'url(#pink)', O, 6) +
    sport_fob(262, 318, 0, 1.0) +
    Ci(370, 290, 60, 'url(#sun)', 11) + L('M322 280 L418 280 M326 302 L414 302', '#FFF4E6', 7, .9) + Ci(370, 290, 60, 'none', 11) +
    spark(446, 92)))

# 3) Llaves del imperio: cabezas con forma de casa, carro y lancha
def car_head():
    return (P('M-62 24 L-62 -4 Q-58 -22 -40 -26 L-28 -50 Q-24 -58 -12 -58 L16 -58 Q28 -58 32 -50 L44 -26 Q60 -22 62 -4 L62 24 Z', 'url(#teal)', 11) +
            P('M-22 -46 L18 -46 L30 -26 L-34 -26 Z', 'url(#sky)', 6) + Ci(-36, 26, 14, O, 0) + Ci(36, 26, 14, O, 0) + Ci(-36, 26, 6, '#C9C1DC', 0) + Ci(36, 26, 6, '#C9C1DC', 0))
def boat_head():
    return (P('M-64 4 L64 4 L44 36 L-48 36 Z', '#FFFFFF', 11) + P('M-34 4 L-20 -30 L30 -30 L40 4 Z', 'url(#sun)', 10) + P('M-10 -30 L-2 -54 L18 -30 Z', '#FFFFFF', 8) +
            L('M-50 22 L48 22', '#E02470', 7))
def house_head():
    return (P('M0 -92 L-58 -40 L-46 -40 L-46 34 L46 34 L46 -40 L58 -40 Z', 'url(#pink)', 11) + R(-12, -2, 24, 36, O, 3, 0) +
            R(-32, -26, 18, 16, '#FFF4E6', 2, 4) + R(14, -26, 18, 16, '#FFF4E6', 2, 4))
def ikey(cx, cy, rot, headsvg, s=1):
    return (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">' + R(-11, 30, 22, 150, 'url(#brass)', 4, 9) +
            P('M11 112 L32 112 L32 126 L22 126 L22 140 L34 140 L34 156 L11 156 Z', 'url(#brass)', 8) + headsvg + '</g>')
I['llavero_imperio'] = ('Llaves del imperio', svg(
    shadow(256, 470, 150) +
    ikey(150, 268, -30, boat_head(), .95) + ikey(362, 268, 30, car_head(), .95) + ikey(256, 262, 0, house_head(), 1.0) +
    ring(256, 98, 52, 'url(#brass)') + R(222, 140, 68, 30, 'url(#gold)', 10, 10) +
    f'<path d="{star(256, 155, 10)}" fill="{O}"/>' + spark(440, 92)))

# ================= Estilo juego =================
C = 'COLOR'
def glyphL(layers):
    defs = ''; g = ''
    for i, (body, cut) in enumerate(layers):
        if cut:
            defs += f'<mask id="m{i}"><rect width="512" height="512" fill="#fff"/>{cut}</mask>'
            g += f'<g mask="url(#m{i})">{body}</g>'
        else:
            g += body
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512"><defs>{defs}</defs>{g}</svg>'
def Rc(x, y, w, h, rx=0, fill=C, extra=''): return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" {extra}/>'
def Cc(cx, cy, r, fill=C): return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"/>'
def flamingo_g(cx, cy, s, fill=C):
    g = f'<g transform="translate({cx} {cy}) scale({s})">'
    g += f'<path d="M6 30 L6 74 M10 30 L24 50 L8 56" fill="none" stroke="{fill}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>'
    g += f'<path d="M-30 14 C-34 -6 -6 -14 22 -2 C40 6 44 22 30 30 C10 40 -24 36 -30 14 Z" fill="{fill}"/>'
    g += f'<path d="M-24 10 C-46 -6 -20 -26 -26 -50 C-30 -66 -12 -76 -2 -66" fill="none" stroke="{fill}" stroke-width="12" stroke-linecap="round"/>'
    g += f'<circle cx="-4" cy="-66" r="10" fill="{fill}"/><path d="M4 -72 L20 -64 L14 -50 L4 -58 Z" fill="{fill}"/>'
    return g + '</g>'
G = {}
G['pasaporte_flamenco'] = ('Pasaporte', glyphL([
    ('<g transform="rotate(-8 230 256)">' + Rc(104, 60, 254, 360, 24) + '</g>',
     '<g transform="rotate(-8 230 256)">' + Rc(140, 60, 10, 360, 0, '#000') + Cc(250, 196, 66, '#000') + Rc(176, 294, 150, 20, 10, '#000') + Rc(196, 330, 110, 16, 8, '#000') + '</g>' + Cc(380, 372, 92, '#000')),
    ('<g transform="rotate(-8 230 256)">' + flamingo_g(252, 200, .78) + '</g>' + Cc(380, 372, 76),
     f'<circle cx="380" cy="372" r="54" fill="none" stroke="#000" stroke-width="9" stroke-dasharray="10 9"/><path d="{star(380, 376, 30)}" fill="#000"/>')]))
def gb(tx, ty, rot, s): return f'<g transform="translate({tx} {ty}) rotate({rot}) scale({s})">'
def board_body(tx, ty, rot, s): return gb(tx, ty, rot, s) + f'<path d="{BOARD}" fill="{C}"/></g>'
def board_cut(tx, ty, rot, s):
    return (gb(tx, ty, rot, s) + f'<clipPath id="g{tx}"><path d="{BOARD}"/></clipPath><g clip-path="url(#g{tx})">' +
            '<rect x="-80" y="-126" width="160" height="12" fill="#000"/><rect x="-80" y="-98" width="160" height="12" fill="#000"/></g>' +
            f'<path d="M0 -60 L0 170" stroke="#000" stroke-width="9" stroke-linecap="round"/><path d="{star(0, 40, 26)}" fill="#000"/></g>')
def board_gap(tx, ty, rot, s): return gb(tx, ty, rot, s) + f'<path d="{BOARD}" fill="#000" stroke="#000" stroke-width="30" stroke-linejoin="round"/></g>'
G['surf_cruzadas'] = ('Tablas cruzadas', glyphL([
    (Cc(256, 196, 152), '<path d="M100 220 L412 220 M104 254 L408 254 M116 288 L396 288" stroke="#000" stroke-width="12"/>' + board_gap(196, 246, -26, .92) + board_gap(318, 312, 26, .92) +
     f'<path d="{SAND}" fill="#000" stroke="#000" stroke-width="28" stroke-linejoin="round"/>'),
    (board_body(196, 246, -26, .92), board_cut(196, 246, -26, .92) + board_gap(318, 312, 26, .92) + f'<path d="{SAND}" fill="#000" stroke="#000" stroke-width="28" stroke-linejoin="round"/>'),
    (board_body(318, 312, 26, .92), board_cut(318, 312, 26, .92) + f'<path d="{SAND}" fill="#000" stroke="#000" stroke-width="28" stroke-linejoin="round"/>'),
    (f'<path d="{SAND}" fill="{C}"/>', '<path d="M120 430 L142 426 M300 412 L322 414 M380 444 L400 440" stroke="#000" stroke-width="9" stroke-linecap="round"/>')]))
def g_ring(cx, cy, r, w=24): return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{C}" stroke-width="{w}"/>'
def g_key(cx, cy, rot, s=1):
    return (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">' + Rc(-12, 30, 24, 152, 4) + Rc(-20, 28, 40, 18, 4) +
            f'<path d="M12 118 L34 118 L34 132 L24 132 L24 146 L36 146 L36 162 L12 162 Z" fill="{C}"/>' + Cc(0, -14, 50) + '</g>')
G['llavero_motel'] = ('Llave de motel', glyphL([
    (g_ring(256, 92, 44) + f'<path d="M256 136 L250 172 M282 112 L360 150" stroke="{C}" stroke-width="10" stroke-linecap="round"/>' + g_key(396, 210, 28, .78),
     f'<g transform="translate(396 210) rotate(28) scale(.78)">{Cc(0, -14, 18, "#000")}</g>' + '<g transform="rotate(-10 256 290)"><path d="M256 132 L410 290 L256 448 L102 290 Z" fill="#000"/></g>'),
    ('<g transform="rotate(-10 256 290)"><path d="M256 150 L392 290 L256 430 L120 290 Z" fill="COLOR"/></g>',
     '<g transform="rotate(-10 256 290)"><circle cx="256" cy="186" r="15" fill="#000"/><path d="M256 182 L362 290 L256 398 L150 290 Z" fill="none" stroke="#000" stroke-width="7" stroke-dasharray="3 12" stroke-linecap="round"/>' +
     '<text x="256" y="282" text-anchor="middle" font-family="DejaVu Sans" font-weight="bold" font-size="40" fill="#000">VICE</text>' +
     '<text x="256" y="336" text-anchor="middle" font-family="DejaVu Sans" font-weight="bold" font-size="46" fill="#000">86</text></g>')]))
def g_fob(cx, cy, rot, s=1):
    body = f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})"><path d="M-46 -86 Q0 -110 46 -86 L58 60 Q0 100 -58 60 Z" fill="{C}"/></g>'
    cut = (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})"><path d="M-30 -70 Q0 -86 30 -70 L36 -10 Q0 4 -36 -10 Z" fill="none" stroke="#000" stroke-width="6"/>' +
           f'<path d="{star(0, -40, 17)}" fill="#000"/><circle cx="-20" cy="26" r="12" fill="#000"/><circle cx="20" cy="26" r="12" fill="#000"/><rect x="-15" y="48" width="30" height="10" rx="5" fill="#000"/></g>')
    return body, cut
fb = g_fob(262, 318, 0)
G['llavero_lujo'] = ('Llavero de lujo', glyphL([
    (g_ring(256, 92, 48) + f'<path d="M222 132 L172 214 M256 140 L260 208 M292 132 L348 214" stroke="{C}" stroke-width="10" stroke-linecap="round"/>' + Cc(160, 306, 92),
     Cc(160, 306, 76, '#000') + '<g transform="translate(262 318)"><path d="M-46 -86 Q0 -110 46 -86 L58 60 Q0 100 -58 60 Z" fill="#000" stroke="#000" stroke-width="26" stroke-linejoin="round"/></g>'),
    (flamingo_g(164, 312, 1.0), ''),
    (fb[0] + Cc(370, 290, 60), fb[1] + '<path d="M322 280 L418 280 M326 302 L414 302" stroke="#000" stroke-width="9"/>')]))
def g_ikey(cx, cy, rot, head, s=1):
    g = f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">' + Rc(-12, 30, 24, 150, 4) + f'<path d="M12 112 L34 112 L34 126 L24 126 L24 140 L36 140 L36 156 L12 156 Z" fill="{C}"/>'
    if head == 'house': g += f'<path d="M0 -94 L-60 -40 L-48 -40 L-48 36 L48 36 L48 -40 L60 -40 Z" fill="{C}"/>'
    if head == 'car': g += f'<path d="M-64 26 L-64 -4 Q-60 -24 -40 -28 L-28 -52 Q-24 -60 -12 -60 L16 -60 Q28 -60 32 -52 L44 -28 Q62 -24 64 -4 L64 26 Z" fill="{C}"/>'
    if head == 'boat': g += f'<path d="M-66 2 L66 2 L46 38 L-50 38 Z" fill="{C}"/><path d="M-36 2 L-22 -32 L32 -32 L42 2 Z" fill="{C}"/><path d="M-10 -32 L-2 -58 L20 -32 Z" fill="{C}"/>'
    return g + '</g>'
def g_ikey_cut(cx, cy, rot, head, s=1):
    g = f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">'
    if head == 'house': g += '<rect x="-13" y="-2" width="26" height="38" rx="3" fill="#000"/><rect x="-34" y="-28" width="20" height="18" rx="2" fill="#000"/><rect x="14" y="-28" width="20" height="18" rx="2" fill="#000"/>'
    if head == 'car': g += '<path d="M-22 -48 L18 -48 L30 -28 L-34 -28 Z" fill="#000"/><circle cx="-38" cy="8" r="9" fill="#000"/><circle cx="38" cy="8" r="9" fill="#000"/>'
    if head == 'boat': g += '<path d="M-52 20 L50 20" stroke="#000" stroke-width="8"/><path d="M-22 -10 L24 -10" stroke="#000" stroke-width="7"/>'
    return g + '</g>'
def g_ikey_gap(cx, cy, rot, head, s=1):
    return g_ikey(cx, cy, rot, head, s).replace(f'fill="{C}"', 'fill="#000" stroke="#000" stroke-width="22" stroke-linejoin="round"')
G['llavero_imperio'] = ('Llaves del imperio', glyphL([
    (g_ikey(150, 268, -30, 'boat', .95), g_ikey_cut(150, 268, -30, 'boat', .95) + g_ikey_gap(256, 262, 0, 'house')),
    (g_ikey(362, 268, 30, 'car', .95), g_ikey_cut(362, 268, 30, 'car', .95) + g_ikey_gap(256, 262, 0, 'house')),
    (g_ikey(256, 262, 0, 'house'), g_ikey_cut(256, 262, 0, 'house')),
    (g_ring(256, 98, 52) + Rc(222, 140, 68, 30, 10), f'<path d="{star(256, 155, 11)}" fill="#000"/>')]))

for k, (n, s) in I.items(): open(f'fc_{k}.svg', 'w').write(s)
for k, (n, s) in G.items():
    open(f'gm_{k}_d.svg', 'w').write(s.replace('COLOR', '#1E1238'))
    open(f'gm_{k}_w.svg', 'w').write(s.replace('COLOR', '#FFFFFF'))
json.dump({k: v[0] for k, v in I.items()}, open('names.json', 'w'), ensure_ascii=False)
print(len(I), len(G))
