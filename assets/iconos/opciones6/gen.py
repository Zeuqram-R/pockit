"""Portfolio: bóveda geométrica y ledger ascendente (a color y estilo juego) + escudo original para el pasaporte."""
import math, json
src = open('../v4/fc.py').read().split('I = {}')[0]
ns = {}; exec(src, ns)
DEFS, O, P, L, HL, R, Ci, E, star, spark, shadow = (ns[k] for k in ['DEFS', 'O', 'P', 'L', 'HL', 'R', 'Ci', 'E', 'star', 'spark', 'shadow'])
EXTRA = '''<defs>
<linearGradient id="vault" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#6A3FD0"/><stop offset=".55" stop-color="#3A1E8C"/><stop offset="1" stop-color="#1E0F55"/></linearGradient>
<linearGradient id="vaultTop" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8A62E8"/><stop offset="1" stop-color="#5A34B8"/></linearGradient>
<linearGradient id="brass" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFE7A0"/><stop offset=".55" stop-color="#E9B44C"/><stop offset="1" stop-color="#A8701E"/></linearGradient>
<linearGradient id="ledger" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2FB9AC"/><stop offset="1" stop-color="#0E5F62"/></linearGradient>
<linearGradient id="paper" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFF8EE"/><stop offset="1" stop-color="#EADBC8"/></linearGradient>
<linearGradient id="shield" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFC56B"/><stop offset=".45" stop-color="#FF7A45"/><stop offset="1" stop-color="#C9307E"/></linearGradient>
</defs>'''
def svg(body): return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">{DEFS}{EXTRA}{body}</svg>'
def octagon(cx, cy, r, rot=22.5):
    pts = [f'{cx + r*math.cos(math.radians(rot + 45*i)):.1f},{cy + r*math.sin(math.radians(rot + 45*i)):.1f}' for i in range(8)]
    return 'M' + ' L'.join(pts) + ' Z'

I = {}
# ---------- 1) Bóveda geométrica (maletín-caja fuerte simétrico) ----------
I['portfolio_boveda'] = ('Bóveda geométrica', svg(
    shadow(256, 460, 190) +
    P('M196 108 L196 86 Q196 66 216 66 L296 66 Q316 66 316 86 L316 108', 'none', 30) +
    P('M196 108 L196 86 Q196 66 216 66 L296 66 Q316 66 316 86 L316 108', 'none', 0, 'stroke="url(#brass)" stroke-width="14"') +
    R(64, 104, 384, 330, 'url(#vault)', 46) +
    P('M64 150 Q64 104 110 104 L402 104 Q448 104 448 150 L448 176 L64 176 Z', 'url(#vaultTop)', 0, 'opacity=".55"') +
    R(64, 104, 384, 330, 'none', 46) +
    L('M80 176 L432 176', O, 6, .55) +
    # esquineras doradas
    ''.join(P(d, 'url(#brass)', 9) for d in ['M64 160 L64 150 Q64 104 110 104 L120 104 L120 128 L88 128 L88 160 Z',
                                             'M448 160 L448 150 Q448 104 402 104 L392 104 L392 128 L424 128 L424 160 Z',
                                             'M64 378 L64 388 Q64 434 110 434 L120 434 L120 410 L88 410 L88 378 Z',
                                             'M448 378 L448 388 Q448 434 402 434 L392 434 L392 410 L424 410 L424 378 Z']) +
    # dial octogonal
    P(octagon(256, 296, 104), 'url(#brass)', 12) + P(octagon(256, 296, 78), '#2A1468', 8) +
    P(octagon(256, 296, 52), 'url(#brass)', 8) +
    ''.join(L(f'M{256+54*math.cos(math.radians(a)):.0f} {296+54*math.sin(math.radians(a)):.0f} L{256+76*math.cos(math.radians(a)):.0f} {296+76*math.sin(math.radians(a)):.0f}', '#FFE08A', 6) for a in range(0, 360, 45)) +
    Ci(256, 296, 18, 'url(#pink)', 7) +
    HL('M100 200 L100 380', 8, .25) + HL('M150 120 L300 120', 6, .35) + spark(452, 86)))

