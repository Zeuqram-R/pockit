"""Ronda 7: pasaporte con "VC", caja fuerte, maletín y llavero de cuero (cripto + carro + casa). A color y estilo juego."""
import math, json
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

src = open('../v4/fc.py').read().split('I = {}')[0]
ns = {}; exec(src, ns)
DEFS, O, P, L, HL, R, Ci, E, star, spark, shadow = (ns[k] for k in ['DEFS', 'O', 'P', 'L', 'HL', 'R', 'Ci', 'E', 'star', 'spark', 'shadow'])
EXTRA = '''<defs>
<linearGradient id="safe" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#7B52DD"/><stop offset="1" stop-color="#3A1E8C"/></linearGradient>
<linearGradient id="safeSide" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3A1E8C"/><stop offset="1" stop-color="#22105E"/></linearGradient>
<linearGradient id="brass" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFE7A0"/><stop offset=".55" stop-color="#E9B44C"/><stop offset="1" stop-color="#A8701E"/></linearGradient>
<linearGradient id="leatherPink" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FF6FA6"/><stop offset="1" stop-color="#B0175A"/></linearGradient>
<linearGradient id="leatherTeal" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#4FD6C8"/><stop offset="1" stop-color="#127A72"/></linearGradient>
<linearGradient id="black" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#4A3A6A"/><stop offset="1" stop-color="#140A24"/></linearGradient>
<linearGradient id="vcText" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFC56B"/><stop offset=".5" stop-color="#FF7A45"/><stop offset="1" stop-color="#FF3E8A"/></linearGradient>
</defs>'''
def svg(body): return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">{DEFS}{EXTRA}{body}</svg>'

FONT = TTFont('/home/claude/pockit/ios/Pockit/Resources/Fonts/BarlowCondensed-Bold.ttf')
def text_path(txt, cx, baseline, size, tracking=0):
    """Texto convertido a trazos (Barlow Condensed Bold, licencia OFL)."""
    gs = FONT.getGlyphSet(); cmap = FONT.getBestCmap(); upm = FONT['head'].unitsPerEm
    s = size / upm
    names = [cmap[ord(c)] for c in txt]
    widths = [gs[n].width for n in names]
    total = sum(widths) * s + tracking * (len(txt) - 1)
    x = cx - total / 2; d = ''
    for n, w in zip(names, widths):
        pen = SVGPathPen(gs)
        gs[n].draw(TransformPen(pen, (s, 0, 0, -s, x, baseline)))
        d += pen.getCommands() + ' '
        x += w * s + tracking
    return d

I = {}; G = {}
# ---------- Pasaporte con VC ----------
VC = text_path('VC', 250, 236, 118, 4)
I['pasaporte_vc'] = ('Pasaporte VC', svg(
    shadow(250, 456, 170) +
    '<g transform="rotate(-8 240 260)">' +
    R(112, 70, 250, 350, 'url(#teal)', 22) + R(112, 70, 40, 350, 'url(#tealD)', 0, 0, 'opacity=".9"') + R(112, 70, 250, 350, 'none', 22) +
    R(168, 120, 164, 140, '#2B1E92', 18, 9) +
    f'<path d="{VC}" fill="url(#vcText)" stroke="{O}" stroke-width="7" stroke-linejoin="round" paint-order="stroke"/>' +
    R(176, 296, 148, 18, '#FFE08A', 9, 6) + R(196, 330, 108, 14, '#FFE08A', 7, 5, 'opacity=".8"') +
    HL('M140 100 L140 390', 6, .35) + '</g>' +
    '<g transform="rotate(14 370 360)">' + Ci(372, 362, 66, 'url(#pink)', 10, 'opacity=".96"') + Ci(372, 362, 46, 'none', 6, 'stroke-dasharray="8 8"') +
    f'<path d="{star(372, 362, 26)}" fill="#FFF4E6" stroke="{O}" stroke-width="5" stroke-linejoin="round"/></g>' + spark(436, 96)))

