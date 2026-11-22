"""Íconos a color (mismo estilo que las pestañas de Pockit: contorno oscuro grueso, sombreado, 3/4)."""
import math, json
O = '#140A24'
DEFS = '''<defs>
<linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFE08A"/><stop offset="1" stop-color="#F2A93B"/></linearGradient>
<linearGradient id="goldD" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#E0A43A"/><stop offset="1" stop-color="#B87420"/></linearGradient>
<linearGradient id="pink" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FF7AB0"/><stop offset="1" stop-color="#E02470"/></linearGradient>
<linearGradient id="pinkD" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#C21C60"/><stop offset="1" stop-color="#8E1046"/></linearGradient>
<linearGradient id="purp" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#A452C2"/><stop offset="1" stop-color="#5E2478"/></linearGradient>
<linearGradient id="purpD" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#5A2370"/><stop offset="1" stop-color="#3A1450"/></linearGradient>
<linearGradient id="teal" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6FE6D7"/><stop offset="1" stop-color="#22A99C"/></linearGradient>
<linearGradient id="tealD" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1E9C90"/><stop offset="1" stop-color="#11695F"/></linearGradient>
<linearGradient id="sun" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFC56B"/><stop offset="0.5" stop-color="#FF7A45"/><stop offset="1" stop-color="#FF3E8A"/></linearGradient>
<linearGradient id="sunH" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#FFC56B"/><stop offset="0.55" stop-color="#FF7A45"/><stop offset="1" stop-color="#FF3E8A"/></linearGradient>
<linearGradient id="cream" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFF8EE"/><stop offset="1" stop-color="#EBD3B8"/></linearGradient>
<linearGradient id="red" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FF6A5A"/><stop offset="1" stop-color="#C81E3A"/></linearGradient>
<linearGradient id="green" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7FE08A"/><stop offset="1" stop-color="#2E9E4F"/></linearGradient>
<linearGradient id="steel" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#E8E2F2"/><stop offset="1" stop-color="#9C93B5"/></linearGradient>
<linearGradient id="dark" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3A2A5C"/><stop offset="1" stop-color="#1E1238"/></linearGradient>
<linearGradient id="wood" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#C77A4A"/><stop offset="1" stop-color="#8A4A2A"/></linearGradient>
<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#9EF2EA"/><stop offset="1" stop-color="#3BB8D0"/></linearGradient>
</defs>'''

def st(w=12): return f'stroke="{O}" stroke-width="{w}" stroke-linejoin="round" stroke-linecap="round"'
def sa(w, extra):
    a = st(w)
    if 'stroke=' in extra: a = a.replace(f'stroke="{O}" ', '')
    if 'stroke-width=' in extra: a = a.replace(f'stroke-width="{w}" ', '')
    return a + ' ' + extra
def P(d, fill, w=12, extra=''): return f'<path d="{d}" fill="{fill}" {sa(w, extra)}/>'
def L(d, color, w, op=1): return f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round" opacity="{op}"/>'
def HL(d, w=10, op=.65): return L(d, '#FFFFFF', w, op)
def R(x, y, w, h, fill, rx=0, sw=12, extra=''): return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" {sa(sw, extra)}/>'
def Ci(cx, cy, r, fill, sw=12, extra=''): return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}" {sa(sw, extra)}/>'
def E(cx, cy, rx, ry, fill, sw=12, extra=''): return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{fill}" {sa(sw, extra)}/>'
def star(cx, cy, r, ri=None, n=5, rot=-90):
    ri = ri or r * 0.45
    pts = [f'{cx + (r if i % 2 == 0 else ri)*math.cos(math.radians(rot + i*180/n)):.1f},{cy + (r if i % 2 == 0 else ri)*math.sin(math.radians(rot + i*180/n)):.1f}' for i in range(n*2)]
    return 'M' + ' L'.join(pts) + ' Z'
def spark(x, y, s=1): return f'<path d="M{x} {y-34*s} L{x+8*s} {y-8*s} L{x+34*s} {y} L{x+8*s} {y+8*s} L{x} {y+34*s} L{x-8*s} {y+8*s} L{x-34*s} {y} L{x-8*s} {y-8*s} Z" fill="#FFE08A" {st(7)}/>'
def shadow(cx, cy, rx, ry=18): return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="#0E0818" opacity=".28"/>'
DOLLAR = 'M296 232 Q284 212 256 212 Q222 212 222 240 Q222 264 256 272 Q292 280 292 306 Q292 334 256 334 Q226 334 214 312 M256 190 L256 356'
def dollar(cx, cy, s, color, w=34):
    return f'<g transform="translate({cx} {cy}) scale({s}) translate(-256 -273)"><path d="{DOLLAR}" fill="none" stroke="{color}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/></g>'
def svg(body): return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">{DEFS}{body}</svg>'

