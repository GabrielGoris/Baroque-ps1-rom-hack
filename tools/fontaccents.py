"""Desenha letras acentuadas do portugues no FONT.BIN do Baroque.

Uso: python fontaccents.py <FONT.BIN de entrada> <FONT.BIN de saida> [preview.png]

A fonte e uma tabela de glifos de 16x16 (2 bits por pixel, 64 bytes cada);
o jogo em ingles so usa a metade esquerda (8x16). O indice do glifo e o
proprio codigo do caractere. Os codigos 0x30..0x6F estao vazios na versao
em ingles e recebem as letras novas (tabela ACCENTS abaixo).
Estilo: 3 = contorno, 1 = preenchimento, 0 = transparente.
"""
import sys

GLYPH = 64

# codigo novo -> (letra base, acento, maiuscula?)
ACCENTS = {
    0x30: (0xD6, 'acute', False), 0x31: (0xD6, 'grave', False), 0x32: (0xD6, 'circ', False), 0x33: (0xD6, 'tilde', False),
    0x34: (0xDA, 'acute', False), 0x35: (0xDA, 'circ', False),
    0x36: (0xDE, 'acute', False),
    0x37: (0xE4, 'acute', False), 0x38: (0xE4, 'circ', False), 0x39: (0xE4, 'tilde', False),
    0x3A: (0xEA, 'acute', False), 0x3B: (0xD8, 'cedil', False),
    0x40: (0xBC, 'acute', True), 0x41: (0xBC, 'grave', True), 0x42: (0xBC, 'circ', True), 0x43: (0xBC, 'tilde', True),
    0x44: (0xC0, 'acute', True), 0x45: (0xC0, 'circ', True),
    0x46: (0xC4, 'acute', True),
    0x47: (0xCA, 'acute', True), 0x48: (0xCA, 'circ', True), 0x49: (0xCA, 'tilde', True),
    0x4A: (0xD0, 'acute', True), 0x4B: (0xBE, 'cedil', True),
}
CHARS = {0x30:'á',0x31:'à',0x32:'â',0x33:'ã',0x34:'é',0x35:'ê',0x36:'í',0x37:'ó',0x38:'ô',0x39:'õ',
         0x3A:'ú',0x3B:'ç',0x40:'Á',0x41:'À',0x42:'Â',0x43:'Ã',0x44:'É',0x45:'Ê',0x46:'Í',0x47:'Ó',
         0x48:'Ô',0x49:'Õ',0x4A:'Ú',0x4B:'Ç'}

# pixels de preenchimento (x, y) de cada acento; o contorno e gerado sozinho
MARKS_LOWER = {
    'acute': [(5, 3), (4, 4)],
    'grave': [(1, 3), (2, 4)],
    'circ':  [(3, 3), (2, 4), (4, 4)],
    'tilde': [(1, 4), (2, 3), (3, 4), (4, 4), (5, 3)],
}
MARKS_UPPER = {   # maiusculas ficam 1 linha mais baixas e 1 linha mais curtas
    'acute': [(5, 1), (4, 2)],
    'grave': [(1, 1), (2, 2)],
    'circ':  [(3, 1), (2, 2), (4, 2)],
    'tilde': [(1, 2), (2, 1), (3, 2), (4, 2), (5, 1)],
}


def read(font, code):
    o = code * GLYPH
    g = []
    for y in range(16):
        w = (font[o + y * 2] << 8) | font[o + y * 2 + 1]
        g.append([(w >> (14 - 2 * x)) & 3 for x in range(8)])
    return g


def write(font, code, g):
    o = code * GLYPH
    for y in range(16):
        w = 0
        for x in range(8):
            w |= (g[y][x] & 3) << (14 - 2 * x)
        font[o + y * 2] = w >> 8
        font[o + y * 2 + 1] = w & 0xFF
    for i in range(32, 64):          # metade direita vazia
        font[o + i] = 0


def add_fill(g, pts):
    for x, y in pts:
        if 0 <= x < 8 and 0 <= y < 16:
            g[y][x] = 1
    for x, y in pts:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                nx, ny = x + dx, y + dy
                if 0 <= nx < 8 and 0 <= ny < 16 and g[ny][nx] == 0:
                    g[ny][nx] = 3


def make(font, base, accent, upper):
    g = [row[:] for row in read(font, base)]
    if accent == 'cedil':
        add_fill(g, [(3, 15)])
        return g
    if upper:
        # letra ocupa as linhas 2..14; tira uma linha repetida do meio
        body = g[2:15]
        cut = next((r for r in range(3, 10) if body[r] == body[r + 1]), 6)
        body = body[:cut] + body[cut + 1:]
        g = [[0] * 8 for _ in range(4)] + body   # agora nas linhas 4..15
        add_fill(g, MARKS_UPPER[accent])
    else:
        if base == 0xDE:             # i: troca o pingo pelo acento
            for y in range(0, 6):
                g[y] = [0] * 8
            g[6] = [0, 0, 3, 3, 3, 0, 0, 0]
        add_fill(g, MARKS_LOWER[accent])
    return g


def main():
    src, dst = sys.argv[1], sys.argv[2]
    font = bytearray(open(src, 'rb').read())
    for code, (base, accent, upper) in ACCENTS.items():
        write(font, code, make(font, base, accent, upper))
    open(dst, 'wb').write(font)
    print('%d letras acentuadas gravadas em %s' % (len(ACCENTS), dst))
    if len(sys.argv) > 3:
        from PIL import Image
        codes = sorted(ACCENTS) + [0xD6, 0xDA, 0xBC, 0xC0]
        s = 6
        im = Image.new('RGB', (len(codes) * 9 * s, 17 * s), (60, 60, 90))
        px = im.load()
        pal = {0: (60, 60, 90), 1: (235, 235, 235), 3: (10, 10, 10), 2: (128, 128, 128)}
        for n, c in enumerate(codes):
            g = read(font, c)
            for y in range(16):
                for x in range(8):
                    for a in range(s):
                        for b in range(s):
                            px[(n * 9 + x) * s + a, y * s + b] = pal[g[y][x]]
        im.save(sys.argv[3])


if __name__ == '__main__':
    main()
