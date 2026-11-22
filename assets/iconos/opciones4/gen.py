"""Ronda 4: tabla de surf (3 opciones) y llavero (3 opciones), a color y estilo juego."""
import math, json, sys
sys.path.insert(0, '../v4')
from fc import DEFS, O, P, L, HL, R, Ci, E, star, spark, shadow, dollar
EXTRA = '''<defs>
<linearGradient id="board1" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#FFF8EE"/><stop offset="1" stop-color="#E9D6C2"/></linearGradient>
<linearGradient id="board2" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#7FEBDD"/><stop offset="1" stop-color="#1FA597"/></linearGradient>
<linearGradient id="board3" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#FF8DBD"/><stop offset="1" stop-color="#D51E68"/></linearGradient>
<linearGradient id="sand" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFE3A8"/><stop offset="1" stop-color="#E8B865"/></linearGradient>
<linearGradient id="metal" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".5" stop-color="#C9C1DC"/><stop offset="1" stop-color="#8A80A6"/></linearGradient>
<linearGradient id="leather" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#9A4FB8"/><stop offset="1" stop-color="#4A1A62"/></linearGradient>
<linearGradient id="float" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFB36B"/><stop offset="1" stop-color="#FF6A3D"/></linearGradient>
</defs>'''
def svg(body): return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">{DEFS}{EXTRA}{body}</svg>'

BOARD = 'M0 -205 C46 -200 68 -112 68 0 C68 112 48 182 0 198 C-48 182 -68 112 -68 0 C-68 -112 -46 -200 0 -205 Z'
def board(tx, ty, rot, fill, stripes, cid, scale=1, fin=True, stringer='#E02470', logo=True):
    clip = f'<clipPath id="{cid}"><path d="{BOARD}"/></clipPath>'
    out = f'<g transform="translate({tx} {ty}) rotate({rot}) scale({scale})">{clip}'
    if fin: out += P('M20 120 L58 132 L30 176 Z', 'url(#purpD)', 9)
    out += f'<path d="{BOARD}" fill="{fill}"/>'
    out += f'<g clip-path="url(#{cid})">'
    for (y, h, c) in stripes:
        out += f'<rect x="-80" y="{y}" width="160" height="{h}" fill="{c}"/>'
    out += f'<path d="M48 -150 C62 -80 62 60 44 150" fill="none" stroke="#FFFFFF" stroke-width="12" stroke-linecap="round" opacity=".5"/>'
    out += f'<path d="M-40 -170 C-58 -80 -60 80 -42 170" fill="none" stroke="#000" stroke-width="16" opacity=".12"/></g>'
    out += L('M0 -196 L0 190', stringer, 5, .9)
    if logo: out += f'<path d="{star(0, 70, 22)}" fill="#FFE08A" stroke="{O}" stroke-width="5" stroke-linejoin="round"/>'
    out += f'<path d="{BOARD}" fill="none" stroke="{O}" stroke-width="12" stroke-linejoin="round"/></g>'
    return out
SUNSET = [(-120, 22, '#FFC56B'), (-94, 22, '#FF7A45'), (-68, 22, '#FF3E8A')]

I = {}
# ---------- SURF a color ----------
I['surf_1_arena'] = ('Tabla en la arena', svg(
    Ci(366, 150, 78, 'url(#sun)', 10) + L('M300 150 L432 150 M296 178 L436 178', '#FF3E8A', 9, .0) +
    P('M30 400 Q120 360 210 392 Q300 420 400 384 Q450 368 482 380 L482 470 L30 470 Z', 'url(#teal)', 10) +
    L('M60 410 Q130 388 200 410', '#FFFFFF', 8, .6) +
    board(236, 236, 10, 'url(#board1)', SUNSET, 'c1') +
    P('M70 470 Q120 392 250 392 Q392 392 452 470 Z', 'url(#sand)', 12) +
    L('M150 440 L170 436 M300 430 L322 432 M380 452 L398 448', '#C9913E', 7, .8) + spark(96, 96)))