# ---------- 2) Ledger / portafolio con línea ascendente ----------
I['portfolio_ledger'] = ('Ledger ascendente', svg(
    shadow(256, 462, 190) +
    P('M78 96 Q78 76 98 76 L196 76 L222 102 L414 102 Q434 102 434 122 L434 420 Q434 440 414 440 L98 440 Q78 440 78 420 Z', 'url(#ledger)', 12) +
    R(108, 136, 296, 274, 'url(#paper)', 16, 10) +
    L('M140 214 L372 214 M140 274 L372 274 M140 334 L372 334', '#C9B8A0', 5, .9) +
    L('M140 160 L140 382 L380 382', '#8E7BA8', 6, .8) +
    L('M150 362 L216 318 L262 336 L352 238', O, 20) + L('M150 362 L216 318 L262 336 L352 238', 'url(#gold)', 10) +
    Ci(216, 318, 11, '#FFF4E6', 6) + Ci(262, 336, 11, '#FFF4E6', 6) +
    P('M352 206 L382 238 L352 270 L322 238 Z', 'url(#pink)', 9) +
    R(78, 230, 30, 64, 'url(#brass)', 8, 9) + HL('M120 150 L240 150', 6, .4) + spark(452, 82)))

# ---------- 3) Pasaporte con escudo original ----------
SHIELD = 'M0 -70 Q34 -58 62 -62 Q66 10 46 42 Q26 70 0 82 Q-26 70 -46 42 Q-66 10 -62 -62 Q-34 -58 0 -70 Z'
def flamingo(cx, cy, s, fill, line=O, lw=5):
    g = f'<g transform="translate({cx} {cy}) scale({s})">'
    g += f'<path d="M6 30 L6 74 M10 30 L24 50 L8 56" fill="none" stroke="{line}" stroke-width="{lw}" stroke-linecap="round" stroke-linejoin="round"/>'
    g += f'<path d="M-30 14 C-34 -6 -6 -14 22 -2 C40 6 44 22 30 30 C10 40 -24 36 -30 14 Z" fill="{fill}" stroke="{line}" stroke-width="{lw}" stroke-linejoin="round"/>'
    g += f'<path d="M-24 10 C-46 -6 -20 -26 -26 -50 C-30 -66 -12 -76 -2 -66" fill="none" stroke="{line}" stroke-width="{lw+10}" stroke-linecap="round"/>'
    g += f'<path d="M-24 10 C-46 -6 -20 -26 -26 -50 C-30 -66 -12 -76 -2 -66" fill="none" stroke="{fill}" stroke-width="10" stroke-linecap="round"/>'
    g += f'<circle cx="-4" cy="-66" r="9" fill="{fill}" stroke="{line}" stroke-width="{lw}"/><path d="M4 -70 L18 -64 L14 -52 L6 -58 Z" fill="{line}"/>'
    return g + '</g>'
