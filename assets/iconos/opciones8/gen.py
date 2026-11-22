"""Llavero de cuero con argolla y cadenas de plata: llave de casa, billetera cripto y control del carro."""
import math, json
src2 = open('../v9/gen.py').read()
import os
os.chdir('../v9'); ns2 = {}; exec(src2.replace("for k, (n, s) in I.items()", "for k, (n, s) in {}.items()").replace("for k, (n, s) in G.items()", "for k, (n, s) in {}.items()").replace("json.dump(", "(lambda *a, **k: None)("), ns2)
os.chdir('../v10')
car_key, crypto_wallet, house_key = ns2['car_key'], ns2['crypto_wallet'], ns2['house_key']
svg, P, L, HL, R, Ci, O, spark, shadow = (ns2[k] for k in ['svg', 'P', 'L', 'HL', 'R', 'Ci', 'O', 'spark', 'shadow'])
g_car_key, g_wallet, g_wallet_screen, g_house_key, glyphL, Rc, Cc, gap, C = (ns2[k] for k in ['g_car_key', 'g_wallet', 'g_wallet_screen', 'g_house_key', 'glyphL', 'Rc', 'Cc', 'gap', 'C'])

SILVER = '<defs><linearGradient id="silver" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".45" stop-color="#D8D2E8"/><stop offset="1" stop-color="#8E86A8"/></linearGradient></defs>'
def chain(x1, y1, x2, y2, color=None, link=24):
    """Cadena de eslabones: uno de frente (óvalo abierto) y uno de canto (plano), alternados."""
    dist = math.hypot(x2 - x1, y2 - y1); n = max(2, round(dist / (link * .78)))
    ang = math.degrees(math.atan2(y2 - y1, x2 - x1)); out = ''
    for i in range(n):
        t = (i + .5) / n; x = x1 + (x2 - x1) * t; y = y1 + (y2 - y1) * t
        tr = f'transform="rotate({ang:.1f} {x:.1f} {y:.1f})"'
        if color is None:
            if i % 2 == 0:
                out += f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{link/2:.0f}" ry="8" {tr} fill="none" stroke="{O}" stroke-width="11"/>'
                out += f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{link/2:.0f}" ry="8" {tr} fill="none" stroke="url(#silver)" stroke-width="5"/>'
            else:
                out += f'<rect x="{x - link/2:.1f}" y="{y - 4:.1f}" width="{link}" height="8" rx="4" {tr} fill="url(#silver)" stroke="{O}" stroke-width="4"/>'
        else:
            if i % 2 == 0:
                out += f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{link/2:.0f}" ry="8" {tr} fill="none" stroke="{color}" stroke-width="6"/>'
            else:
                out += f'<rect x="{x - link/2:.1f}" y="{y - 3.5:.1f}" width="{link}" height="7" rx="3.5" {tr} fill="{color}"/>'
    return out
STRAP = 'M216 28 Q216 14 230 14 L282 14 Q296 14 296 28 L296 126 Q296 140 282 142 L230 142 Q216 140 216 126 Z'
RING = (256, 196, 38)
CH = [((228, 222), (156, 300)), ((256, 236), (256, 274)), ((284, 222), (356, 282))]
fc = svg(SILVER + shadow(256, 470, 170) +
    ''.join(chain(*a, *b) for a, b in CH) +
    house_key(146, 362, -14, .8) + crypto_wallet(256, 374, 0, .8) + car_key(364, 366, 14, .8) +
    P(STRAP, 'url(#leatherTeal)', 12) + L('M229 26 L229 130 M283 26 L283 130', '#FFF4E6', 3, .7) +
    Ci(256, 56, 14, 'url(#silver)', 7) + Ci(256, 56, 5, O, 0) +
    R(230, 134, 52, 22, 'url(#silver)', 8, 8) +
    f'<circle cx="{RING[0]}" cy="{RING[1]}" r="{RING[2]}" fill="none" stroke="{O}" stroke-width="24"/>'
    f'<circle cx="{RING[0]}" cy="{RING[1]}" r="{RING[2]}" fill="none" stroke="url(#silver)" stroke-width="11"/>' +
    HL('M226 168 A38 38 0 0 1 256 158', 4, .9) + HL('M236 30 L236 100', 6, .4) + spark(446, 92))
hk = g_house_key(146, 362, -14, .8); wl = g_wallet(256, 374, 0, .8); ck = g_car_key(364, 366, 14, .8)
gm = glyphL([
    (''.join(chain(*a, *b, color=C) for a, b in CH), gap(hk[0]) + gap(wl[0]) + gap(ck[0])),
    (hk[0], hk[1]), (ck[0], ck[1]), (wl[0], wl[1]), (g_wallet_screen(256, 374, 0, .8), ''),
    (f'<path d="{STRAP}" fill="{C}"/>' + Rc(228, 132, 56, 26, 8) + f'<circle cx="{RING[0]}" cy="{RING[1]}" r="{RING[2]}" fill="none" stroke="{C}" stroke-width="20"/>',
     Cc(256, 56, 16, '#000') + '<path d="M230 28 L230 126 M282 28 L282 126" stroke="#000" stroke-width="5" stroke-dasharray="10 8"/>'),
    (Cc(256, 56, 7), '')])
open('fc_llavero.svg', 'w').write(fc)
open('gm_llavero_d.svg', 'w').write(gm.replace('COLOR', '#1E1238'))
open('gm_llavero_w.svg', 'w').write(gm.replace('COLOR', '#FFFFFF'))
print('ok')
