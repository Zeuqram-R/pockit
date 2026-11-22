"""Llavero v3: correa larga, llave antigua de lujo y keyfob negro mate (sin marcas)."""
import math, os
src = open('base.py').read().split("STRAP = ")[0].replace("os.chdir('../v10')", "os.chdir('../v11')")
exec(src)

def luxe_key(cx, cy, rot, s=1):
    # llave antigua de lujo: cabeza ovalada con aro calado, gema rosa y cuello con anillos
    g = f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">'
    g += R(-10, 30, 20, 154, 'url(#brass)', 5, 9)
    g += P('M10 120 L30 120 L30 130 L22 130 L22 142 L34 142 L34 152 L22 152 L22 164 L32 164 L32 176 L10 176 Z', 'url(#brass)', 7)
    g += R(-20, 22, 40, 12, 'url(#gold)', 6, 7) + R(-16, 40, 32, 9, 'url(#gold)', 4, 6) + R(-13, 56, 26, 7, 'url(#gold)', 3, 5)
    g += f'<ellipse cx="0" cy="-34" rx="44" ry="54" fill="url(#brass)" stroke="{O}" stroke-width="10"/>'
    g += f'<ellipse cx="0" cy="-34" rx="28" ry="38" fill="#2B1E92" stroke="{O}" stroke-width="7"/>'
    g += f'<ellipse cx="0" cy="-34" rx="36" ry="46" fill="none" stroke="#FFE7A0" stroke-width="3" stroke-dasharray="3 7" opacity=".9"/>'
    g += f'<path d="M0 -52 L13 -34 L0 -16 L-13 -34 Z" fill="url(#pink)" stroke="{O}" stroke-width="5" stroke-linejoin="round"/>'
    g += Ci(0, -84, 9, 'url(#gold)', 6)
    g += HL('M-4 64 L-4 170', 4, .55) + HL('M-34 -50 Q-34 -76 -12 -84', 4, .7)
    return g + '</g>'

FOB = 'M-42 -78 Q0 -96 42 -78 Q56 0 42 80 Q0 98 -42 80 Q-56 0 -42 -78 Z'
def luxe_fob(cx, cy, rot, s=1):
    # keyfob negro mate (sin cromo ni brillo)
    g = f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">'
    g += f'<path d="M-12 -86 Q-12 -112 0 -112 Q12 -112 12 -86" fill="none" stroke="{O}" stroke-width="16"/><path d="M-12 -86 Q-12 -112 0 -112 Q12 -112 12 -86" fill="none" stroke="#2A2333" stroke-width="7"/>'
    g += f'<path d="{FOB}" fill="#221C2C" stroke="{O}" stroke-width="11" stroke-linejoin="round"/>'
    g += f'<path d="{FOB}" transform="scale(.9)" fill="none" stroke="#120E18" stroke-width="5"/>'
    for y in (-36, 0, 36):
        g += R(-16, y - 12, 32, 24, '#18131F', 8, 4) + R(-16, y - 12, 32, 24, 'none', 8, 0, 'stroke="url(#silver)" stroke-width="1.5" opacity=".6"')
    # símbolos plateados: candado, desbloqueo y maletero
    g += R(-7, -38, 14, 10, 'url(#silver)', 2, 0) + P('M-4 -38 L-4 -42 Q-4 -46 0 -46 Q4 -46 4 -42 L4 -38', 'none', 0, 'stroke="url(#silver)" stroke-width="2.5"')
    g += R(-7, -2, 14, 10, 'url(#silver)', 2, 0) + P('M-4 -2 L-4 -6 Q-4 -10 0 -10 Q4 -10 6 -7', 'none', 0, 'stroke="url(#silver)" stroke-width="2.5"')
    g += P('M-9 40 L-9 32 Q0 26 9 32 L9 40 Z', 'url(#silver)', 0)
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
    b = (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">' + Rc(-11, 30, 22, 154, 5) + Rc(-22, 22, 44, 14, 6) + Rc(-18, 40, 36, 11, 4) + Rc(-14, 56, 28, 8, 3) +
         f'<path d="M10 120 L32 120 L32 130 L24 130 L24 142 L36 142 L36 152 L24 152 L24 164 L34 164 L34 176 L10 176 Z" fill="{C}"/>' +
         f'<ellipse cx="0" cy="-34" rx="46" ry="56" fill="{C}"/>' + Cc(0, -86, 11) + '</g>')
    c = f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})"><ellipse cx="0" cy="-34" rx="28" ry="38" fill="#000"/></g>'
    return b, c
def g_luxe_key_gem(cx, cy, rot, s=1):
    return f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})"><path d="M0 -54 L14 -34 L0 -14 L-14 -34 Z" fill="{C}"/></g>'
def g_luxe_fob(cx, cy, rot, s=1):
    b = (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})"><path d="M-12 -86 Q-12 -114 0 -114 Q12 -114 12 -86" fill="none" stroke="{C}" stroke-width="10"/>' +
         f'<path d="{FOB}" fill="{C}"/></g>')
    c = (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})"><path d="{FOB}" transform="scale(.86)" fill="none" stroke="#000" stroke-width="7"/>' +
         ''.join(Rc(-17, y - 12, 34, 24, 8, '#000') for y in (-36, 0, 36)) + '</g>')
    return b, c
lk = g_luxe_key(150, 372, -10, .72); wl = g_wallet(256, 382, 0, .72); fb = g_luxe_fob(362, 384, 10, .78)
gm = glyphL([
    (''.join(chain(*a, *b, color=C) for a, b in CH), gap(lk[0]) + gap(wl[0]) + gap(fb[0])),
    (lk[0], lk[1]), (g_luxe_key_gem(150, 372, -10, .72), ''), (fb[0], fb[1]), (wl[0], wl[1]), (g_wallet_screen(256, 382, 0, .72), ''),
    (f'<path d="{STRAP}" fill="{C}"/>' + Rc(228, 172, 56, 26, 8) + f'<circle cx="{RING[0]}" cy="{RING[1]}" r="{RING[2]}" fill="none" stroke="{C}" stroke-width="20"/>',
     Cc(256, 44, 15, '#000') + '<path d="M232 14 L232 168 M280 14 L280 168" stroke="#000" stroke-width="5" stroke-dasharray="10 8"/>'),
    (Cc(256, 44, 7), '')])
open('fc_llavero.svg', 'w').write(fc)
open('gm_llavero_d.svg', 'w').write(gm.replace('COLOR', '#1E1238'))
open('gm_llavero_w.svg', 'w').write(gm.replace('COLOR', '#FFFFFF'))
print('ok')