I['surf_2_tabla'] = ('Tabla con cordón', svg(
    shadow(250, 460, 180) +
    board(250, 236, -38, 'url(#board3)', [(-128, 18, '#FFE08A'), (-104, 18, '#FFF4E6'), (-80, 18, '#2EC4B6')], 'c2', stringer='#FFF4E6') +
    L('M392 388 C430 420 440 460 400 470 C360 480 330 450 360 428 C380 414 410 430 404 452', O, 18) +
    L('M392 388 C430 420 440 460 400 470 C360 480 330 450 360 428 C380 414 410 430 404 452', 'url(#teal)', 8) +
    R(386, 436, 40, 28, 'url(#dark)', 10, 8, 'transform="rotate(-20 406 450)"') + spark(110, 96)))
I['surf_3_cruzadas'] = ('Tablas cruzadas', svg(
    Ci(256, 214, 150, 'url(#sun)', 12) +
    L('M120 250 L392 250 M132 290 L380 290', '#FFFFFF', 0) +
    f'<g opacity=".35">{L("M110 236 L402 236 M118 270 L394 270 M136 304 L376 304", "#FFF4E6", 10)}</g>' +
    board(196, 264, -28, 'url(#board2)', [(-128, 16, '#FFF4E6'), (-106, 16, '#FF3E8A')], 'c3a', scale=.92, stringer='#FFF4E6') +
    board(316, 264, 28, 'url(#board3)', [(-128, 16, '#FFE08A'), (-106, 16, '#2EC4B6')], 'c3b', scale=.92, stringer='#FFF4E6') +
    P('M70 452 Q256 410 442 452 L442 470 L70 470 Z', 'url(#sand)', 10) + spark(440, 80)))

# ---------- LLAVERO a color ----------
def chain(x1, y1, x2, y2, n=4):
    out = ''
    for i in range(n):
        t = (i + .5) / n
        x = x1 + (x2 - x1) * t; y = y1 + (y2 - y1) * t
        ang = math.degrees(math.atan2(y2 - y1, x2 - x1))
        out += f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="12" ry="7" transform="rotate({ang:.0f} {x:.1f} {y:.1f})" fill="none" stroke="{O}" stroke-width="10"/>'
        out += f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="12" ry="7" transform="rotate({ang:.0f} {x:.1f} {y:.1f})" fill="none" stroke="url(#metal)" stroke-width="4"/>'
    return out
def ring(cx, cy, r):
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{O}" stroke-width="28"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="url(#metal)" stroke-width="14"/>'
            + HL(f'M{cx-r*.7:.0f} {cy-r*.7:.0f} A{r} {r} 0 0 1 {cx:.0f} {cy-r:.0f}', 5, .9))
def house_key(cx, cy, rot, s=1):
    return (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">' +
            R(-12, 30, 24, 150, 'url(#gold)', 4, 9) + P('M12 120 L34 120 L34 136 L24 136 L24 150 L36 150 L36 166 L12 166 Z', 'url(#gold)', 8) +
            P('M0 -70 L-62 -18 L-48 -18 L-48 44 L48 44 L48 -18 L62 -18 Z', 'url(#gold)', 11) +
            R(-14, 4, 28, 40, O, 3, 0) + Ci(0, -64, 0, O, 0) + R(-36, -10, 20, 18, '#FFF4E6', 2, 5) + R(16, -10, 20, 18, '#FFF4E6', 2, 5) + '</g>')
def car_fob(cx, cy, rot, s=1):
    return (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">' +
            R(-14, 70, 28, 110, 'url(#steel)', 4, 9) + P('M14 110 L30 116 L22 130 L30 144 L14 150 Z', 'url(#steel)', 7) +
            R(-50, -70, 100, 150, 'url(#dark)', 32, 11) + Ci(0, -32, 16, 'url(#pink)', 6) + Ci(0, 12, 16, '#2EC4B6', 6) +
            R(-14, 42, 28, 14, '#FFE08A', 7, 4) + HL('M-34 -50 L-34 30', 6, .35) + '</g>')
