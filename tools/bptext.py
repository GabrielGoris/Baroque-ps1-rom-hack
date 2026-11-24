"""Texto do Baroque (PS1, versao em ingles): decodifica, exporta e aplica traducoes.

  python bptext.py export <arquivo.MSB> <saida.tsv>
      Gera uma tabela (indice, ingles, traducao) com uma linha por mensagem.

  python bptext.py apply <arquivo.MSB original> <tabela.tsv> <saida.MSB>
      Aplica as traducoes preenchidas SEM mudar o tamanho de cada mensagem
      (completa com espacos; avisa se a traducao for longa demais).

Convencoes na tabela: '|' = quebra de linha, {xx} = byte em hexa
(icones de botao, codigos de controle), {xxyy} = caractere de 2 bytes.
"""
import sys, re

ENC = {' ': 0x00, '|': 0xFE}
for i in range(26):
    ENC[chr(65 + i)] = 0xBC + i
    ENC[chr(97 + i)] = 0xD6 + i
for i in range(10):
    ENC[str(i)] = 0xA2 + i
ENC.update({'>': 0xA0, '<': 0xA1, '…': 0xAC, ':': 0xAD, '?': 0xAE, '!': 0xAF, "'": 0xB1,
            '“': 0xB2, '”': 0xB3, '(': 0xB4, ')': 0xB5, '[': 0xB6, ']': 0xB7, ',': 0xBA,
            '.': 0xBB, '+': 0xF0, '-': 0xF1, '&': 0xF3, '/': 0xF4})
# letras acentuadas desenhadas por fontaccents.py
ENC.update({'á': 0x30, 'à': 0x31, 'â': 0x32, 'ã': 0x33, 'é': 0x34, 'ê': 0x35, 'í': 0x36,
            'ó': 0x37, 'ô': 0x38, 'õ': 0x39, 'ú': 0x3A, 'ç': 0x3B, 'Á': 0x40, 'À': 0x41,
            'Â': 0x42, 'Ã': 0x43, 'É': 0x44, 'Ê': 0x45, 'Í': 0x46, 'Ó': 0x47, 'Ô': 0x48,
            'Õ': 0x49, 'Ú': 0x4A, 'Ç': 0x4B, '"': 0xB2})
DEC = {v: k for k, v in ENC.items() if k not in '"'}
DEC[0xB2] = '“'


def decode(b):
    out, i = [], 0
    while i < len(b):
        x = b[i]
        if x in (0xF8, 0xF9, 0xFA) and i + 1 < len(b):
            out.append('{%02x%02x}' % (x, b[i + 1])); i += 2; continue
        out.append(DEC.get(x, '{%02x}' % x)); i += 1
    return ''.join(out)


def encode(s):
    out = bytearray()
    for tok in re.findall(r'\{[0-9a-fA-F]+\}|.', s):
        if tok.startswith('{'):
            out += bytes.fromhex(tok[1:-1])
        elif tok in ENC:
            out.append(ENC[tok])
        else:
            raise ValueError('caractere sem glifo: %r' % tok)
    return bytes(out)


def split(data):
    msgs, i = [], 0
    while i < len(data):
        j = data.find(b'\xff', i)
        if j < 0:
            msgs.append((i, data[i:])); break
        msgs.append((i, data[i:j])); i = j + 1
    return msgs


def tsv_escape(s):
    return s.replace('\t', ' ')


def cmd_export(src, dst):
    data = open(src, 'rb').read()
    with open(dst, 'w', encoding='utf-8', newline='\n') as f:
        f.write('indice\toffset\tbytes\tingles\ttraducao\n')
        for n, (off, m) in enumerate(split(data)):
            f.write('%d\t%04x\t%d\t%s\t\n' % (n, off, len(m), tsv_escape(decode(m))))
    print('exportado:', dst)


def cmd_apply(src, table, dst):
    data = bytearray(open(src, 'rb').read())
    msgs = split(bytes(data))
    done = skipped = 0
    for line in open(table, encoding='utf-8').read().splitlines()[1:]:
        cols = line.split('\t')
        if len(cols) < 5 or not cols[4].strip():
            continue
        n = int(cols[0]); pt = cols[4]
        off, orig = msgs[n]
        enc = encode(pt)
        if len(enc) > len(orig):
            print('  #%d longa demais (%d > %d bytes), mantida em ingles: %s' % (n, len(enc), len(orig), pt))
            skipped += 1
            continue
        enc = enc + bytes(len(orig) - len(enc))      # completa com espacos
        data[off:off + len(orig)] = enc
        done += 1
    open(dst, 'wb').write(data)
    print('%s: %d mensagens traduzidas, %d puladas' % (dst, done, skipped))


if __name__ == '__main__':
    a = sys.argv[1:]
    if a and a[0] == 'export' and len(a) == 3:
        cmd_export(a[1], a[2])
    elif a and a[0] == 'apply' and len(a) == 4:
        cmd_apply(a[1], a[2], a[3])
    else:
        print(__doc__); sys.exit(1)
