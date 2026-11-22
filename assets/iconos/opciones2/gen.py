import math, json, os
# Glifos estilo juego (siluetas sólidas con calados), 512x512. COLOR se reemplaza al renderizar.
C = 'COLOR'

def star(cx, cy, r, ri=None, n=5, rot=-90):
    ri = ri or r * 0.45
    pts = []
    for i in range(n * 2):
        rr = r if i % 2 == 0 else ri
        a = math.radians(rot + i * 180 / n)
        pts.append(f'{cx + rr*math.cos(a):.1f},{cy + rr*math.sin(a):.1f}')
    return 'M' + ' L'.join(pts) + ' Z'

def burst(cx, cy, r1, r2, n=12):
    return star(cx, cy, r1, r2, n, -90)

def hexagon(cx, cy, r):
    pts = [f'{cx + r*math.cos(math.radians(-90+60*i)):.1f},{cy + r*math.sin(math.radians(-90+60*i)):.1f}' for i in range(6)]
    return 'M' + ' L'.join(pts) + ' Z'

DOLLAR = 'M296 232 Q284 212 256 212 Q222 212 222 240 Q222 264 256 272 Q292 280 292 306 Q292 334 256 334 Q226 334 214 312 M256 190 L256 356'
def dollar(cx, cy, s, color='#000', w=34):
    return f'<g transform="translate({cx} {cy}) scale({s}) translate(-256 -273)"><path d="{DOLLAR}" fill="none" stroke="{color}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/></g>'

def glyph(body, cut=''):
    m = f'<defs><mask id="k"><rect width="512" height="512" fill="#fff"/>{cut}</mask></defs>' if cut else ''
    g = f'<g mask="url(#k)">{body}</g>' if cut else body
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">{m}{g}</svg>'

def S(d, w, extra=''):  # trazo de color
    return f'<path d="{d}" fill="none" stroke="{C}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round" {extra}/>'
def K(d, w):  # trazo calado
    return f'<path d="{d}" fill="none" stroke="#000" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>'
def F(d): return f'<path d="{d}" fill="{C}"/>'
def KF(d): return f'<path d="{d}" fill="#000"/>'

I = {}
# ---------------- PROGRESS ----------------
I['progress_1_cumbre'] = ('Cumbre', glyph(
    F('M48 444 L196 196 L250 276 L318 150 L464 444 Z') + S('M318 156 L318 54', 16) + F('M326 50 L408 76 L326 104 Z'),
    K('M262 248 L288 222 L318 250 L346 222 L370 246', 16)))
I['progress_2_estrellas'] = ('Estrellas', glyph(
    F(star(108, 380, 68)) + F(star(256, 286, 86)) + F(star(404, 176, 104))))
I['progress_3_anillo'] = ('Anillo', glyph(
    S('M256 100 A156 156 0 1 1 100 256', 58) +
    S('M100 256 A156 156 0 0 1 256 100', 20, 'stroke-dasharray="1 38"') + F(star(256, 262, 82))))
I['progress_4_escalera'] = ('Escalera', glyph(
    F('M60 450 L60 372 L162 372 L162 290 L264 290 L264 208 L366 208 L366 126 L456 126 L456 450 Z') +
    S('M72 262 L236 98', 28) + F('M196 72 L270 64 L262 138 Z')))
I['progress_5_corona'] = ('Corona', glyph(
    F('M78 176 L166 286 L256 124 L346 286 L434 176 L400 382 L112 382 Z') +
    f'<circle cx="78" cy="168" r="26" fill="{C}"/><circle cx="256" cy="112" r="28" fill="{C}"/><circle cx="434" cy="168" r="26" fill="{C}"/>' +
    '<rect x="108" y="398" width="296" height="48" rx="12" fill="COLOR"/>',
    KF('M256 290 L284 322 L256 354 L228 322 Z') + '<circle cx="166" cy="334" r="16" fill="#000"/><circle cx="346" cy="334" r="16" fill="#000"/>'))

# ---------------- CHALLENGES ----------------
I['challenges_1_llama'] = ('Llama', glyph(
    F('M256 48 C298 136 404 188 404 312 C404 404 338 460 256 460 C174 460 108 404 108 312 C108 240 156 196 174 146 C194 206 220 228 238 234 C232 166 236 104 256 48 Z'),
    KF('M256 290 C286 330 316 352 316 386 C316 416 290 434 256 434 C222 434 196 416 196 386 C196 352 226 330 256 290 Z')))
I['challenges_2_guante'] = ('Guante', glyph(
    F('M146 132 Q146 66 228 66 L328 66 Q418 66 418 162 L418 276 Q418 340 364 352 L364 362 L188 362 L188 326 Q132 304 132 238 Z') +
    '<rect x="178" y="376" width="196" height="76" rx="16" fill="COLOR"/>',
    K('M140 236 Q196 222 246 262', 16) + K('M232 400 L320 400 M232 428 L320 428', 10)))