def boat_float(cx, cy, rot, s=1):
    return (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">' +
            R(-30, -80, 60, 170, 'url(#float)', 30, 11) + R(-30, -20, 60, 22, '#FFFFFF', 0, 0) + R(-30, 20, 60, 22, '#FFFFFF', 0, 0) +
            R(-30, -80, 60, 170, 'none', 30, 11) + P('M-14 -36 L14 -36 L8 -26 L-8 -26 Z', O, 0) +
            L('M-12 -60 L-12 60', '#FFFFFF', 6, .45) + '</g>')
def money_tag(cx, cy, rot, s=1):
    return (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">' +
            P('M-50 -56 L30 -56 L58 0 L30 56 L-50 56 Z', 'url(#green)', 11) + Ci(32, 0, 10, '#140A24', 0) +
            dollar(-12, 2, 0.4, '#FFF4E6', 30) + '</g>')

I['llavero_1_colgando'] = ('Llavero completo', svg(
    ring(256, 110, 66) +
    chain(214, 166, 130, 250, 3) + chain(246, 176, 230, 262, 2) + chain(278, 174, 300, 262, 2) + chain(306, 164, 386, 244, 3) +
    boat_float(120, 330, 12, .95) + house_key(220, 330, 4, .95) + car_fob(310, 336, -6, .9) + money_tag(398, 312, -18, .9) + spark(452, 90)))
I['llavero_2_cuero'] = ('Llavero de cuero', svg(
    shadow(256, 460, 170) +
    house_key(150, 300, -28, 1.05) + car_fob(350, 296, 26, 1.0) +
    P('M196 70 Q196 40 226 40 L286 40 Q316 40 316 70 L316 300 Q316 340 256 360 Q196 340 196 300 Z', 'url(#leather)', 12) +
    L('M214 64 L214 296 M298 64 L298 296', '#FFE08A', 4, .7) +
    Ci(256, 200, 44, 'url(#gold)', 10) + f'<path d="{star(256, 204, 26)}" fill="url(#pink)" stroke="{O}" stroke-width="6" stroke-linejoin="round"/>' +
    R(226, 340, 60, 40, 'url(#metal)', 10, 10) + ring(256, 410, 30) + HL('M222 80 L222 160', 7, .4) + spark(440, 96)))
I['llavero_3_abanico'] = ('Llaves en abanico', svg(
    shadow(256, 462, 150) +
    boat_float(150, 300, -34, 1.0) + car_fob(256, 300, 0, 1.0) + house_key(362, 300, 34, 1.0) +
    ring(256, 120, 58) +
    Ci(408, 108, 48, 'url(#gold)', 10) + dollar(408, 110, 0.38, O, 30) + spark(92, 110)))

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
def gb(tx, ty, rot, s=1):  # board silhouette group open
    return f'<g transform="translate({tx} {ty}) rotate({rot}) scale({s})">'
def board_body(tx, ty, rot, s=1, fin=True):
    return gb(tx, ty, rot, s) + f'<path d="{BOARD}" fill="{C}"/>' + (f'<path d="M20 120 L58 132 L30 176 Z" fill="{C}"/>' if fin else '') + '</g>'
def board_cut(tx, ty, rot, s=1, logo=True, bands=2):
    out = gb(tx, ty, rot, s) + f'<clipPath id="g{tx}{ty}"><path d="{BOARD}"/></clipPath><g clip-path="url(#g{tx}{ty})">'
    for i in range(bands): out += f'<rect x="-80" y="{-126 + i*30}" width="160" height="12" fill="#000"/>'
    out += '</g><path d="M0 -60 L0 170" stroke="#000" stroke-width="9" stroke-linecap="round"/>'
    if logo: out += f'<path d="{star(0, 70, 26)}" fill="#000"/>'
    return out + '</g>'
def board_gap(tx, ty, rot, s=1):
    return gb(tx, ty, rot, s) + f'<path d="{BOARD}" fill="#000" stroke="#000" stroke-width="30" stroke-linejoin="round"/></g>'

