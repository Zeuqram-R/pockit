"""Glifos estilo juego, ronda 3 (siluetas sólidas con calados)."""
import math, json, sys
sys.path.insert(0, '../v3')
C = 'COLOR'
def star(cx, cy, r, ri=None, n=5, rot=-90):
    ri = ri or r * 0.45
    pts = [f'{cx + (r if i % 2 == 0 else ri)*math.cos(math.radians(rot + i*180/n)):.1f},{cy + (r if i % 2 == 0 else ri)*math.sin(math.radians(rot + i*180/n)):.1f}' for i in range(n*2)]
    return 'M' + ' L'.join(pts) + ' Z'
DOLLAR = 'M296 232 Q284 212 256 212 Q222 212 222 240 Q222 264 256 272 Q292 280 292 306 Q292 334 256 334 Q226 334 214 312 M256 190 L256 356'
def dollar(cx, cy, s, color='#000', w=34):
    return f'<g transform="translate({cx} {cy}) scale({s}) translate(-256 -273)"><path d="{DOLLAR}" fill="none" stroke="{color}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/></g>'
def glyph(body, cut=''):
    m = f'<defs><mask id="k"><rect width="512" height="512" fill="#fff"/>{cut}</mask></defs>' if cut else ''
    g = f'<g mask="url(#k)">{body}</g>' if cut else body
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">{m}{g}</svg>'

def glyphL(layers):
    defs = ''; g = ''
    for i, (body, cut) in enumerate(layers):
        if cut:
            defs += f'<mask id="m{i}"><rect width="512" height="512" fill="#fff"/>{cut}</mask>'
            g += f'<g mask="url(#m{i})">{body}</g>'
        else:
            g += body
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512"><defs>{defs}</defs>{g}</svg>'
def S(d, w, extra=''): return f'<path d="{d}" fill="none" stroke="{C}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round" {extra}/>'
def K(d, w): return f'<path d="{d}" fill="none" stroke="#000" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>'
def F(d): return f'<path d="{d}" fill="{C}"/>'
def KF(d): return f'<path d="{d}" fill="#000"/>'
def Rc(x, y, w, h, rx=0, fill=C, extra=''): return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" {extra}/>'
def Cc(cx, cy, r, fill=C): return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"/>'

I = {}
# ---------- PROGRESS ----------
I['progress_1_cofre'] = ('Cofre', glyph(
    F('M76 236 L76 190 Q76 100 256 100 Q436 100 436 190 L436 236 Z') + F('M76 256 L436 256 L436 424 Q436 444 416 444 L96 444 Q76 444 76 424 Z'),
    Rc(140, 100, 14, 344, 0, '#000') + Rc(358, 100, 14, 344, 0, '#000') +
    Rc(218, 220, 76, 92, 14, '#000') + Cc(256, 252, 13, '#fff') + Rc(249, 258, 14, 30, 3, '#fff') + Rc(76, 236, 360, 20, 0, '#000')))
I['progress_2_album'] = ('Álbum', glyph(
    F('M40 150 L250 184 L250 446 L40 412 Z') + F('M262 184 L472 150 L472 412 L262 446 Z'),
    f'<g transform="rotate(-6 128 236)">{Rc(88, 196, 84, 84, 14, "#000")}<path d="{star(130, 238, 26)}" fill="#fff"/></g>' +
    f'<g transform="rotate(6 160 340)">{Rc(118, 300, 84, 84, 14, "#000")}</g>' +
    f'<g transform="rotate(4 342 238)">{Rc(300, 196, 84, 84, 14, "#000")}{Cc(342, 238, 20, "#fff")}</g>' +
    Rc(302, 304, 84, 84, 14, 'none', 'stroke="#000" stroke-width="10" stroke-dasharray="14 12"')))
I['progress_3_pasaporte'] = ('Pasaporte', glyphL([
    ('<g transform="rotate(-8 230 256)">' + Rc(104, 60, 254, 360, 24) + '</g>',
     '<g transform="rotate(-8 230 256)">' + Rc(140, 60, 10, 360, 0, '#000') + Cc(250, 196, 62, '#000') + Rc(176, 294, 150, 20, 10, '#000') + Rc(196, 330, 110, 16, 8, '#000') + '</g>' + Cc(380, 372, 92, '#000')),
    ('<g transform="rotate(-8 230 256)">' + S('M250 236 Q246 200 258 176 M258 176 Q232 166 218 182 M258 176 Q282 160 298 176 M258 176 Q254 152 236 150', 12) + '</g>' + Cc(380, 372, 76),
     f'<circle cx="380" cy="372" r="54" fill="none" stroke="#000" stroke-width="9" stroke-dasharray="10 9"/><path d="{star(380, 376, 30)}" fill="#000"/>')]))