I['challenges_3_explosion'] = ('Explosión', glyph(
    F(burst(256, 256, 214, 140, 12)),
    '<rect x="230" y="150" width="52" height="138" rx="22" fill="#000"/><circle cx="256" cy="340" r="28" fill="#000"/>'))
I['challenges_4_calavera'] = ('Calavera', glyph(
    F('M256 62 C148 62 86 136 86 228 C86 290 118 332 160 352 L160 414 Q160 446 192 446 L320 446 Q352 446 352 414 L352 352 C394 332 426 290 426 228 C426 136 364 62 256 62 Z'),
    '<ellipse cx="188" cy="238" rx="46" ry="52" fill="#000"/><ellipse cx="324" cy="238" rx="46" ry="52" fill="#000"/>' +
    KF('M256 298 L280 344 L232 344 Z') + K('M214 392 L214 446 M256 392 L256 446 M298 392 L298 446', 14)))
I['challenges_5_rayo'] = ('Rayo', glyph(
    F(hexagon(256, 256, 214)),
    KF('M290 104 L166 286 L246 286 L218 414 L350 222 L268 222 L304 104 Z')))

# ---------------- ACTIVITIES ----------------
I['activities_1_pesa'] = ('Pesa', glyph(
    '<g transform="rotate(-32 256 256)">' +
    '<rect x="120" y="234" width="272" height="44" rx="12" fill="COLOR"/>' +
    '<rect x="62" y="166" width="52" height="180" rx="16" fill="COLOR"/><rect x="124" y="132" width="58" height="248" rx="16" fill="COLOR"/>' +
    '<rect x="330" y="132" width="58" height="248" rx="16" fill="COLOR"/><rect x="398" y="166" width="52" height="180" rx="16" fill="COLOR"/></g>'))
I['activities_2_bolos'] = ('Bolos', glyph(
    F('M196 52 C230 52 244 84 236 126 C230 158 216 168 220 200 C226 242 270 282 270 352 C270 414 240 454 196 454 C152 454 122 414 122 352 C122 282 166 242 172 200 C176 168 162 158 156 126 C148 84 162 52 196 52 Z') +
    '<circle cx="370" cy="372" r="88" fill="COLOR"/>',
    K('M164 150 Q196 160 228 150 M168 178 Q196 186 224 178', 12) +
    '<circle cx="344" cy="334" r="15" fill="#000"/><circle cx="384" cy="326" r="15" fill="#000"/><circle cx="364" cy="368" r="15" fill="#000"/>'))
I['activities_3_raqueta'] = ('Raqueta', glyph(
    '<g transform="rotate(38 300 200)">' +
    f'<ellipse cx="300" cy="186" rx="104" ry="134" fill="none" stroke="{C}" stroke-width="34"/>' +
    '<clipPath id="h"><ellipse cx="300" cy="186" rx="90" ry="120"/></clipPath>' +
    f'<g clip-path="url(#h)" stroke="{C}" stroke-width="9">' +
    ''.join(f'<path d="M{x} 40 L{x} 330"/>' for x in range(222, 390, 26)) +
    ''.join(f'<path d="M180 {y} L420 {y}"/>' for y in range(78, 310, 26)) + '</g>' +
    f'<path d="M300 320 L300 470" stroke="{C}" stroke-width="44" stroke-linecap="round"/></g>' +
    '<circle cx="112" cy="128" r="54" fill="COLOR"/>',
    K('M70 104 Q112 132 154 104 M70 152 Q112 124 154 152', 10)))
I['activities_4_surf'] = ('Surf', glyph(
    F('M118 446 C78 372 186 144 352 58 C420 26 446 62 414 126 C338 278 200 424 118 446 Z'),
    K('M150 408 C230 330 330 190 388 92', 14) + KF('M262 300 L300 330 L238 344 Z')))
I['activities_5_rampa'] = ('Rampa', glyph(
    F('M44 452 L262 452 L262 330 Z') + F('M338 452 L466 452 L466 368 Z') +
    S('M268 300 Q358 118 452 300', 18, 'stroke-dasharray="2 34"') + F(star(358, 150, 62))))