# ---------- Caja fuerte ----------
I['portfolio_caja_fuerte'] = ('Caja fuerte', svg(
    shadow(256, 466, 190) +
    R(96, 434, 50, 26, 'url(#dark)', 6, 9) + R(366, 434, 50, 26, 'url(#dark)', 6, 9) +
    P('M410 82 L446 108 L446 430 L410 444 Z', 'url(#safeSide)', 12) +
    R(66, 82, 346, 362, 'url(#safe)', 30) +
    R(100, 116, 278, 294, 'url(#safe)', 18, 10) + R(100, 116, 278, 294, '#000', 18, 0, 'opacity=".12"') +
    ''.join(Ci(x, y, 7, 'url(#brass)', 5) for x in (118, 360) for y in (134, 392)) +
    R(78, 160, 22, 54, 'url(#brass)', 6, 8) + R(78, 312, 22, 54, 'url(#brass)', 6, 8) +
    Ci(232, 262, 84, 'url(#brass)', 12) + Ci(232, 262, 62, '#2A1468', 8) +
    ''.join(L(f'M{232+50*math.cos(math.radians(a)):.0f} {262+50*math.sin(math.radians(a)):.0f} L{232+(60 if a % 90 else 56)*math.cos(math.radians(a)):.0f} {262+(60 if a % 90 else 56)*math.sin(math.radians(a)):.0f}', '#FFE08A', 5) for a in range(0, 360, 30)) +
    Ci(232, 262, 30, 'url(#brass)', 8) + L('M232 262 L232 238', O, 8) +
    R(330, 226, 26, 78, 'url(#brass)', 12, 9) + Ci(343, 220, 16, 'url(#pink)', 7) +
    HL('M92 110 L180 110', 7, .45) + HL('M86 140 L86 400', 7, .25) + spark(452, 76)))

# ---------- Maletín ----------
I['portfolio_maletin'] = ('Maletín', svg(
    shadow(256, 462, 200) +
    P('M190 132 L190 100 Q190 76 214 76 L298 76 Q322 76 322 100 L322 132', 'none', 32) +
    P('M190 132 L190 100 Q190 76 214 76 L298 76 Q322 76 322 100 L322 132', 'none', 0, 'stroke="url(#leatherPink)" stroke-width="16"') +
    R(54, 128, 404, 302, 'url(#leatherPink)', 34) +
    R(54, 128, 404, 120, 'url(#pinkD)', 34, 0, 'opacity=".35"') + R(54, 128, 404, 302, 'none', 34) +
    L('M54 236 L458 236', O, 7) + L('M70 252 L442 252', '#FFE08A', 3, .6) +
    L('M76 150 L436 150 M76 410 L436 410', '#FFF4E6', 3, .35) +
    R(116, 210, 66, 54, 'url(#brass)', 10, 9) + R(330, 210, 66, 54, 'url(#brass)', 10, 9) +
    R(136, 226, 26, 14, O, 4, 0) + R(350, 226, 26, 14, O, 4, 0) +
    ''.join(P(d, 'url(#brass)', 8) for d in ['M54 172 L54 162 Q54 128 88 128 L98 128 L98 146 L72 146 L72 172 Z',
                                            'M458 172 L458 162 Q458 128 424 128 L414 128 L414 146 L440 146 L440 172 Z',
                                            'M54 386 L54 396 Q54 430 88 430 L98 430 L98 412 L72 412 L72 386 Z',
                                            'M458 386 L458 396 Q458 430 424 430 L414 430 L414 412 L440 412 L440 386 Z']) +
    HL('M90 170 L240 170', 8, .4) + spark(452, 82)))

# ---------- Llavero de cuero: carro + billetera cripto + casa ----------
def car_key(cx, cy, rot, s=1):
    return (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">' +
            R(-12, 58, 24, 104, 'url(#steel)', 4, 9) + P('M12 92 L28 98 L20 112 L28 126 L12 132 Z', 'url(#steel)', 7) +
            P('M-44 -78 Q0 -98 44 -78 L54 54 Q0 88 -54 54 Z', 'url(#black)', 11) +
            f'<path d="{star(0, -42, 15)}" fill="url(#pink)" stroke="{O}" stroke-width="4" stroke-linejoin="round"/>' +
            Ci(-18, 18, 10, '#2EC4B6', 5) + Ci(18, 18, 10, '#FF3E8A', 5) + R(-12, 40, 24, 9, '#FFE08A', 4, 4) + HL('M-32 -58 L-36 34', 5, .35) + '</g>')
def crypto_wallet(cx, cy, rot, s=1):
    return (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">' +
            R(-36, -96, 72, 196, 'url(#steel)', 14, 11) + R(-24, -84, 48, 172, 'url(#black)', 10, 6) +
            R(-16, -62, 32, 70, '#0E1E3A', 4, 4) +
            L('M-10 -12 L-2 -26 L4 -18 L10 -40', '#6FE6D7', 4) + Ci(-8, -50, 3, '#FFE08A', 0) + Ci(0, -50, 3, '#FFE08A', 0) + Ci(8, -50, 3, '#FFE08A', 0) +
            Ci(-12, 40, 9, 'url(#gold)', 5) + Ci(12, 40, 9, 'url(#gold)', 5) + Ci(0, -112, 10, 'none', 7) + '</g>')