I['progress_4_barra'] = ('Barra de nivel', glyphL([
    (Rc(104, 186, 380, 140, 40) + F('M400 160 L440 108 L480 160 L456 160 L456 200 L424 200 L424 160 Z'), Rc(124, 206, 340, 100, 26, '#000') + Cc(112, 256, 108, '#000')),
    (Rc(140, 222, 200, 68, 16), K('M210 222 L210 290 M276 222 L276 290', 10)),
    (Cc(112, 256, 90), f'<path d="{star(112, 262, 48)}" fill="#000"/>')]))
I['progress_5_estrella'] = ('Estrella', glyphL([
    (f'<path d="{star(256, 268, 216, 98)}" fill="{C}"/>', f'<path d="{star(256, 272, 132, 60)}" fill="none" stroke="#000" stroke-width="14" stroke-linejoin="round"/>' + Cc(256, 272, 30, '#000'))]))

# ---------- CHALLENGES ----------
def cube_sil(cx, cy, s):
    k = 0.87
    return f'M{cx} {cy-s} L{cx+k*s} {cy-s/2} L{cx+k*s} {cy+s/2} L{cx} {cy+s} L{cx-k*s} {cy+s/2} L{cx-k*s} {cy-s/2} Z'
def cube_cut(cx, cy, s):
    k = 0.87
    return K(f'M{cx-k*s} {cy-s/2} L{cx} {cy} L{cx+k*s} {cy-s/2} M{cx} {cy} L{cx} {cy+s}', 12)
def pip(o, u, v, a, b, r=.11):
    return f'<g transform="matrix({u[0]} {u[1]} {v[0]} {v[1]} {o[0]} {o[1]})"><circle cx="{a}" cy="{b}" r="{r}" fill="#000"/></g>'
def dpips(cx, cy, s, faces):
    k = 0.87; out = ''
    for (a, b) in faces[0]: out += pip((cx-k*s, cy-s/2), (k*s, -s/2), (k*s, s/2), a, b)
    for (a, b) in faces[1]: out += pip((cx-k*s, cy-s/2), (k*s, s/2), (0, s), a, b)
    for (a, b) in faces[2]: out += pip((cx, cy), (k*s, -s/2), (0, s), a, b)
    return out
F1 = [(.5, .5)]; F2 = [(.27, .27), (.73, .73)]; F3 = [(.25, .25), (.5, .5), (.75, .75)]
F5 = [(.25, .25), (.75, .25), (.5, .5), (.25, .75), (.75, .75)]; F6 = [(.27, .22), (.27, .5), (.27, .78), (.73, .22), (.73, .5), (.73, .78)]; F4 = [(.27, .27), (.73, .27), (.27, .73), (.73, .73)]
I['challenges_1_dados'] = ('Dados', glyph(
    F(cube_sil(338, 180, 110)) + F(cube_sil(176, 318, 128)),
    cube_cut(338, 180, 110) + dpips(338, 180, 110, [F1, F3, F2]) + KF(cube_sil(176, 318, 146)) ).replace('</g></svg>',
    '</g>' + f'<g mask="url(#k2)">{F(cube_sil(176, 318, 128))}</g>' +
    f'<defs><mask id="k2"><rect width="512" height="512" fill="#fff"/>{cube_cut(176, 318, 128)}{dpips(176, 318, 128, [F5, F6, F4])}</mask></defs></svg>'))
I['challenges_2_cinturon'] = ('Cinturón', glyph(
    F('M24 236 Q256 300 488 236 L488 324 Q256 388 24 324 Z') + F('M256 136 L362 176 L384 280 L326 390 L256 422 L186 390 L128 280 L150 176 Z'),
    KF('M256 120 L376 166 L400 284 L334 406 L256 442 L178 406 L112 284 L136 166 Z')).replace('</g></svg>',
    '</g><g mask="url(#k2)">' + F('M256 156 L346 190 L366 280 L314 378 L256 404 L198 378 L146 280 L166 190 Z') + '</g>' +
    f'<defs><mask id="k2"><rect width="512" height="512" fill="#fff"/><path d="{star(256, 282, 64)}" fill="#000"/>' +
    K('M256 186 L328 212 L344 280 L302 356 L256 376 L210 356 L168 280 L184 212 Z', 10) + '</mask></defs></svg>'))
