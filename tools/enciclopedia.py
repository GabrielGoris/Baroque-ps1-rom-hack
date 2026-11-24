"""Enciclopedia de itens da tela titulo (traducao pt-BR).

  python enciclopedia.py <pasta do projeto>

A traducao inglesa nao usa o ETC/ITEM2.MSB (que ficou em japones). O tradutor
colocou o texto ingles dentro de ETC/FONT.BIN, a partir de 0x5000 (carregado
em 0x801CB800), e trocou as tabelas do BIN01/MOVIE.BIN:
  0x127EC: 244 palavras (16 bits altos = categoria, 16 baixos = posicao do texto)
  0x12BDC: 12 meias-palavras (filmes, finais e extras)
  gp-0x7DB8 (exe 0x80068728) = 0x4C, a entrada "???" do cabecalho.
Os primeiros 0x6C bytes (numeros de pagina e a entrada vazia) ficam iguais.

Le traducao/ENCICLOPEDIA.tsv (chave, ingles, traducao) e grava o bloco novo em
patch/files/ETC/FONT.BIN e as tabelas em patch/files/BIN01/MOVIE.BIN.
Rode depois do fontaccents.py e do textpack.py.
"""
import os
import re
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bptext  # noqa: E402

BLOCK_OFF = 0x5000
BLOCK_SIZE = 0x4688       # espaco usado pelo ingles; depois vem desenho da fonte
HEADER = 0x6C
TAB = 0x127EC
TAB_N = 244
SPEC = 0x12BDC
SPEC_N = 12
WIDTH = 42


def glyphs(s):
    return len(re.sub(r"\{[0-9a-f]+\}", "#", s))


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    p = lambda *a: os.path.join(root, *a)
    eng = open(p("original", "ETC", "FONT.BIN"), "rb").read()[BLOCK_OFF:BLOCK_OFF + BLOCK_SIZE]
    movie_src = p("patch", "files", "BIN01", "MOVIE.BIN")
    if not os.path.exists(movie_src):
        movie_src = p("original", "BIN01", "MOVIE.BIN")
    movie = bytearray(open(movie_src, "rb").read())
    orig_movie = open(p("original", "BIN01", "MOVIE.BIN"), "rb").read()

    tab = [struct.unpack_from("<I", orig_movie, TAB + 4 * k)[0] for k in range(TAB_N)]
    spec = [struct.unpack_from("<H", orig_movie, SPEC + 2 * j)[0] for j in range(SPEC_N)]

    def eng_entry(off):
        return eng[off:eng.index(b"\xff", off)]

    tr = {}
    for n, line in enumerate(open(p("traducao", "ENCICLOPEDIA.tsv"), encoding="utf-8")):
        if n == 0:
            continue
        cols = line.rstrip("\n").split("\t")
        if len(cols) >= 3 and cols[2].strip():
            tr[cols[0]] = cols[2]

    erros = []

    def entry(key, off):
        s = tr.get(key)
        if s is None:
            return eng_entry(off)
        for ln in s.split("|"):
            if glyphs(ln) > WIDTH:
                erros.append("%s: linha com mais de %d caracteres: %s" % (key, WIDTH, ln))
        if len(s.split("|")) > 4:
            erros.append("%s: mais de 4 linhas" % key)
        try:
            return bptext.encode(s)
        except Exception as e:  # caractere sem glifo
            erros.append("%s: %s" % (key, e))
            return b""

    out = bytearray(eng[:HEADER])
    new_tab, new_spec = [], []
    for k, v in enumerate(tab):
        if len(out) & 1:
            out.append(0)
        new_tab.append((v & 0xFFFF0000) | len(out))
        out += entry("T%d" % k, v & 0xFFFF) + b"\xff"
    for j, o in enumerate(spec):
        if len(out) & 1:
            out.append(0)
        new_spec.append(len(out))
        out += entry("S%d" % j, o) + b"\xff"
    if erros:
        print("\n".join(erros))
        raise SystemExit("ERRO na enciclopedia.")
    if len(out) > BLOCK_SIZE:
        raise SystemExit("Enciclopedia grande demais: %d bytes (limite %d)" % (len(out), BLOCK_SIZE))
    out += bytes(BLOCK_SIZE - len(out))

    font_path = p("patch", "files", "ETC", "FONT.BIN")
    font = bytearray(open(font_path, "rb").read())
    font[BLOCK_OFF:BLOCK_OFF + BLOCK_SIZE] = out
    open(font_path, "wb").write(font)

    for k, v in enumerate(new_tab):
        struct.pack_into("<I", movie, TAB + 4 * k, v)
    for j, v in enumerate(new_spec):
        struct.pack_into("<H", movie, SPEC + 2 * j, v)
    os.makedirs(p("patch", "files", "BIN01"), exist_ok=True)
    open(p("patch", "files", "BIN01", "MOVIE.BIN"), "wb").write(movie)
    print("Enciclopedia: %d entradas, %d de %d bytes" % (len(tab) + len(spec), len(out.rstrip(b'\0')), BLOCK_SIZE))


if __name__ == "__main__":
    main()