I['pasaporte_escudo'] = ('Pasaporte con escudo', svg(
    shadow(250, 456, 170) +
    '<g transform="rotate(-8 240 260)">' +
    R(112, 70, 250, 350, 'url(#teal)', 22) + R(112, 70, 40, 350, 'url(#tealD)', 0, 0, 'opacity=".9"') + R(112, 70, 250, 350, 'none', 22) +
    f'<g transform="translate(250 196) scale(1.05)"><clipPath id="sh"><path d="{SHIELD}"/></clipPath><path d="{SHIELD}" fill="url(#shield)"/>' +
    '<g clip-path="url(#sh)">' + ''.join(f'<rect x="-70" y="{y}" width="140" height="6" fill="#2B1E92" opacity=".35"/>' for y in (22, 36, 50, 64)) + '</g>' +
    f'<path d="{star(-34, -40, 12)}" fill="#FFF4E6"/>' + f'<path d="{SHIELD}" fill="none" stroke="{O}" stroke-width="9" stroke-linejoin="round"/></g>' +
    flamingo(258, 204, .62, 'url(#pink)', O, 6) +
    R(176, 300, 148, 18, '#FFE08A', 9, 6) + R(196, 334, 108, 14, '#FFE08A', 7, 5, 'opacity=".8"') +
    HL('M140 100 L140 390', 6, .35) + '</g>' +
    '<g transform="rotate(14 370 360)">' + Ci(372, 362, 66, 'url(#pink)', 10, 'opacity=".96"') + Ci(372, 362, 46, 'none', 6, 'stroke-dasharray="8 8"') +
    f'<path d="{star(372, 362, 26)}" fill="#FFF4E6" stroke="{O}" stroke-width="5" stroke-linejoin="round"/></g>' + spark(436, 96)))

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
G = {}
G['portfolio_boveda'] = ('Bóveda geométrica', glyphL([
    (f'<path d="M196 110 L196 86 Q196 64 218 64 L294 64 Q316 64 316 86 L316 110" fill="none" stroke="{C}" stroke-width="26"/>' + Rc(60, 102, 392, 336, 48),
     '<path d="M80 176 L432 176" stroke="#000" stroke-width="10"/>' + f'<path d="{octagon(256, 298, 112)}" fill="#000"/>' +
     '<path d="M86 132 L86 156 M86 132 L110 132 M426 132 L426 156 M426 132 L402 132 M86 408 L86 384 M86 408 L110 408 M426 408 L426 384 M426 408 L402 408" stroke="#000" stroke-width="9" stroke-linecap="round"/>'),
    (f'<path d="{octagon(256, 298, 98)}" fill="{C}"/>', f'<path d="{octagon(256, 298, 74)}" fill="none" stroke="#000" stroke-width="12"/>' + Cc(256, 298, 22, '#000') +
     ''.join(f'<path d="M{256+36*math.cos(math.radians(a)):.0f} {298+36*math.sin(math.radians(a)):.0f} L{256+60*math.cos(math.radians(a)):.0f} {298+60*math.sin(math.radians(a)):.0f}" stroke="#000" stroke-width="8" stroke-linecap="round"/>' for a in range(0, 360, 45)))]))
G['portfolio_ledger'] = ('Ledger ascendente', glyphL([
    (f'<path d="M74 94 Q74 72 96 72 L196 72 L224 100 L416 100 Q438 100 438 122 L438 422 Q438 444 416 444 L96 444 Q74 444 74 422 Z" fill="{C}"/>',
     Rc(106, 134, 300, 278, 18, '#000')),
    (Rc(124, 152, 264, 242, 10), '<path d="M140 214 L372 214 M140 274 L372 274 M140 334 L372 334" stroke="#000" stroke-width="5" opacity=".55"/>' +
     '<path d="M150 362 L216 318 L262 336 L352 238" fill="none" stroke="#000" stroke-width="20" stroke-linecap="round" stroke-linejoin="round"/>' +
     '<path d="M352 202 L386 238 L352 274 L318 238 Z" fill="#000"/>'),
    (Rc(70, 228, 34, 68, 8), '')]))
G['pasaporte_escudo'] = ('Pasaporte con escudo', glyphL([
    ('<g transform="rotate(-8 230 256)">' + Rc(104, 60, 254, 360, 24) + '</g>',
     '<g transform="rotate(-8 230 256)">' + Rc(140, 60, 10, 360, 0, '#000') + f'<path d="{SHIELD}" transform="translate(250 196) scale(1.18)" fill="#000"/>' +
     Rc(176, 300, 150, 20, 10, '#000') + Rc(196, 336, 110, 16, 8, '#000') + '</g>' + Cc(380, 372, 92, '#000')),
    ('<g transform="rotate(-8 230 256)">' + f'<path d="{SHIELD}" transform="translate(250 196) scale(1.02)" fill="{C}"/>' + '</g>' + Cc(380, 372, 76),
     '<g transform="rotate(-8 230 256)">' + flamingo(258, 204, .6, '#000', '#000', 6) + '</g>' +
     f'<circle cx="380" cy="372" r="54" fill="none" stroke="#000" stroke-width="9" stroke-dasharray="10 9"/><path d="{star(380, 376, 30)}" fill="#000"/>')]))

for k, (n, s) in I.items(): open(f'fc_{k}.svg', 'w').write(s)
for k, (n, s) in G.items():
    open(f'gm_{k}_d.svg', 'w').write(s.replace('COLOR', '#1E1238'))
    open(f'gm_{k}_w.svg', 'w').write(s.replace('COLOR', '#FFFFFF'))
json.dump({k: v[0] for k, v in I.items()}, open('names.json', 'w'), ensure_ascii=False)
print(len(I), len(G))