# ---------------- PROPERTIES ----------------
win = lambda xs, ys, w=22, h=28: ''.join(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="4" fill="#000"/>' for x in xs for y in ys)
I['properties_1_skyline'] = ('Skyline', glyph(
    '<rect x="50" y="250" width="96" height="200" rx="6" fill="COLOR"/><rect x="158" y="116" width="104" height="334" rx="6" fill="COLOR"/>' +
    '<rect x="203" y="62" width="14" height="60" fill="COLOR"/><rect x="274" y="186" width="86" height="264" rx="6" fill="COLOR"/>' +
    '<rect x="372" y="290" width="90" height="160" rx="6" fill="COLOR"/>',
    win([80, 110], [280, 330, 380]) + win([182, 220], [150, 205, 260, 315, 370]) + win([296, 330], [220, 280, 340]) + win([398, 430], [320, 372])))
I['properties_2_pin_casa'] = ('Pin con casa', glyph(
    F('M256 472 C256 472 96 300 96 206 C96 116 168 44 256 44 C344 44 416 116 416 206 C416 300 256 472 256 472 Z') +
    '<rect x="240" y="244" width="32" height="50" rx="4" fill="COLOR"/>',
    KF('M256 112 L172 190 L340 190 Z') + '<rect x="188" y="186" width="136" height="108" fill="#000"/>'))
I['properties_3_se_vende'] = ('Letrero', glyph(
    '<rect x="92" y="56" width="32" height="396" rx="8" fill="COLOR"/><rect x="92" y="74" width="300" height="28" rx="8" fill="COLOR"/>' +
    S('M196 102 L196 148 M348 102 L348 148', 10) + '<rect x="150" y="144" width="250" height="160" rx="16" fill="COLOR"/>' +
    '<rect x="56" y="440" width="108" height="20" rx="8" fill="COLOR"/>',
    dollar(275, 224, 0.62)))
I['properties_4_buzon'] = ('Buzón', glyph(
    F('M104 222 Q104 128 198 128 L356 128 Q446 128 446 222 L446 334 L104 334 Z') +
    '<rect x="236" y="334" width="46" height="118" fill="COLOR"/><rect x="398" y="56" width="18" height="150" rx="6" fill="COLOR"/>' +
    '<rect x="410" y="56" width="62" height="44" rx="6" fill="COLOR"/>',
    K('M152 136 Q132 230 152 328', 14) + '<rect x="378" y="134" width="56" height="80" fill="#000"/>'))
I['properties_5_casa_palmera'] = ('Casa y palmera', glyph(
    S('M120 452 Q112 320 152 196', 30) +
    S('M152 196 Q96 150 44 196', 26) + S('M152 196 Q118 112 62 104', 26) + S('M152 196 Q184 112 244 118', 26) + S('M152 196 Q214 170 236 224', 24) +
    F('M222 260 L342 164 L462 260 Z') + '<rect x="244" y="250" width="196" height="200" fill="COLOR"/>',
    '<rect x="318" y="338" width="48" height="112" rx="4" fill="#000"/><rect x="266" y="286" width="40" height="40" rx="4" fill="#000"/><rect x="378" y="286" width="40" height="40" rx="4" fill="#000"/>'))

# ---------------- GARAGE ----------------
spokes = ''.join(f'<circle cx="{256+52*math.cos(math.radians(a)):.1f}" cy="{256+52*math.sin(math.radians(a)):.1f}" r="20" fill="#000"/>' for a in range(-90, 270, 72))
tread = ''.join(f'<path d="M{256+178*math.cos(math.radians(a)):.1f} {256+178*math.sin(math.radians(a)):.1f} L{256+214*math.cos(math.radians(a)):.1f} {256+214*math.sin(math.radians(a)):.1f}" stroke="#000" stroke-width="18" stroke-linecap="round"/>' for a in range(0, 360, 24))
I['garage_1_llanta'] = ('Llanta', glyph(
    '<circle cx="256" cy="256" r="204" fill="COLOR"/>',
    '<circle cx="256" cy="256" r="122" fill="none" stroke="#000" stroke-width="22"/>' + spokes + '<circle cx="256" cy="256" r="14" fill="#000"/>' + tread))
I['garage_2_gasolina'] = ('Gasolina', glyph(
    '<rect x="96" y="80" width="220" height="364" rx="22" fill="COLOR"/><rect x="74" y="426" width="264" height="34" rx="10" fill="COLOR"/>' +
    S('M316 176 L374 176 Q396 176 396 198 L396 362 Q396 396 422 396 Q448 396 448 362 L448 212', 22) +
    '<rect x="424" y="132" width="44" height="92" rx="12" fill="COLOR"/>',
    '<rect x="132" y="122" width="148" height="96" rx="10" fill="#000"/>' + KF('M206 268 C226 300 246 318 246 344 C246 370 228 388 206 388 C184 388 166 370 166 344 C166 318 186 300 206 268 Z')))
I['garage_3_carro_frente'] = ('Carro de frente', glyph(
    F('M158 104 L354 104 L408 222 L104 222 Z') + '<rect x="60" y="206" width="392" height="156" rx="34" fill="COLOR"/>' +
    '<rect x="84" y="344" width="78" height="92" rx="16" fill="COLOR"/><rect x="350" y="344" width="78" height="92" rx="16" fill="COLOR"/>',
    KF('M178 130 L334 130 L370 206 L142 206 Z') + '<circle cx="126" cy="282" r="30" fill="#000"/><circle cx="386" cy="282" r="30" fill="#000"/>' +
    '<rect x="196" y="262" width="120" height="44" rx="10" fill="#000"/>'))
I['garage_4_cono'] = ('Cono', glyph(
    F('M228 64 L284 64 L384 400 L128 400 Z') + '<rect x="64" y="396" width="384" height="56" rx="14" fill="COLOR"/>',
    KF('M206 170 L306 170 L320 220 L192 220 Z') + KF('M176 270 L336 270 L352 324 L160 324 Z')))
I['garage_5_placa'] = ('Placa', glyph(
    '<rect x="40" y="132" width="432" height="248" rx="34" fill="COLOR"/>',
    '<rect x="64" y="156" width="384" height="200" rx="20" fill="none" stroke="#000" stroke-width="10"/>' +
    '<circle cx="104" cy="186" r="12" fill="#000"/><circle cx="408" cy="186" r="12" fill="#000"/>' +
    '<text x="256" y="318" text-anchor="middle" font-family="DejaVu Sans" font-weight="bold" font-size="104" fill="#000">VC·86</text>' +
    '<rect x="176" y="200" width="160" height="16" rx="8" fill="#000"/>'))

# ---------------- PORTFOLIO ----------------
def coins(x, y0, n, w=160, h=36):
    out = ''
    for i in range(n):
        out += f'<rect x="{x}" y="{y0 - i*(h+8)}" width="{w}" height="{h}" rx="14" fill="COLOR"/>'
    return out
I['portfolio_1_monedas'] = ('Monedas', glyph(
    coins(56, 414, 5) + coins(236, 414, 3) + '<circle cx="376" cy="170" r="94" fill="COLOR"/>',
    dollar(376, 172, 0.72)))
I['portfolio_2_fajo'] = ('Fajo', glyph(
    '<rect x="88" y="104" width="360" height="200" rx="18" fill="COLOR" transform="rotate(-8 268 204)"/>' +
    '<rect x="52" y="214" width="408" height="206" rx="18" fill="COLOR"/>',
    '<rect x="64" y="198" width="408" height="16" fill="#000" transform="rotate(-8 268 204)"/>' +
    '<rect x="64" y="226" width="384" height="182" rx="12" fill="none" stroke="#000" stroke-width="10"/>' +
    '<circle cx="256" cy="317" r="62" fill="#000"/>' + dollar(256, 318, 0.5, '#fff', 34) +
    '<rect x="96" y="300" width="40" height="34" rx="6" fill="#000"/><rect x="376" y="300" width="40" height="34" rx="6" fill="#000"/>'))
I['portfolio_3_diamante'] = ('Diamante', glyph(
    F('M146 104 L366 104 L456 212 L256 444 L56 212 Z'),
    K('M60 212 L452 212', 14) + K('M146 104 L200 212 L256 104 L312 212 L366 104', 12) + K('M200 212 L256 440 L312 212', 12)))
I['portfolio_4_lingotes'] = ('Lingotes', glyph(
    F('M52 446 L84 360 L234 360 L256 446 Z') + F('M262 446 L282 360 L430 360 L462 446 Z') + F('M152 346 L184 260 L330 260 L356 346 Z') +
    F(star(300, 140, 46, 16, 4, -90)) + F(star(196, 176, 26, 9, 4, -90)),
    K('M100 380 L220 380', 10) + K('M300 380 L418 380', 10) + K('M200 280 L316 280', 10)))
I['portfolio_5_tarjeta'] = ('Tarjeta', glyph(
    '<rect x="44" y="118" width="424" height="276" rx="34" fill="COLOR"/>',
    '<rect x="44" y="170" width="424" height="54" fill="#000"/><rect x="92" y="258" width="78" height="58" rx="10" fill="#000"/>' +
    '<rect x="92" y="340" width="176" height="20" rx="10" fill="#000"/><circle cx="374" cy="320" r="34" fill="none" stroke="#000" stroke-width="12"/><circle cx="414" cy="320" r="34" fill="none" stroke="#000" stroke-width="12"/>'))

json.dump({k: v for k, v in I.items()}, open('icons.json', 'w'), ensure_ascii=False)
for k, (name, svg) in I.items():
    open(f'{k}_d.svg', 'w').write(svg.replace('COLOR', '#1E1238'))
    open(f'{k}_w.svg', 'w').write(svg.replace('COLOR', '#FFFFFF'))
print(len(I))