G = {}
G['surf_1_arena'] = ('Tabla en la arena', glyphL([
    (f'<circle cx="366" cy="150" r="80" fill="{C}"/>' + f'<path d="M30 400 Q120 360 210 392 Q300 420 400 384 Q450 368 482 380 L482 470 L30 470 Z" fill="{C}"/>',
     board_gap(236, 236, 10) + '<path d="M58 470 Q116 380 250 380 Q400 380 464 470 Z" fill="#000"/>' +
     '<path d="M296 140 L436 140 M292 170 L440 170" stroke="#000" stroke-width="10"/>'),
    (board_body(236, 236, 10), board_cut(236, 236, 10)),
    (f'<path d="M70 470 Q120 392 250 392 Q392 392 452 470 Z" fill="{C}"/>', '<path d="M150 440 L170 436 M300 430 L322 432" stroke="#000" stroke-width="8" stroke-linecap="round"/>')]))
G['surf_2_tabla'] = ('Tabla con cordón', glyphL([
    (board_body(250, 236, -38), board_cut(250, 236, -38, bands=3)),
    (f'<path d="M392 388 C430 420 440 460 400 470 C360 480 330 450 360 428 C380 414 410 430 404 452" fill="none" stroke="{C}" stroke-width="16" stroke-linecap="round"/>' +
     f'<rect x="382" y="434" width="46" height="32" rx="10" fill="{C}" transform="rotate(-20 406 450)"/>', '')]))
G['surf_3_cruzadas'] = ('Tablas cruzadas', glyphL([
    (f'<circle cx="256" cy="214" r="152" fill="{C}"/>', '<path d="M100 236 L412 236 M104 270 L408 270 M116 304 L396 304" stroke="#000" stroke-width="12"/>' + board_gap(196, 264, -28, .92) + board_gap(316, 264, 28, .92) + '<path d="M60 470 Q256 396 452 470 Z" fill="#000"/>'),
    (board_body(196, 264, -28, .92), board_cut(196, 264, -28, .92, bands=2) + board_gap(316, 264, 28, .92)),
    (board_body(316, 264, 28, .92), board_cut(316, 264, 28, .92, bands=2)),
    (f'<path d="M70 452 Q256 410 442 452 L442 470 L70 470 Z" fill="{C}"/>', '')]))

def g_ring(cx, cy, r): return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{C}" stroke-width="24"/>'
def g_chain(x1, y1, x2, y2, n):
    out = ''
    for i in range(n):
        t = (i + .5) / n; x = x1 + (x2 - x1) * t; y = y1 + (y2 - y1) * t
        ang = math.degrees(math.atan2(y2 - y1, x2 - x1))
        out += f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="13" ry="8" transform="rotate({ang:.0f} {x:.1f} {y:.1f})" fill="none" stroke="{C}" stroke-width="8"/>'
    return out
def g_house_key(cx, cy, rot, s=1):
    body = (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})"><rect x="-13" y="30" width="26" height="150" rx="4" fill="{C}"/>'
            f'<path d="M12 120 L36 120 L36 136 L26 136 L26 150 L38 150 L38 166 L12 166 Z" fill="{C}"/><path d="M0 -74 L-66 -18 L-50 -18 L-50 46 L50 46 L50 -18 L66 -18 Z" fill="{C}"/></g>')
    cut = (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})"><rect x="-14" y="6" width="28" height="40" rx="3" fill="#000"/>'
           f'<rect x="-38" y="-12" width="22" height="20" rx="2" fill="#000"/><rect x="16" y="-12" width="22" height="20" rx="2" fill="#000"/></g>')
    return body, cut
def g_car_fob(cx, cy, rot, s=1):
    body = (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})"><rect x="-14" y="70" width="28" height="110" rx="4" fill="{C}"/>'
            f'<path d="M14 110 L32 116 L24 130 L32 144 L14 150 Z" fill="{C}"/><rect x="-52" y="-72" width="104" height="154" rx="34" fill="{C}"/></g>')
    cut = (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})"><circle cx="0" cy="-32" r="17" fill="#000"/><circle cx="0" cy="12" r="17" fill="#000"/>'
           f'<rect x="-16" y="42" width="32" height="14" rx="7" fill="#000"/><rect x="-18" y="72" width="36" height="10" fill="#000"/></g>')
    return body, cut