def cube(cx, cy, s, top, left, right):
    k = 0.87
    t = f'M{cx} {cy-s} L{cx+k*s} {cy-s/2} L{cx} {cy} L{cx-k*s} {cy-s/2} Z'
    l = f'M{cx-k*s} {cy-s/2} L{cx} {cy} L{cx} {cy+s} L{cx-k*s} {cy+s/2} Z'
    r = f'M{cx} {cy} L{cx+k*s} {cy-s/2} L{cx+k*s} {cy+s/2} L{cx} {cy+s} Z'
    return P(l, left, 10) + P(r, right, 10) + P(t, top, 10)
def pips(o, u, v, pts, color, r=0.11):
    out = ''
    for a, b in pts:
        out += f'<g transform="matrix({u[0]} {u[1]} {v[0]} {v[1]} {o[0]} {o[1]})"><circle cx="{a}" cy="{b}" r="{r}" fill="{color}"/></g>'
    return out

I = {}
# ================= PROGRESS =================
I['progress_1_cofre'] = ('Cofre', svg(
    shadow(256, 452, 190) +
    P('M88 250 L88 196 Q88 112 256 112 Q424 112 424 196 L424 250 Z', 'url(#purp)') +
    HL('M120 190 Q130 140 230 136', 10, .45) +
    P('M88 250 L424 250 L424 420 Q424 436 408 436 L104 436 Q88 436 88 420 Z', 'url(#purpD)') +
    L('M96 316 L416 316 M96 378 L416 378', '#2A0E3A', 6, .7) +
    R(132, 112, 40, 324, 'url(#gold)', 6, 10) + R(340, 112, 40, 324, 'url(#gold)', 6, 10) +
    R(80, 236, 352, 30, 'url(#gold)', 10, 10) +
    R(220, 230, 72, 84, 'url(#gold)', 14, 10) + P('M256 254 m-13 0 a13 13 0 1 0 26 0 a13 13 0 1 0 -26 0 M250 266 L246 292 L266 292 L262 266', O, 4) +
    Ci(152, 136, 5, O, 0) + Ci(360, 136, 5, O, 0) + Ci(152, 410, 5, O, 0) + Ci(360, 410, 5, O, 0) +
    spark(440, 86)))

I['progress_2_album'] = ('Álbum de stickers', svg(
    shadow(256, 456, 200) +
    P('M44 156 L256 188 L468 156 L468 420 L256 452 L44 420 Z', 'url(#purp)') +
    P('M64 136 L256 170 L256 430 L64 398 Z', 'url(#cream)', 10) + P('M256 170 L448 136 L448 398 L256 430 Z', 'url(#cream)', 10) +
    L('M256 170 L256 430', O, 6, .5) +
    f'<g transform="rotate(-6 128 230)">{R(92, 186, 80, 80, "url(#pink)", 14, 9)}<path d="{star(132, 226, 24)}" fill="#FFE08A" {st(5)}/></g>' +
    f'<g transform="rotate(5 160 330)">{R(118, 290, 84, 84, "url(#teal)", 14, 9)}' + L('M160 356 Q158 322 168 306 M168 306 Q146 300 136 312 M168 306 Q188 296 196 308 M168 306 Q164 290 152 290', O, 6) + '</g>' +
    f'<g transform="rotate(4 340 230)">{R(298, 188, 84, 84, "url(#sun)", 14, 9)}' + Ci(340, 230, 20, '#FFF4E6', 6) + '</g>' +
    R(300, 300, 84, 84, 'none', 14, 6, 'stroke-dasharray="14 12" opacity=".55"') +
    L('M342 330 L342 356 M329 343 L355 343', O, 7, .5) + spark(452, 96)))

I['progress_3_pasaporte'] = ('Pasaporte', svg(
    shadow(250, 456, 170) +
    '<g transform="rotate(-8 240 260)">' +
    R(112, 70, 250, 350, 'url(#teal)', 22) + R(112, 70, 40, 350, 'url(#tealD)', 0, 0, 'opacity=".9"') + R(112, 70, 250, 350, 'none', 22) +
    Ci(250, 200, 62, 'url(#gold)', 10) + L('M250 238 Q246 200 258 176 M258 176 Q232 166 218 182 M258 176 Q280 160 296 176 M258 176 Q254 154 236 152 M258 176 Q272 156 288 158', O, 7) +
    R(176, 296, 148, 18, '#FFE08A', 9, 6) + R(196, 330, 108, 14, '#FFE08A', 7, 5, 'opacity=".8"') +
    HL('M140 100 L140 390', 6, .35) + '</g>' +
    '<g transform="rotate(14 370 360)">' + Ci(372, 362, 66, 'url(#pink)', 10, 'opacity=".96"') + Ci(372, 362, 46, 'none', 6, 'stroke-dasharray="8 8"') +
    f'<path d="{star(372, 362, 26)}" fill="#FFF4E6" {st(5)}/></g>' + spark(436, 96)))

