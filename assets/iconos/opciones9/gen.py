"""Llavero v2: correa más larga, keyfob de lujo (estilo europeo, sin marcas) y llave lujosa dorada."""
import math, os
src = open('base.py').read().split("STRAP = ")[0].replace("os.chdir('../v10')", "os.chdir('../v11')")
exec(src)
def luxe_key(cx, cy, rot, s=1):
    g = f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">'
    g += R(-10, 34, 20, 150, 'url(#brass)', 5, 9)
    g += P('M10 120 L30 120 L30 130 L22 130 L22 142 L34 142 L34 152 L22 152 L22 164 L32 164 L32 176 L10 176 Z', 'url(#brass)', 7)
    g += R(-20, 30, 40, 12, 'url(#gold)', 6, 7) + R(-16, 48, 32, 9, 'url(#gold)', 4, 6)
    for dx, dy in ((0, -58), (-26, -32), (26, -32), (0, -6)):
        g += Ci(dx, dy, 22, 'url(#brass)', 9)
    g += Ci(0, -32, 20, 'url(#brass)', 0) + Ci(0, -58, 8, '#2B1E92', 5)
    g += f'<path d="M0 -46 L12 -32 L0 -18 L-12 -32 Z" fill="url(#pink)" stroke="{O}" stroke-width="5" stroke-linejoin="round"/>'
    g += HL('M-4 60 L-4 170', 4, .55) + HL('M-30 -44 Q-30 -60 -14 -66', 4, .7)
    return g + '</g>'
FOB = 'M-42 -78 Q0 -96 42 -78 Q56 0 42 80 Q0 98 -42 80 Q-56 0 -42 -78 Z'
def luxe_fob(cx, cy, rot, s=1):
    g = f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">'
    g += f'<path d="M-12 -86 Q-12 -112 0 -112 Q12 -112 12 -86" fill="none" stroke="{O}" stroke-width="16"/><path d="M-12 -86 Q-12 -112 0 -112 Q12 -112 12 -86" fill="none" stroke="url(#silver)" stroke-width="7"/>'
    g += f'<path d="{FOB}" fill="url(#black)" stroke="{O}" stroke-width="11" stroke-linejoin="round"/>'
    g += f'<path d="{FOB}" transform="scale(.9)" fill="none" stroke="url(#silver)" stroke-width="7"/>'
    for i, y in enumerate((-36, 0, 36)):
        g += R(-16, y - 12, 32, 24, 'url(#silver)', 8, 4)
    g += L('M-6 -40 L-6 -32 M6 -40 L6 -32', O, 3) + Ci(0, 0, 5, O, 0) + P('M-7 30 L7 30 L0 42 Z', O, 0)
    g += HL('M-28 -60 Q-38 0 -28 56', 5, .45)
    return g + '</g>'
STRAP = 'M218 12 Q218 0 232 0 L280 0 Q294 0 294 12 L294 166 Q294 180 280 182 L232 182 Q218 180 218 166 Z'
RING = (256, 236, 36)
CH = [((230, 260), (154, 312)), ((256, 274), (256, 290)), ((282, 260), (352, 298))]
fc = svg(SILVER + shadow(256, 486, 160) +
    ''.join(chain(*a, *b) for a, b in CH) +
    luxe_key(150, 372, -10, .72) + crypto_wallet(256, 382, 0, .72) + luxe_fob(362, 384, 10, .78) +
    P(STRAP, 'url(#leatherTeal)', 12) + L('M231 12 L231 170 M281 12 L281 170', '#FFF4E6', 3, .7) +
    Ci(256, 44, 13, 'url(#silver)', 7) + Ci(256, 44, 5, O, 0) +
    R(230, 174, 52, 22, 'url(#silver)', 8, 8) +
    f'<circle cx="{RING[0]}" cy="{RING[1]}" r="{RING[2]}" fill="none" stroke="{O}" stroke-width="24"/>'
    f'<circle cx="{RING[0]}" cy="{RING[1]}" r="{RING[2]}" fill="none" stroke="url(#silver)" stroke-width="11"/>' +
    HL('M228 210 A36 36 0 0 1 256 200', 4, .9) + HL('M238 16 L238 130', 6, .4) + spark(446, 92))
# --- estilo juego ---
def g_luxe_key(cx, cy, rot, s=1):
    b = (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">' + Rc(-11, 34, 22, 150, 5) + Rc(-22, 28, 44, 16, 6) + Rc(-18, 48, 36, 11, 4) +
         f'<path d="M10 120 L32 120 L32 130 L24 130 L24 142 L36 142 L36 152 L24 152 L24 164 L34 164 L34 176 L10 176 Z" fill="{C}"/>' +
         ''.join(Cc(dx, dy, 26) for dx, dy in ((0, -58), (-26, -32), (26, -32), (0, -6))) + '</g>')
    c = (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">' + Cc(0, -58, 9, '#000') +
         '<path d="M0 -48 L13 -32 L0 -16 L-13 -32 Z" fill="#000"/><path d="M-22 44 L22 44" stroke="#000" stroke-width="5"/></g>')
    return b, c
def g_luxe_fob(cx, cy, rot, s=1):
    b = (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})"><path d="M-12 -86 Q-12 -114 0 -114 Q12 -114 12 -86" fill="none" stroke="{C}" stroke-width="10"/>' +
         f'<path d="{FOB}" fill="{C}"/></g>')
    c = (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})"><path d="{FOB}" transform="scale(.86)" fill="none" stroke="#000" stroke-width="7"/>' +
         ''.join(Rc(-17, y - 12, 34, 24, 8, '#000') for y in (-36, 0, 36)) + '</g>')
    return b, c
lk = g_luxe_key(150, 372, -10, .72); wl = g_wallet(256, 382, 0, .72); fb = g_luxe_fob(362, 384, 10, .78)
gm = glyphL([
    (''.join(chain(*a, *b, color=C) for a, b in CH), gap(lk[0]) + gap(wl[0]) + gap(fb[0])),
    (lk[0], lk[1]), (fb[0], fb[1]), (wl[0], wl[1]), (g_wallet_screen(256, 382, 0, .72), ''),
    (f'<path d="{STRAP}" fill="{C}"/>' + Rc(228, 172, 56, 26, 8) + f'<circle cx="{RING[0]}" cy="{RING[1]}" r="{RING[2]}" fill="none" stroke="{C}" stroke-width="20"/>',
     Cc(256, 44, 15, '#000') + '<path d="M232 14 L232 168 M280 14 L280 168" stroke="#000" stroke-width="5" stroke-dasharray="10 8"/>'),
    (Cc(256, 44, 7), '')])
open('fc_llavero.svg', 'w').write(fc)
open('gm_llavero_d.svg', 'w').write(gm.replace('COLOR', '#1E1238'))
open('gm_llavero_w.svg', 'w').write(gm.replace('COLOR', '#FFFFFF'))
print('ok')