def g_float(cx, cy, rot, s=1):
    body = f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})"><rect x="-32" y="-82" width="64" height="174" rx="32" fill="{C}"/></g>'
    cut = f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})"><rect x="-40" y="-18" width="80" height="14" fill="#000"/><rect x="-40" y="22" width="80" height="14" fill="#000"/></g>'
    return body, cut
def g_tag(cx, cy, rot, s=1):
    body = f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})"><path d="M-52 -58 L32 -58 L60 0 L32 58 L-52 58 Z" fill="{C}"/></g>'
    cut = f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})"><circle cx="32" cy="0" r="10" fill="#000"/>' + dollar(-12, 2, 0.4, '#000', 30) + '</g>'
    return body, cut
def merge(*items):
    return [(b, c) for b, c in items]

G['llavero_1_colgando'] = ('Llavero completo', glyphL(
    [(g_ring(256, 110, 66) + g_chain(214, 166, 130, 250, 3) + g_chain(246, 176, 230, 262, 2) + g_chain(278, 174, 300, 262, 2) + g_chain(306, 164, 386, 244, 3), '')] +
    merge(g_float(120, 330, 12, .95), g_house_key(220, 330, 4, .95), g_car_fob(310, 336, -6, .9), g_tag(398, 312, -18, .9))))
lk = g_house_key(150, 300, -28, 1.05); cf = g_car_fob(350, 296, 26, 1.0)
G['llavero_2_cuero'] = ('Llavero de cuero', glyphL([
    (lk[0], lk[1] + '<path d="M196 70 Q196 40 226 40 L286 40 Q316 40 316 70 L316 300 Q316 340 256 360 Q196 340 196 300 Z" fill="#000" stroke="#000" stroke-width="26" stroke-linejoin="round"/>'),
    (cf[0], cf[1] + '<path d="M196 70 Q196 40 226 40 L286 40 Q316 40 316 70 L316 300 Q316 340 256 360 Q196 340 196 300 Z" fill="#000" stroke="#000" stroke-width="26" stroke-linejoin="round"/>'),
    (f'<path d="M196 70 Q196 40 226 40 L286 40 Q316 40 316 70 L316 300 Q316 340 256 360 Q196 340 196 300 Z" fill="{C}"/><rect x="226" y="346" width="60" height="38" rx="10" fill="{C}"/>' + g_ring(256, 412, 30),
     f'<circle cx="256" cy="200" r="48" fill="#000"/><path d="M216 64 L216 150 M296 64 L296 150 M216 250 L216 296 M296 250 L296 296" stroke="#000" stroke-width="6" stroke-dasharray="10 8"/><rect x="226" y="346" width="60" height="6" fill="#000"/>'),
    (f'<circle cx="256" cy="200" r="34" fill="{C}"/>', f'<path d="{star(256, 204, 24)}" fill="#000"/>')]))
fl = g_float(150, 300, -34); cf3 = g_car_fob(256, 300, 0); hk = g_house_key(362, 300, 34)
G['llavero_3_abanico'] = ('Llaves en abanico', glyphL([
    (fl[0], fl[1]), (cf3[0], cf3[1] + '<g transform="translate(150 300) rotate(-34)"><rect x="-44" y="-94" width="88" height="198" rx="40" fill="#000"/></g>'),
    (hk[0], hk[1] + '<g transform="translate(256 300)"><rect x="-64" y="-84" width="128" height="178" rx="40" fill="#000"/></g>'),
    (g_ring(256, 120, 58) + f'<circle cx="408" cy="108" r="50" fill="{C}"/>', dollar(408, 110, 0.38, '#000', 30))]))

json.dump({k: v[0] for k, v in I.items()}, open('names.json', 'w'), ensure_ascii=False)
for k, (n, s) in I.items(): open(f'fc_{k}.svg', 'w').write(s)
for k, (n, s) in G.items():
    open(f'gm_{k}_d.svg', 'w').write(s.replace('COLOR', '#1E1238'))
    open(f'gm_{k}_w.svg', 'w').write(s.replace('COLOR', '#FFFFFF'))
print(len(I), len(G))