I['progress_4_barra'] = ('Barra de nivel', svg(
    shadow(272, 372, 200, 14) +
    R(96, 194, 380, 128, 'url(#dark)', 34) +
    R(118, 214, 240, 88, 'url(#sunH)', 20, 8) + HL('M140 232 L330 232', 10, .55) +
    L('M178 220 L178 296 M238 220 L238 296 M298 220 L298 296', O, 6, .35) +
    Ci(108, 258, 82, 'url(#gold)', 12) + Ci(108, 258, 60, 'none', 6, 'opacity=".35"') +
    f'<path d="{star(108, 262, 44)}" fill="url(#pink)" {st(8)}/>' +
    P('M402 168 L438 120 L474 168 L452 168 L452 206 L424 206 L424 168 Z', 'url(#teal)', 9) + spark(420, 380, .8)))

I['progress_5_estrella'] = ('Estrella', svg(
    shadow(256, 456, 150) +
    E(256, 290, 214, 74, 'none', 0, 'stroke="#FF3E8A" stroke-width="16" opacity=".0"') +
    f'<path d="{star(256, 262, 196, 88)}" transform="translate(0 22)" fill="url(#goldD)" {st(12)}/>' +
    f'<path d="{star(256, 250, 196, 88)}" fill="url(#gold)" {st(12)}/>' +
    ''.join(f'<path d="M256 250 L{256+196*math.cos(math.radians(-90+72*i)):.1f} {250+196*math.sin(math.radians(-90+72*i)):.1f} L{256+88*math.cos(math.radians(-54+72*i)):.1f} {250+88*math.sin(math.radians(-54+72*i)):.1f} Z" fill="#E0A43A" opacity=".55"/>' for i in range(5)) +
    f'<path d="{star(256, 250, 196, 88)}" fill="none" {st(12)}/>' +
    Ci(256, 250, 40, 'url(#pink)', 9) + HL('M228 120 L244 90', 10, .7) + spark(440, 90)))

# ================= CHALLENGES =================
def die(cx, cy, s, top, left, right, pipc, faces):
    out = cube(cx, cy, s, top, left, right)
    k = 0.87
    # top face: origin = left vertex, u -> top vertex, v -> center
    out += pips((cx-k*s, cy-s/2), (k*s, -s/2), (k*s, s/2), faces[0], pipc)
    out += pips((cx-k*s, cy-s/2), (k*s, s/2), (0, s), faces[1], pipc)
    out += pips((cx, cy), (k*s, -s/2), (0, s), faces[2], pipc)
    return out
F1 = [(.5, .5)]; F2 = [(.27, .27), (.73, .73)]; F3 = [(.25, .25), (.5, .5), (.75, .75)]
F5 = [(.25, .25), (.75, .25), (.5, .5), (.25, .75), (.75, .75)]; F6 = [(.27, .22), (.27, .5), (.27, .78), (.73, .22), (.73, .5), (.73, .78)]; F4 = [(.27, .27), (.73, .27), (.27, .73), (.73, .73)]
I['challenges_1_dados'] = ('Dados', svg(
    shadow(250, 452, 200) +
    die(330, 196, 112, 'url(#pink)', '#C21C60', '#9E1450', '#FFF4E6', [F1, F3, F2]) +
    die(180, 312, 124, '#FFFFFF', '#EBD3B8', '#D1B496', '#E02470', [F5, F6, F4]) + spark(446, 82)))

I['challenges_2_cinturon'] = ('Cinturón', svg(
    shadow(256, 452, 220) +
    P('M30 238 Q256 300 482 238 L482 318 Q256 382 30 318 Z', 'url(#purpD)') +
    L('M40 258 Q256 320 472 258 M40 300 Q256 362 472 300', '#FFE08A', 5, .55) +
    R(86, 256, 70, 84, 'url(#gold)', 12, 10, 'transform="rotate(8 121 298)"') + R(356, 256, 70, 84, 'url(#gold)', 12, 10, 'transform="rotate(-8 391 298)"') +
    P('M256 150 L352 186 L372 280 L320 380 L256 410 L192 380 L140 280 L160 186 Z', 'url(#gold)', 12) +
    P('M256 186 L322 210 L336 278 L300 350 L256 370 L212 350 L176 278 L190 210 Z', 'url(#pink)', 9) +
    f'<path d="{star(256, 278, 52)}" fill="#FFE08A" {st(8)}/>' + HL('M190 200 L230 176', 9, .6) +
    Ci(121, 298, 8, '#FFF4E6', 5) + Ci(391, 298, 8, '#FFF4E6', 5) + spark(436, 120)))