def house_key(cx, cy, rot, s=1, bow='url(#brass)'):
    return (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">' +
            R(-11, 30, 22, 140, 'url(#brass)', 4, 9) + P('M11 108 L32 108 L32 122 L22 122 L22 136 L34 136 L34 152 L11 152 Z', 'url(#brass)', 8) +
            P('M0 -66 L-50 -20 L-40 -20 L-40 36 L40 36 L40 -20 L50 -20 Z', bow, 10) + R(-11, 6, 22, 30, O, 3, 0) + '</g>')
I['portfolio_llavero_cuero'] = ('Llavero de cuero', svg(
    shadow(256, 468, 170) +
    house_key(140, 330, -24, .88) + crypto_wallet(256, 338, 0, .88) + car_key(372, 332, 22, .88) +
    # correa de cuero en lazo
    P('M214 30 Q214 16 228 16 L284 16 Q298 16 298 30 L298 136 Q298 152 282 154 L230 154 Q214 152 214 136 Z', 'url(#leatherTeal)', 12) +
    L('M227 28 L227 142 M285 28 L285 142', '#FFF4E6', 3, .7) +
    Ci(256, 60, 15, 'url(#brass)', 8) + Ci(256, 60, 6, O, 0) +
    R(228, 146, 56, 24, 'url(#brass)', 8, 9) +
    f'<circle cx="256" cy="200" r="34" fill="none" stroke="{O}" stroke-width="24"/><circle cx="256" cy="200" r="34" fill="none" stroke="url(#brass)" stroke-width="11"/>' +
    HL('M234 34 L234 110', 6, .4) + spark(446, 92)))

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

G['pasaporte_vc'] = ('Pasaporte VC', glyphL([
    ('<g transform="rotate(-8 230 256)">' + Rc(104, 60, 254, 360, 24) + '</g>',
     '<g transform="rotate(-8 230 256)">' + Rc(140, 60, 10, 360, 0, '#000') + Rc(164, 116, 172, 148, 20, '#000') + Rc(176, 300, 150, 20, 10, '#000') + Rc(196, 336, 110, 16, 8, '#000') + '</g>' + Cc(380, 372, 92, '#000')),
    ('<g transform="rotate(-8 230 256)">' + f'<path d="{VC}" fill="{C}"/>' + '</g>' + Cc(380, 372, 76),
     f'<circle cx="380" cy="372" r="54" fill="none" stroke="#000" stroke-width="9" stroke-dasharray="10 9"/><path d="{star(380, 376, 30)}" fill="#000"/>')]))

G['portfolio_caja_fuerte'] = ('Caja fuerte', glyphL([
    (Rc(60, 76, 392, 372, 32) + Rc(94, 432, 54, 30, 6) + Rc(364, 432, 54, 30, 6),
     Rc(96, 112, 320, 300, 18, 'none', 'stroke="#000" stroke-width="12"') + Cc(232, 262, 96, '#000') + Rc(322, 214, 42, 100, 18, '#000') +
     ''.join(Cc(x, y, 8, '#000') for x in (124, 390) for y in (140, 384))),
    (Cc(232, 262, 82) + Rc(330, 228, 26, 76, 12) + Cc(343, 220, 18),
     Cc(232, 262, 60, '#000')),
    (Cc(232, 262, 34), '<path d="M232 262 L232 236" stroke="#000" stroke-width="10" stroke-linecap="round"/>' +
     ''.join(f'<path d="M{232+44*math.cos(math.radians(a)):.0f} {262+44*math.sin(math.radians(a)):.0f} L{232+56*math.cos(math.radians(a)):.0f} {262+56*math.sin(math.radians(a)):.0f}" stroke="#000" stroke-width="0"/>' for a in range(0, 360, 30))),
    (''.join(f'<path d="M{232+44*math.cos(math.radians(a)):.0f} {262+44*math.sin(math.radians(a)):.0f} L{232+56*math.cos(math.radians(a)):.0f} {262+56*math.sin(math.radians(a)):.0f}" stroke="{C}" stroke-width="7" stroke-linecap="round"/>' for a in range(0, 360, 30)), '')]))