I['challenges_3_busqueda'] = ('Nivel de búsqueda', glyph(
    '<g transform="rotate(-4 256 260)">' + Rc(92, 60, 328, 396, 14) + '</g>',
    '<g transform="rotate(-4 256 260)">' + Rc(124, 96, 264, 44, 8, '#000') + Rc(146, 160, 220, 176, 10, '#000') +
    ''.join(f'<path d="{star(158+49*i, 392, 24)}" fill="#000"/>' for i in range(5)) + '</g>').replace('</g></svg>',
    '</g><g transform="rotate(-4 256 260)">' + F('M256 188 C292 188 306 216 302 248 C298 276 282 292 256 292 C230 292 214 276 210 248 C206 216 220 188 256 188 Z M184 336 Q186 300 234 296 L278 296 Q326 300 328 336 Z') +
    ''.join(f'<path d="{star(158+49*i, 392, 13)}" fill="{C}"/>' for i in range(3, 5)) + '</g></svg>'))
I['challenges_4_chile'] = ('Chile picante', glyph(
    F('M330 136 C396 148 424 220 394 302 C360 394 256 456 140 448 C100 445 86 418 116 406 C208 368 270 316 286 228 C292 182 298 144 330 136 Z') +
    F('M326 130 C316 96 336 70 370 60 L380 84 C356 92 350 108 356 126 Z') + F('M292 146 Q330 100 384 134 Q356 156 330 150 Q310 158 292 146 Z') +
    F('M118 152 C106 120 132 100 124 66 C154 90 168 120 148 152 Z') + F('M196 122 C188 98 210 84 206 56 C230 76 238 100 222 126 Z') + F('M78 240 C66 216 86 196 80 168 C108 188 116 214 100 242 Z'),
    K('M370 196 C382 236 368 290 334 334', 14) + K('M300 152 Q320 160 340 152', 10)))
I['challenges_5_nitro'] = ('Nitro', glyph(
    '<g transform="rotate(18 256 270)">' + Rc(160, 128, 192, 330, 76) + Rc(218, 84, 76, 50, 10) + Rc(192, 48, 128, 40, 16) + '</g>' +
    F('M110 96 C98 72 118 56 112 30 C138 50 148 74 130 100 Z'),
    '<g transform="rotate(18 256 270)">' + Rc(160, 230, 192, 12, 0, '#000') + Rc(160, 350, 192, 12, 0, '#000') +
    KF('M228 262 L266 262 L248 294 L282 294 L232 346 L246 310 L216 310 Z') + Rc(192, 160, 16, 240, 8, '#000') + '</g>'))

# ---------- ACTIVITIES: surf mejorado ----------
BOARD = 'M-196 0 C-196 -56 -110 -66 0 -66 C120 -66 192 -34 210 0 C192 34 120 66 0 66 C-110 66 -196 56 -196 0 Z'
T = '<g transform="translate(286 196) rotate(-28) scale(1.08)">'
I['activities_4_surf'] = ('Surf', glyphL([
    (F('M24 476 L24 334 C24 214 150 160 236 186 C292 204 314 250 300 292 C282 262 252 254 230 270 C210 288 220 316 250 326 Q330 344 400 326 Q448 314 488 330 L488 476 Z'),
     K('M60 400 Q130 380 200 400 T340 400 T480 400', 12) +
     T + f'<path d="{BOARD}" fill="#000" stroke="#000" stroke-width="36" stroke-linejoin="round"/><path d="M-150 58 L-104 62 L-148 108 Z" fill="#000" stroke="#000" stroke-width="30" stroke-linejoin="round"/></g>'),
    (T + f'<path d="{BOARD}" fill="{C}"/>' + F('M-150 58 L-104 62 L-148 108 Z') + '</g>',
     T + K('M-176 0 L-40 0 M40 0 L188 0', 9) + f'<path d="{star(0, 2, 34)}" fill="#000"/>' + '</g>'),
    (Cc(420, 300, 9) + Cc(444, 280, 7) + Cc(410, 270, 6), '')]))

# ---------- PROPERTIES: pin con casa mejorado ----------
I['properties_2_pin_casa'] = ('Pin con casa', glyphL([
    (F('M256 452 C256 452 90 296 90 196 C90 104 164 34 256 34 C348 34 422 104 422 196 C422 296 256 452 256 452 Z') +
     '<ellipse cx="256" cy="476" rx="96" ry="16" fill="COLOR" opacity=".5"/>', Cc(256, 194, 126, '#000')),
    (Rc(302, 108, 26, 58, 3) + F('M256 96 L146 190 L174 190 L174 292 L338 292 L338 190 L366 190 Z'),
     Rc(236, 222, 40, 70, 4, '#000') + Rc(190, 206, 34, 34, 3, '#000') + Rc(288, 206, 34, 34, 3, '#000') +
     K('M168 184 L256 110 L344 184', 10) + K('M206 206 L206 240 M190 223 L224 223 M304 206 L304 240 M288 223 L322 223', 0))]))