I['challenges_3_wanted'] = ('Nivel de búsqueda', svg(
    shadow(256, 460, 170) +
    '<g transform="rotate(-4 256 260)">' + R(98, 64, 316, 384, 'url(#cream)', 10) +
    R(126, 98, 260, 44, '#E02470', 6, 8) + R(150, 158, 212, 170, '#2A1240', 8, 8) +
    P('M256 186 C292 186 306 214 302 246 C298 274 282 290 256 290 C230 290 214 274 210 246 C206 214 220 186 256 186 Z M190 328 Q192 290 236 286 L276 286 Q320 290 322 328 Z', '#5A3A80', 0) +
    ''.join(f'<path d="{star(160+48*i, 376, 22)}" fill="{"url(#gold)" if i < 3 else "#E8DCCB"}" {st(6)}/>' for i in range(5)) +
    L('M146 120 L366 120', '#FFF4E6', 8, .9) + '</g>' + Ci(256, 78, 16, 'url(#pink)', 8) + spark(444, 112)))

I['challenges_4_chile'] = ('Chile picante', svg(
    shadow(256, 452, 170) +
    P('M330 128 C392 140 420 210 392 292 C360 384 260 448 150 440 C110 437 96 412 124 400 C214 362 276 310 290 222 C296 176 300 136 330 128 Z', 'url(#red)') +
    HL('M366 186 C380 230 366 286 330 330', 12, .55) +
    P('M330 128 C318 96 336 72 368 64 L376 82 C352 90 346 106 352 124 Z', 'url(#green)', 10) +
    P('M298 140 Q330 104 380 134 Q356 152 330 146 Q312 152 298 140 Z', 'url(#green)', 10) +
    P('M120 150 C110 120 134 100 128 70 C156 92 168 120 150 150 Z', 'url(#sun)', 8) +
    P('M196 120 C190 98 210 84 206 60 C228 78 236 100 222 124 Z', 'url(#sun)', 8) +
    P('M80 236 C68 214 88 196 82 170 C108 188 116 214 102 238 Z', 'url(#sun)', 8)))

I['challenges_5_nitro'] = ('Nitro', svg(
    shadow(250, 456, 160) +
    '<g transform="rotate(18 256 270)">' +
    R(166, 130, 180, 320, 'url(#teal)', 70) + R(166, 236, 180, 110, 'url(#pink)', 0, 10) +
    P('M226 266 L262 266 L246 296 L278 296 L232 344 L244 310 L216 310 Z', '#FFE08A', 7) +
    HL('M196 170 L196 410', 12, .5) + R(220, 88, 72, 50, 'url(#steel)', 10, 10) + R(196, 56, 120, 36, 'url(#gold)', 14, 10) + '</g>' +
    P('M118 92 C108 72 126 58 120 36 C142 52 150 74 136 96 Z', 'url(#sun)', 7) + spark(430, 130)))

# ================= ACTIVITIES =================
BOARD = 'M-196 0 C-196 -44 -110 -50 0 -50 C112 -50 186 -22 200 0 C186 22 112 50 0 50 C-110 50 -196 44 -196 0 Z'
I['activities_1_surf'] = ('Surf', svg(
    P('M30 470 L30 300 C30 168 166 104 268 136 C340 158 372 222 350 276 C330 236 292 222 260 240 C228 260 238 300 276 312 Q330 326 380 314 Q430 300 482 320 L482 470 Z', 'url(#teal)') +
    P('M70 470 L70 330 C80 220 160 176 240 180', 'none', 0, 'stroke="#11695F" stroke-width="10" opacity=".5"') +
    L('M60 300 C70 200 160 150 250 160', '#FFFFFF', 10, .6) + L('M350 276 C356 250 352 226 340 206', '#FFFFFF', 10, .8) +
    Ci(372, 238, 9, '#FFFFFF', 5) + Ci(390, 262, 6, '#FFFFFF', 4) + Ci(380, 206, 6, '#FFFFFF', 4) +
    '<g transform="translate(286 236) rotate(-28) scale(.95)">' + P(BOARD, 'url(#sunH)') +
    P('M-196 0 C-196 -16 -150 -22 0 -22 C120 -22 186 -10 200 0 C186 10 120 22 0 22 C-150 22 -196 16 -196 0 Z', 'url(#pink)', 0, 'opacity=".9"') +
    L('M-190 0 L196 0', '#FFF4E6', 5, .9) + P(BOARD, 'none') +
    P('M-150 46 L-110 48 L-150 86 Z', 'url(#purp)', 9) +
    HL('M-140 -30 C-60 -42 60 -42 150 -22', 8, .55) + '</g>' +
    Ci(96, 86, 40, 'url(#gold)', 9)))

