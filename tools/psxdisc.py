"""Ferramenta pequena para imagens .bin (MODE2/2352) de PS1.

  python psxdisc.py inject <imagem.bin> <arquivo_no_disco> <arquivo_novo>
      Grava <arquivo_novo> por cima de <arquivo_no_disco> (ex.: SLPM_863.41
      ou BIN00/ALGUMA.BIN) dentro da imagem, recalculando EDC/ECC.
      O arquivo novo precisa ter o mesmo tamanho do original.

  python psxdisc.py injectdir <imagem.bin> <pasta>
      Grava todos os arquivos da pasta (ex.: patch/files/ETC/FONT.BIN vira
      ETC/FONT.BIN no disco). Cada um precisa ter o tamanho do original.

  python psxdisc.py fixsectors <imagem.bin> <setor> [<setor> ...]
      Recalcula EDC/ECC de setores Mode 2 Form 1.

  python psxdisc.py check <imagem.bin>
      Lista setores Form 1 com EDC invalido.
"""
import os, struct, sys

SECTOR = 2352
_EDC = []
for i in range(256):
    e = i
    for _ in range(8):
        e = (e >> 1) ^ (0xD8018001 if e & 1 else 0)
    _EDC.append(e)
_F = [0] * 256
_B = [0] * 256
for i in range(256):
    j = ((i << 1) ^ (0x11D if i & 0x80 else 0)) & 0xFF
    _F[i] = j
    _B[i ^ j] = i


def edc(data):
    e = 0
    for x in data:
        e = (e >> 8) ^ _EDC[(e ^ x) & 0xFF]
    return e


def _ecc_block(src, majc, minc, majm, mini, dest, doff):
    size = majc * minc
    for major in range(majc):
        idx = (major >> 1) * majm + (major & 1)
        a = b = 0
        for _ in range(minc):
            t = src[idx]
            idx += mini
            if idx >= size:
                idx -= size
            a ^= t
            b ^= t
            a = _F[a]
        a = _B[_F[a] ^ b]
        dest[doff + major] = a
        dest[doff + major + majc] = a ^ b


def fix_form1(sec):
    sec = bytearray(sec)
    sec[0x818:0x81C] = edc(sec[0x10:0x818]).to_bytes(4, "little")
    addr = bytes(sec[12:16])
    sec[12:16] = b"\0\0\0\0"
    _ecc_block(bytes(sec[0xC:]), 86, 24, 2, 86, sec, 0x81C)
    _ecc_block(bytes(sec[0xC:]), 52, 43, 86, 88, sec, 0x8C8)
    sec[12:16] = addr
    return bytes(sec)


def read_user(f, lba):
    f.seek(lba * SECTOR)
    return f.read(SECTOR)[24:24 + 2048]