# ---------- PORTFOLIO ----------
I['portfolio_1_cerdito'] = ('Cerdito', glyph(
    '<ellipse cx="250" cy="290" rx="194" ry="142" fill="COLOR"/>' + F('M144 172 L122 100 L206 150 Z') +
    Rc(124, 380, 56, 72, 16) + Rc(316, 380, 56, 72, 16) + '<ellipse cx="444" cy="298" rx="46" ry="56" fill="COLOR"/>' +
    S('M60 296 Q30 276 40 250 Q56 236 66 258', 14) + Cc(256, 74, 54),
    Rc(204, 160, 96, 20, 10, '#000') + Cc(372, 246, 14, '#000') + Cc(434, 286, 8, '#000') + Cc(454, 308, 8, '#000') +
    K('M398 252 Q392 300 406 346', 10) + dollar(256, 76, 0.42, '#000', 30) + K('M120 250 Q138 196 196 180', 12)))
I['portfolio_2_reloj'] = ('Reloj', glyph(
    Rc(192, 30, 128, 132, 20) + Rc(192, 350, 128, 132, 20) + Cc(256, 256, 150) + Rc(398, 232, 34, 48, 8),
    K('M192 74 L320 74 M192 112 L320 112 M192 400 L320 400 M192 438 L320 438', 12) + Cc(256, 256, 112, '#000')).replace('</g></svg>',
    '</g>' + ''.join(f'<circle cx="{256+90*math.cos(math.radians(a)):.0f}" cy="{256+90*math.sin(math.radians(a)):.0f}" r="{11 if a % 90 == 0 else 7}" fill="{C}"/>' for a in range(0, 360, 30)) +
    S('M256 256 L256 182', 16) + S('M256 256 L314 290', 14) + Cc(256, 256, 18) + '</svg>'))
I['portfolio_3_carpeta'] = ('Carpeta', glyph(
    F('M52 126 L192 126 L220 158 L460 158 L460 210 L52 210 Z') +
    f'<g transform="rotate(-10 200 200)">{Rc(126, 96, 156, 176, 8)}</g>' + f'<g transform="rotate(8 332 190)">{Rc(258, 92, 156, 176, 8)}</g>' +
    F('M40 228 L472 228 L446 446 L66 446 Z'),
    KF('M30 210 L482 210 L482 228 L30 228 Z') +
    f'<g transform="rotate(-10 200 200)">{Rc(142, 112, 124, 112, 0, "#000")}</g>' + f'<g transform="rotate(8 332 190)">{Rc(274, 108, 124, 112, 0, "#000")}</g>' +
    Rc(200, 300, 112, 38, 10, '#000') + K('M90 262 L422 262', 12)).replace('</g></svg>',
    '</g><g transform="rotate(-10 200 200)">' + F('M204 132 L160 176 L172 176 L172 214 L236 214 L236 176 L248 176 Z') + '</g>' +
    '<g transform="rotate(8 332 190)">' + F('M290 204 L300 176 L330 168 L362 176 L382 204 Z') + Cc(310, 206, 11) + Cc(362, 206, 11) + '</g></svg>'))
I['portfolio_4_yate'] = ('Yate', glyph(
    F('M30 324 L482 324 L424 414 L96 414 Z') + F('M112 324 L156 240 L364 240 L418 324 Z') + F('M180 236 L208 176 L332 176 L356 236 Z') +
    S('M270 176 L270 100', 12) + F('M276 102 L340 120 L276 138 Z') + S('M30 452 Q100 428 170 452 T310 452 T482 452', 18),
    Rc(60, 344, 400, 16, 8, '#000') + KF('M174 262 L348 262 L370 306 L148 306 Z') + KF('M218 192 L322 192 L332 222 L208 222 Z')))
I['portfolio_5_llavero'] = ('Llavero', glyph(
    S('M256 100 m-62 0 a62 62 0 1 0 124 0 a62 62 0 1 0 -124 0', 28) +
    S('M206 150 L142 228 M256 164 L256 240 M306 150 L372 228', 12) +
    F('M140 214 L72 278 L88 278 L88 368 L192 368 L192 278 L208 278 Z') + Rc(206, 232, 100, 130, 28) +
    F('M240 360 L272 360 L272 452 L256 472 L240 452 Z') + F('M326 222 L428 222 L452 258 L428 408 L326 408 Z'),
    Rc(122, 316, 34, 52, 4, '#000') + Cc(256, 274, 16, '#000') + Cc(256, 320, 16, '#000') + Cc(426, 256, 10, '#000') +
    dollar(382, 322, 0.42, '#000', 30)))

json.dump({k: v[0] for k, v in I.items()}, open('gm_names.json', 'w'), ensure_ascii=False)
for k, (n, s) in I.items():
    open(f'gm_{k}_d.svg', 'w').write(s.replace('COLOR', '#1E1238'))
    open(f'gm_{k}_w.svg', 'w').write(s.replace('COLOR', '#FFFFFF'))
print(len(I))