I['activities_2_jetski'] = ('Moto de agua', svg(
    P('M30 420 Q90 392 150 420 T270 420 T390 420 T482 420 L482 470 L30 470 Z', 'url(#teal)', 10) +
    P('M58 340 L400 340 Q452 340 466 306 L430 268 L320 268 L278 226 L180 226 Q132 226 112 262 L64 300 Z', 'url(#pink)') +
    P('M58 340 L400 340 Q440 340 458 318 L466 340 Q440 378 380 380 L96 380 Q70 380 58 340 Z', '#FFFFFF') +
    P('M180 226 L278 226 L300 250 L172 250 Z', 'url(#dark)', 10) +
    P('M300 256 L330 200', 'none', 12) + P('M312 196 L356 188', 'none', 12) +
    P('M330 268 L420 268 L440 300 L350 300 Z', 'url(#sky)', 9) +
    L('M90 312 L210 312', '#FFE08A', 10) + HL('M140 262 L250 262', 8, .5) +
    L('M14 380 Q34 356 30 330 M40 400 Q62 380 64 356', '#9EF2EA', 9) + spark(436, 120)))

I['activities_3_pesca'] = ('Pesca', svg(
    P('M40 440 Q110 416 180 440 T320 440 T472 440 L472 470 L40 470 Z', 'url(#teal)', 10) +
    L('M84 452 L392 70', O, 22) + L('M84 452 L392 70', 'url(#wood)', 12) + L('M84 452 L150 370', O, 26) + L('M84 452 L150 370', 'url(#dark)', 16) +
    Ci(176, 360, 34, 'url(#gold)', 10) + Ci(176, 360, 10, O, 0) + L('M176 360 L206 338', O, 8) +
    L('M392 70 Q452 160 380 268', '#FFF4E6', 4) +
    '<g transform="rotate(-24 360 320)">' + P('M300 320 C330 278 400 278 430 320 C400 362 330 362 300 320 Z M300 320 L262 292 L268 320 L262 348 Z', 'url(#pink)', 10) +
    Ci(400, 312, 7, O, 0) + HL('M330 300 Q360 290 390 296', 6, .55) + '</g>' +
    L('M380 268 Q392 280 384 292', O, 5) + spark(80, 100)))

I['activities_4_patineta'] = ('Patineta', svg(
    shadow(256, 452, 200) +
    '<g transform="rotate(-18 256 300)">' +
    R(140, 330, 36, 40, 'url(#steel)', 6, 8) + R(336, 330, 36, 40, 'url(#steel)', 6, 8) +
    E(126, 380, 34, 28, 'url(#teal)', 10) + E(190, 380, 34, 28, 'url(#teal)', 10) + E(322, 380, 34, 28, 'url(#teal)', 10) + E(386, 380, 34, 28, 'url(#teal)', 10) +
    P('M80 300 Q40 300 44 330 Q90 344 256 344 Q422 344 468 330 Q472 300 432 300 Z', 'url(#pinkD)', 10) +
    P('M90 282 Q46 282 44 314 Q100 330 256 330 Q412 330 468 314 Q466 282 422 282 Z', 'url(#sunH)', 12) +
    L('M150 296 L200 316 M240 296 L290 316', '#FFF4E6', 10, .8) + f'<path d="{star(360, 306, 18)}" fill="#FFE08A" {st(4)}/>' + '</g>' + spark(430, 120)))

I['activities_5_bolos'] = ('Bolos', svg(
    shadow(256, 456, 200) +
    P('M196 52 C230 52 244 84 236 126 C230 158 216 168 220 200 C226 242 270 282 270 352 C270 414 240 450 196 450 C152 450 122 414 122 352 C122 282 166 242 172 200 C176 168 162 158 156 126 C148 84 162 52 196 52 Z', 'url(#cream)') +
    L('M162 152 Q196 166 230 152', '#E02470', 12) + L('M166 180 Q196 192 226 180', '#E02470', 12) + HL('M180 80 Q172 110 182 140', 8, .8) +
    Ci(366, 366, 94, 'url(#purp)') + Ci(340, 330, 14, O, 0) + Ci(380, 322, 14, O, 0) + Ci(362, 362, 14, O, 0) +
    HL('M310 316 Q320 296 344 290', 10, .55) + spark(440, 120)))

# ================= PROPERTIES =================
I['properties_1_pin_casa'] = ('Pin con casa', svg(
    shadow(256, 462, 90, 16) +
    P('M256 460 C256 460 92 300 92 200 C92 108 166 38 256 38 C346 38 420 108 420 200 C420 300 256 460 256 460 Z', 'url(#sun)') +
    HL('M134 170 Q140 100 210 74', 12, .5) + Ci(256, 196, 118, 'url(#cream)', 10) +
    R(306, 116, 22, 50, 'url(#pinkD)', 3, 8) +
    P('M256 108 L160 190 L352 190 Z', 'url(#pink)', 10) + R(180, 186, 152, 102, '#FFF8EE', 4, 10) +
    R(238, 226, 36, 62, 'url(#teal)', 4, 8) + R(196, 212, 30, 28, 'url(#sky)', 3, 7) + R(286, 212, 30, 28, 'url(#sky)', 3, 7) +
    L('M150 296 Q256 310 362 296', '#2E9E4F', 10, .9)))