def find_file(f, path):
    pvd = read_user(f, 16)
    if pvd[1:6] != b"CD001":
        raise SystemExit("Imagem sem ISO9660 no setor 16")
    rec = pvd[156:156 + 34]
    lba, size = struct.unpack("<I", rec[2:6])[0], struct.unpack("<I", rec[10:14])[0]
    parts = [p for p in path.replace("\\", "/").upper().split("/") if p]
    for depth, name in enumerate(parts):
        found = None
        for s in range((size + 2047) // 2048):
            d = read_user(f, lba + s)
            off = 0
            while off < 2048 and d[off]:
                ln = d[off]
                r = d[off:off + ln]
                nlen = r[32]
                ident = r[33:33 + nlen].decode("ascii", "replace").upper().split(";")[0]
                if ident == name:
                    found = (struct.unpack("<I", r[2:6])[0], struct.unpack("<I", r[10:14])[0], r[25], lba + s, off)
                    break
                off += ln
            if found:
                break
        if not found:
            raise SystemExit("Nao achei %s no disco" % "/".join(parts[:depth + 1]))
        lba, size, flags, rec_lba, rec_off = found
    find_file.last_record = (rec_lba, rec_off)
    return lba, size


def cmd_inject(img, path, newfile):
    data = open(newfile, "rb").read()
    with open(img, "r+b") as f:
        lba, size = find_file(f, path)
        rec_lba, rec_off = find_file.last_record
        sectors = (size + 2047) // 2048
        if len(data) != size:
            if (len(data) + 2047) // 2048 > sectors:
                raise SystemExit("%s: %d bytes nao cabem nos %d setores do arquivo (max %d bytes)."
                                 % (path, len(data), sectors, sectors * 2048))
            # atualiza o tamanho no registro de diretorio (ambos os endians)
            f.seek(rec_lba * SECTOR)
            sec = bytearray(f.read(SECTOR))
            o = 24 + rec_off
            sec[o + 10:o + 14] = struct.pack("<I", len(data))
            sec[o + 14:o + 18] = struct.pack(">I", len(data))
            f.seek(rec_lba * SECTOR)
            f.write(fix_form1(sec))
            print("  tamanho de %s no diretorio: %d -> %d bytes" % (path, size, len(data)))
            size = len(data)
        changed = 0
        for i in range(sectors):
            f.seek((lba + i) * SECTOR)
            sec = bytearray(f.read(SECTOR))
            if sec[15] != 2 or sec[18] & 0x20:
                raise SystemExit("Setor %d nao e Mode 2 Form 1" % (lba + i))
            chunk = data[i * 2048:(i + 1) * 2048]
            chunk = chunk + bytes(2048 - len(chunk)) if len(chunk) < 2048 else chunk
            if bytes(sec[24:24 + 2048]) == chunk:
                continue
            sec[24:24 + 2048] = chunk
            f.seek((lba + i) * SECTOR)
            f.write(fix_form1(sec))
            changed += 1
    print("%s: LBA %d, %d bytes, %d setores alterados" % (path, lba, size, changed))


def cmd_injectdir(img, folder):
    for root, dirs, files in os.walk(folder):
        dirs.sort()
        for name in sorted(files):
            full = os.path.join(root, name)
            rel = os.path.relpath(full, folder).replace(os.sep, "/")
            cmd_inject(img, rel, full)


def cmd_fix(img, sectors):
    with open(img, "r+b") as f:
        for s in sectors:
            f.seek(s * SECTOR)
            x = f.read(SECTOR)
            y = fix_form1(x)
            if x != y:
                f.seek(s * SECTOR)
                f.write(y)
            print("setor %d: %s" % (s, "corrigido" if x != y else "ja estava ok"))


def cmd_check(img):
    bad = 0
    n = os.path.getsize(img) // SECTOR
    with open(img, "rb") as f:
        for s in range(n):
            sec = f.read(SECTOR)
            if sec[15] == 2 and not sec[18] & 0x20:
                if edc(sec[16:0x818]) != int.from_bytes(sec[0x818:0x81C], "little"):
                    bad += 1
                    print("EDC invalido no setor", s)
    print("setores com erro:", bad)


if __name__ == "__main__":
    a = sys.argv[1:]
    try:
        open(a[1], "r+b").close() if len(a) > 1 and a[0] in ("inject", "injectdir", "fixsectors") else None
    except PermissionError:
        raise SystemExit("A imagem esta em uso (provavelmente aberta no DuckStation). "
                         "Feche o jogo no emulador e rode de novo.")
    if len(a) == 4 and a[0] == "inject":
        cmd_inject(a[1], a[2], a[3])
    elif len(a) == 3 and a[0] == "injectdir":
        cmd_injectdir(a[1], a[2])
    elif len(a) >= 3 and a[0] == "fixsectors":
        cmd_fix(a[1], [int(x) for x in a[2:]])
    elif len(a) == 2 and a[0] == "check":
        cmd_check(a[1])
    else:
        print(__doc__)
        sys.exit(1)