G['portfolio_maletin'] = ('Maletín', glyphL([
    (f'<path d="M190 134 L190 100 Q190 74 216 74 L296 74 Q322 74 322 100 L322 134" fill="none" stroke="{C}" stroke-width="28"/>' + Rc(50, 124, 412, 310, 36),
     '<path d="M50 236 L462 236" stroke="#000" stroke-width="14"/>' + Rc(108, 202, 82, 70, 12, '#000') + Rc(322, 202, 82, 70, 12, '#000') +
     '<path d="M74 150 L74 176 M74 150 L100 150 M438 150 L438 176 M438 150 L412 150 M74 408 L74 382 M74 408 L100 408 M438 408 L438 382 M438 408 L412 408" stroke="#000" stroke-width="9" stroke-linecap="round"/>'),
    (Rc(120, 214, 58, 46, 8) + Rc(334, 214, 58, 46, 8), Rc(136, 230, 26, 14, 4, '#000') + Rc(350, 230, 26, 14, 4, '#000'))]))

def g_car_key(cx, cy, rot, s=1):
    b = f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">' + Rc(-13, 56, 26, 106, 4) + f'<path d="M12 92 L30 98 L22 112 L30 126 L12 132 Z" fill="{C}"/><path d="M-46 -80 Q0 -102 46 -80 L56 56 Q0 92 -56 56 Z" fill="{C}"/></g>'
    c = (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})"><path d="{star(0, -42, 17)}" fill="#000"/><circle cx="-18" cy="18" r="11" fill="#000"/><circle cx="18" cy="18" r="11" fill="#000"/>' +
         '<rect x="-13" y="40" width="26" height="10" rx="5" fill="#000"/><rect x="-16" y="58" width="32" height="8" fill="#000"/></g>')
    return b, c
def g_wallet(cx, cy, rot, s=1):
    b = f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">' + Rc(-38, -98, 76, 200, 16) + f'<circle cx="0" cy="-114" r="12" fill="none" stroke="{C}" stroke-width="8"/></g>'
    c = (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">' + Rc(-22, -72, 44, 88, 6, '#000') + Cc(-13, 42, 10, '#000') + Cc(13, 42, 10, '#000') + '</g>')
    return b, c
def g_wallet_screen(cx, cy, rot, s=1):
    return f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})"><path d="M-12 -14 L-3 -30 L4 -20 L12 -46" fill="none" stroke="{C}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/></g>'
def g_house_key(cx, cy, rot, s=1):
    b = (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">' + Rc(-12, 30, 24, 142, 4) +
         f'<path d="M12 108 L34 108 L34 122 L24 122 L24 136 L36 136 L36 152 L12 152 Z" fill="{C}"/><path d="M0 -70 L-54 -20 L-42 -20 L-42 38 L42 38 L42 -20 L54 -20 Z" fill="{C}"/></g>')
    c = f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})">' + Rc(-12, 6, 24, 32, 3, '#000') + '</g>'
    return b, c
def gap(svgpart): return svgpart.replace(f'fill="{C}"', 'fill="#000" stroke="#000" stroke-width="22" stroke-linejoin="round"').replace(f'stroke="{C}"', 'stroke="#000"')
hk = g_house_key(140, 330, -24, .88); wl = g_wallet(256, 338, 0, .88); ck = g_car_key(372, 332, 22, .88)
STRAP = 'M214 30 Q214 16 228 16 L284 16 Q298 16 298 30 L298 136 Q298 152 282 154 L230 154 Q214 152 214 136 Z'
G['portfolio_llavero_cuero'] = ('Llavero de cuero', glyphL([
    (hk[0], hk[1] + gap(wl[0])),
    (ck[0], ck[1] + gap(wl[0])),
    (wl[0], wl[1] + f'<path d="{STRAP}" fill="#000" stroke="#000" stroke-width="24"/><circle cx="256" cy="200" r="34" fill="none" stroke="#000" stroke-width="40"/>'),
    (g_wallet_screen(256, 338, 0, .88), ''),
    (f'<path d="{STRAP}" fill="{C}"/>' + Rc(226, 144, 60, 28, 8) + f'<circle cx="256" cy="200" r="34" fill="none" stroke="{C}" stroke-width="22"/>',
     Cc(256, 60, 17, '#000') + '<path d="M228 32 L228 138 M284 32 L284 138" stroke="#000" stroke-width="5" stroke-dasharray="10 8"/>'),
    (Cc(256, 60, 8), '')]))

for k, (n, s) in I.items(): open(f'fc_{k}.svg', 'w').write(s)
for k, (n, s) in G.items():
    open(f'gm_{k}_d.svg', 'w').write(s.replace('COLOR', '#1E1238'))
    open(f'gm_{k}_w.svg', 'w').write(s.replace('COLOR', '#FFFFFF'))
json.dump({k: v[0] for k, v in I.items()}, open('names.json', 'w'), ensure_ascii=False)
print(len(I), len(G))