I['properties_2_hotel'] = ('Hotel art déco', svg(
    shadow(256, 456, 210) +
    P('M120 448 L120 150 L170 150 L170 110 L342 110 L342 150 L392 150 L392 448 Z', 'url(#cream)') +
    R(232, 70, 48, 44, 'url(#pink)', 6, 10) + L('M256 44 L256 70', O, 10) +
    R(120, 196, 272, 20, 'url(#teal)', 0, 8) + R(120, 300, 272, 20, 'url(#pink)', 0, 8) +
    ''.join(R(x, y, 34, 52, 'url(#sky)', 6, 7) for x in (150, 218, 260, 328) for y in (230, 334)) +
    R(206, 380, 100, 68, 'url(#dark)', 10, 9) + P('M196 380 L316 380 L300 360 L212 360 Z', 'url(#pink)', 8) +
    R(400, 130, 46, 200, 'url(#purp)', 12, 10) + ''.join(f'<path d="{star(423, 160+40*i, 13)}" fill="#FFE08A"/>' for i in range(5)) +
    L('M84 448 Q74 330 104 236', O, 22) + L('M84 448 Q74 330 104 236', 'url(#wood)', 12) +
    P('M104 236 Q60 210 30 240 Q66 222 104 240 Q74 180 40 176 Q90 170 108 232 Q120 176 168 174 Q132 196 110 238 Z', 'url(#green)', 8)))

I['properties_3_letrero'] = ('Letrero de venta', svg(
    P('M40 452 Q120 420 256 430 Q392 420 472 452 Z', 'url(#green)', 10) +
    R(96, 70, 34, 380, 'url(#wood)', 6) + R(96, 84, 300, 30, 'url(#wood)', 8) +
    L('M196 114 L196 156 M346 114 L346 156', O, 8) +
    R(150, 152, 252, 160, 'url(#pink)', 18) + R(168, 170, 216, 124, 'none', 10, 6, 'stroke="#FFF4E6" opacity=".9"') +
    dollar(276, 234, 0.62, '#FFF4E6', 34) + HL('M180 190 L240 190', 8, .45) + spark(436, 90)))

I['properties_4_neon'] = ('Neón de motel', svg(
    R(236, 300, 40, 160, 'url(#steel)', 6) + shadow(256, 460, 80, 12) +
    P('M60 150 L360 150 L360 104 L460 206 L360 308 L360 262 L60 262 Z', 'url(#purp)') +
    P('M86 174 L380 174 L380 158 L430 206 L380 254 L380 238 L86 238 Z', 'none', 8, 'stroke="#FF6FA6"') +
    ''.join(Ci(x, 206, 10, '#FFE08A', 5) for x in range(110, 360, 44)) +
    f'<path d="{star(120, 82, 54)}" fill="url(#gold)" {st(10)}/>' + Ci(120, 82, 12, '#FFF4E6', 0)))

I['properties_5_buzon'] = ('Buzón', svg(
    R(234, 320, 44, 136, 'url(#wood)', 6) + shadow(256, 458, 110, 12) +
    P('M96 212 Q96 116 196 116 L360 116 Q448 116 448 212 L448 330 L96 330 Z', 'url(#teal)') +
    P('M96 212 Q96 116 172 116 Q248 116 248 212 L248 330 L96 330 Z', 'url(#tealD)', 12) +
    P('M140 170 L210 170 L210 236 L140 236 Z', 'url(#cream)', 8, 'transform="rotate(-10 175 203)"') +
    HL('M290 140 L410 140', 10, .5) +
    R(394, 46, 18, 160, 'url(#steel)', 6, 8) + P('M404 46 L474 46 L474 98 L404 98 Z', 'url(#pink)', 10)))

# ================= GARAGE =================
I['garage_1_carro_frente'] = ('Carro de frente', svg(
    shadow(256, 452, 210) +
    R(84, 360, 82, 86, 'url(#dark)', 18) + R(346, 360, 82, 86, 'url(#dark)', 18) +
    P('M150 96 L362 96 L414 212 L98 212 Z', 'url(#pink)') + P('M172 120 L340 120 L380 202 L132 202 Z', 'url(#sky)', 9) +
    HL('M190 134 L170 190', 12, .7) + HL('M220 134 L206 170', 8, .5) +
    R(52, 198, 408, 166, 'url(#pink)', 40) + R(52, 300, 408, 64, 'url(#pinkD)', 0, 0, 'opacity=".7"') + R(52, 198, 408, 166, 'none', 40) +
    L('M226 206 L226 290 M286 206 L286 290', '#FFF4E6', 12, .85) +
    Ci(124, 270, 36, '#FFE08A', 10) + Ci(388, 270, 36, '#FFE08A', 10) + Ci(124, 270, 16, '#FFFFFF', 0) + Ci(388, 270, 16, '#FFFFFF', 0) +
    R(180, 248, 152, 56, 'url(#dark)', 12, 10) + L('M200 262 L312 262 M200 276 L312 276 M200 290 L312 290', '#9C93B5', 5) +
    R(60, 326, 392, 30, 'url(#steel)', 15, 10)))

