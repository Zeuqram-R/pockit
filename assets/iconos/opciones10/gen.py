"""Pasaporte v2: escudo nacional con VC y laureles, 'Vice City' en cursiva (garabato), chip biométrico. Sin brillo."""
import math, os
os.chdir('../v9'); src = open('gen.py').read()
ns = {}; exec(src.replace("for k, (n, s) in I.items()", "for k, (n, s) in {}.items()").replace("for k, (n, s) in G.items()", "for k, (n, s) in {}.items()").replace("json.dump(", "(lambda *a, **k: None)("), ns)
os.chdir('../v12')
svg, P, L, HL, R, Ci, O, star, shadow, text_path, glyphL, Rc, Cc, C = (ns[k] for k in ['svg', 'P', 'L', 'HL', 'R', 'Ci', 'O', 'star', 'shadow', 'text_path', 'glyphL', 'Rc', 'Cc', 'C'])

SHIELD = 'M0 -62 Q30 -52 54 -56 Q58 6 40 36 Q22 62 0 72 Q-22 62 -40 36 Q-58 6 -54 -56 Q-30 -52 0 -62 Z'
def laurel(side):
    # rama de laurel (side = -1 izquierda, 1 derecha)
    out = ''
    stem = f'M{side*40} 66 Q{side*76} 30 {side*70} -36'
    out += f'<path d="{stem}" fill="none" stroke="COL" stroke-width="5" stroke-linecap="round"/>'
    for i, t in enumerate([0.1, 0.28, 0.46, 0.64, 0.82]):
        y = 60 - t * 96; x = side * (44 + 30 * math.sin(t * math.pi * .9))
        out += f'<ellipse cx="{x + side*10:.1f}" cy="{y:.1f}" rx="11" ry="5" transform="rotate({-side*35} {x + side*10:.1f} {y:.1f})" fill="COL"/>'
        out += f'<ellipse cx="{x - side*4:.1f}" cy="{y - 9:.1f}" rx="10" ry="4.5" transform="rotate({side*55} {x - side*4:.1f} {y - 9:.1f})" fill="COL"/>'
    return out
VC = text_path('VC', 0, 20, 62, 2)
# "Vice City" cursiva: un trazo continuo que imita letra ligada
CURSIVE = ('M-70 6 C-66 -14 -60 -14 -58 4 C-56 18 -50 18 -46 0 C-44 -8 -40 -8 -40 2 C-40 12 -34 12 -30 2 '
           'C-26 -6 -20 -6 -20 4 C-20 12 -14 12 -10 4 C-6 -4 0 -6 2 2 C4 10 -6 12 -8 4 '
           'M14 2 C14 -16 30 -16 28 -2 C26 10 18 12 18 4 C24 -4 30 -4 32 6 C34 14 40 10 42 2 C44 -6 46 -6 46 4 '
           'C46 12 52 12 54 2 C56 -16 60 -16 60 4 C60 14 66 12 68 2 C70 -6 74 -4 72 8 C70 20 62 24 60 18')
def passport_fc():
    b = shadow(250, 466, 170) + '<g transform="rotate(-8 240 260)">'
    b += R(108, 58, 262, 370, 'url(#teal)', 24) + R(108, 58, 44, 370, 'url(#tealD)', 0, 0, 'opacity=".9"') + R(108, 58, 262, 370, 'none', 24)
    # título arriba (líneas tipo "PASAPORTE")
    b += R(180, 86, 120, 10, '#FFE08A', 5, 0) + R(196, 104, 88, 7, '#FFE08A', 3, 0, 'opacity=".75"')
    # escudo nacional con laureles y estrella
    b += '<g transform="translate(240 214)">'
    b += laurel(-1).replace('COL', '#FFE08A') + laurel(1).replace('COL', '#FFE08A')
    b += f'<path d="{SHIELD}" fill="url(#vcText)" stroke="{O}" stroke-width="7" stroke-linejoin="round"/>'
    b += f'<path d="{SHIELD}" transform="scale(.8)" fill="none" stroke="#FFF4E6" stroke-width="3" opacity=".7"/>'
    b += f'<path d="{VC}" fill="#2B1E92" stroke="#FFF4E6" stroke-width="2"/>'
    b += f'<path d="{star(0, -80, 13)}" fill="#FFE08A" stroke="{O}" stroke-width="4" stroke-linejoin="round"/></g>'
    # "Vice City" en cursiva
    b += f'<g transform="translate(240 330) scale(1.15)"><path d="{CURSIVE}" fill="none" stroke="#FFE08A" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"/></g>'
    # chip biométrico
    b += R(220, 370, 40, 26, 'none', 6, 0, 'stroke="#FFE08A" stroke-width="4"') + Ci(240, 383, 7, 'none', 0, 'stroke="#FFE08A" stroke-width="3"')
    b += L('M220 383 L233 383 M247 383 L260 383', '#FFE08A', 3)
    b += HL('M136 90 L136 400', 6, .35) + '</g>'
    b += '<g transform="rotate(14 378 380)">' + Ci(380, 384, 58, 'url(#pink)', 10, 'opacity=".96"') + Ci(380, 384, 40, 'none', 6, 'stroke-dasharray="8 8"') + f'<path d="{star(380, 384, 22)}" fill="#FFF4E6" stroke="{O}" stroke-width="5" stroke-linejoin="round"/></g>'
    return svg(b)
def passport_gm():
    T = '<g transform="rotate(-8 230 256)">'
    layers = [
        (T + Rc(100, 50, 270, 380, 26) + '</g>',
         T + Rc(140, 50, 10, 380, 0, '#000') + Rc(180, 82, 120, 12, 6, '#000') + Rc(196, 102, 88, 8, 4, '#000') +
         f'<g transform="translate(240 214)"><path d="{SHIELD}" transform="scale(1.18)" fill="#000"/>' + laurel(-1).replace('COL', '#000') + laurel(1).replace('COL', '#000') +
         f'<path d="{star(0, -80, 15)}" fill="#000"/></g>' +
         f'<g transform="translate(240 330) scale(1.15)"><path d="{CURSIVE}" fill="none" stroke="#000" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/></g>' +
         '<rect x="220" y="370" width="40" height="26" rx="6" fill="none" stroke="#000" stroke-width="5"/><circle cx="240" cy="383" r="7" fill="none" stroke="#000" stroke-width="4"/></g>' +
         Cc(384, 386, 84, '#000')),
        (T + f'<g transform="translate(240 214)"><path d="{SHIELD}" fill="{C}"/></g></g>', T + f'<g transform="translate(240 214)"><path d="{VC}" fill="#000"/></g></g>'),
        (Cc(384, 386, 68), f'<circle cx="384" cy="386" r="48" fill="none" stroke="#000" stroke-width="8" stroke-dasharray="10 9"/><path d="{star(384, 388, 26)}" fill="#000"/>')]
    return glyphL(layers)
open('fc_pasaporte.svg', 'w').write(passport_fc())
g = passport_gm()
open('gm_pasaporte_d.svg', 'w').write(g.replace('COLOR', '#1E1238'))
open('gm_pasaporte_w.svg', 'w').write(g.replace('COLOR', '#FFFFFF'))
print('ok')