I['garage_2_placa'] = ('Placa', svg(
    shadow(256, 430, 210, 14) +
    R(36, 120, 440, 270, 'url(#cream)', 34) + P('M36 154 Q36 120 70 120 L442 120 Q476 120 476 154 L476 196 L36 196 Z', 'url(#sunH)', 0) +
    R(36, 120, 440, 270, 'none', 34) + L('M36 196 L476 196', O, 8) +
    L('M84 186 Q80 160 92 140 M92 140 Q74 132 64 146 M92 140 Q110 128 120 142', O, 6) +
    '<text x="256" y="172" text-anchor="middle" font-family="DejaVu Sans" font-weight="bold" font-size="40" fill="#FFF4E6" stroke="#140A24" stroke-width="3">LEONIDA</text>' +
    '<text x="256" y="322" text-anchor="middle" font-family="DejaVu Sans" font-weight="bold" font-size="104" fill="#2B1E92">VC·86</text>' +
    Ci(80, 352, 12, 'url(#steel)', 6) + Ci(432, 352, 12, 'url(#steel)', 6) + spark(452, 92)))

I['garage_3_llanta'] = ('Llanta', svg(
    shadow(256, 460, 160) +
    E(280, 256, 150, 196, 'url(#dark)') + E(232, 256, 150, 196, '#2A1A44') +
    ''.join(L(f'M{232+150*math.cos(math.radians(a)):.0f} {256+196*math.sin(math.radians(a)):.0f} L{232+128*math.cos(math.radians(a)):.0f} {256+168*math.sin(math.radians(a)):.0f}', '#55407A', 10) for a in range(0, 360, 20)) +
    E(232, 256, 150, 196, 'none') + E(232, 256, 92, 120, 'url(#gold)', 10) +
    ''.join(L(f'M232 256 L{232+80*math.cos(math.radians(a)):.0f} {256+106*math.sin(math.radians(a)):.0f}', O, 16) for a in range(-90, 270, 72)) +
    ''.join(L(f'M232 256 L{232+80*math.cos(math.radians(a)):.0f} {256+106*math.sin(math.radians(a)):.0f}', '#FFE08A', 7) for a in range(-90, 270, 72)) +
    Ci(232, 256, 24, 'url(#pink)', 8) + HL('M140 150 Q160 110 200 92', 10, .35) + spark(436, 96)))

I['garage_4_gasolina'] = ('Gasolina', svg(
    shadow(240, 456, 170) +
    R(96, 120, 220, 324, 'url(#pink)', 26) + Ci(206, 92, 52, 'url(#cream)', 10) + L('M180 92 L232 92', '#E02470', 10) +
    R(126, 160, 160, 96, 'url(#cream)', 12, 10) + L('M150 222 L206 186', O, 7) + Ci(206, 230, 10, O, 0) +
    R(140, 290, 132, 22, '#FFF4E6', 8, 7, 'opacity=".9"') + R(76, 430, 260, 30, 'url(#dark)', 10) +
    HL('M118 140 L118 410', 10, .35) +
    L('M316 200 L370 200 Q392 200 392 222 L392 360 Q392 396 420 396 Q448 396 448 360 L448 226', O, 26) +
    L('M316 200 L370 200 Q392 200 392 222 L392 360 Q392 396 420 396 Q448 396 448 360 L448 226', 'url(#dark)', 14) +
    R(422, 148, 52, 92, 'url(#steel)', 14, 10)))

I['garage_5_cono'] = ('Cono', svg(
    shadow(256, 452, 200) +
    R(60, 400, 392, 52, 'url(#pinkD)', 14) +
    P('M226 62 L286 62 L392 406 L120 406 Z', 'url(#sun)') +
    P('M196 160 L316 160 L336 222 L176 222 Z', '#FFF4E6', 8) + P('M160 276 L352 276 L372 340 L140 340 Z', '#FFF4E6', 8) +
    HL('M240 84 L196 360', 10, .4) + spark(440, 110)))

# ================= PORTFOLIO =================
I['portfolio_1_cerdito'] = ('Cerdito', svg(
    shadow(256, 456, 190) +
    R(130, 360, 50, 80, 'url(#pinkD)', 14) + R(320, 360, 50, 80, 'url(#pinkD)', 14) +
    E(256, 290, 190, 140, 'url(#pink)') + P('M150 176 L130 110 L204 156 Z', 'url(#pinkD)', 10) +
    E(436, 296, 40, 50, '#FF9CC4', 10) + Ci(426, 286, 7, O, 0) + Ci(446, 306, 7, O, 0) + Ci(372, 248, 12, O, 0) +
    L('M66 290 Q40 270 50 248 Q64 236 70 256', O, 9) + R(210, 160, 92, 18, O, 9, 0) +
    HL('M130 240 Q150 190 210 172', 12, .5) +
    Ci(256, 82, 50, 'url(#gold)', 10) + dollar(256, 84, 0.42, O, 30)))

I['portfolio_2_reloj'] = ('Reloj de oro', svg(
    R(196, 40, 120, 120, 'url(#goldD)', 18) + R(196, 352, 120, 120, 'url(#goldD)', 18) +
    L('M206 76 L306 76 M206 112 L306 112 M206 392 L306 392 M206 428 L306 428', O, 6, .45) +
    Ci(256, 256, 140, 'url(#gold)') + Ci(256, 256, 104, 'url(#teal)', 10) +
    ''.join(f'<circle cx="{256+86*math.cos(math.radians(a)):.0f}" cy="{256+86*math.sin(math.radians(a)):.0f}" r="7" fill="#FFF4E6"/>' for a in range(0, 360, 30)) +
    L('M256 256 L256 186', O, 12) + L('M256 256 L310 286', O, 10) + Ci(256, 256, 12, 'url(#pink)', 6) +
    R(396, 236, 28, 40, 'url(#gold)', 8, 9) + HL('M170 190 Q190 160 226 150', 10, .5) + spark(440, 96)))

I['portfolio_3_carpeta'] = ('Carpeta', svg(
    shadow(256, 456, 200) +
    P('M60 140 L190 140 L216 170 L452 170 L452 430 L60 430 Z', 'url(#goldD)') +
    f'<g transform="rotate(-10 200 210)">{R(130, 110, 150, 170, "#FFFFFF", 6, 10)}{R(146, 126, 118, 110, "url(#sky)", 0, 7)}' +
    P('M205 150 L160 196 L250 196 Z', 'url(#pink)', 6) + R(172, 194, 66, 40, '#FFF8EE', 0, 6) + '</g>' +
    f'<g transform="rotate(8 330 200)">{R(262, 100, 150, 170, "#FFFFFF", 6, 10)}{R(278, 116, 118, 110, "url(#sun)", 0, 7)}' +
    P('M292 206 L300 182 L330 176 L360 182 L380 206 Z', 'url(#dark)', 6) + Ci(312, 208, 9, O, 0) + Ci(362, 208, 9, O, 0) + '</g>' +
    P('M48 232 L464 232 L440 440 L72 440 Z', 'url(#gold)') + HL('M90 262 L420 262', 10, .5) +
    R(206, 300, 100, 34, 'url(#cream)', 8, 8)))

I['portfolio_4_yate'] = ('Yate', svg(
    P('M30 424 Q100 400 170 424 T310 424 T482 424 L482 470 L30 470 Z', 'url(#teal)', 10) +
    P('M40 330 L472 330 L420 410 L100 410 Z', '#FFFFFF') + L('M62 356 L452 356', '#E02470', 14) +
    P('M40 330 L472 330 L420 410 L100 410 Z', 'none') +
    P('M120 330 L160 250 L360 250 L410 330 Z', '#FFFFFF') + P('M184 250 L210 190 L330 190 L350 250 Z', '#FFFFFF') +
    P('M176 270 L346 270 L366 314 L150 314 Z', 'url(#dark)', 8) + P('M220 204 L320 204 L330 236 L210 236 Z', 'url(#sky)', 7) +
    L('M270 190 L270 120', O, 10) + P('M270 124 L330 140 L270 156 Z', 'url(#pink)', 7) +
    Ci(390, 300, 10, '#FFE08A', 5) + spark(440, 120)))

I['portfolio_5_llavero'] = ('Llavero', svg(
    Ci(256, 108, 66, 'none', 0, 'stroke="#140A24" stroke-width="30"') + Ci(256, 108, 66, 'none', 0, 'stroke="url(#gold)" stroke-width="14"') +
    L('M206 160 L140 236 M256 174 L256 250 M306 160 L372 236', O, 10) +
    P('M140 224 L80 280 L92 280 L92 360 L188 360 L188 280 L200 280 Z', 'url(#pink)', 10) + R(124, 310, 32, 50, 'url(#dark)', 4, 7) +
    R(210, 240, 92, 120, 'url(#dark)', 26) + Ci(256, 278, 14, 'url(#pink)', 6) + Ci(256, 322, 14, '#FFE08A', 6) +
    P('M240 360 L272 360 L272 448 L256 466 L240 448 Z', 'url(#steel)', 9) +
    P('M330 230 L424 230 L444 262 L424 400 L330 400 Z', 'url(#green)', 10) + Ci(424, 262, 0, O, 0) +
    dollar(384, 318, 0.42, '#FFF4E6', 30)))

json.dump({k: v[0] for k, v in I.items()}, open('fc_names.json', 'w'), ensure_ascii=False)
for k, (n, s) in I.items():
    open(f'fc_{k}.svg', 'w').write(s)
print(len(I))
