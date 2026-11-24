"""Remonta os arquivos de texto do Baroque com as traducoes e corrige as
referencias no codigo (executavel e overlays).

  python textpack.py <raiz do projeto>

Le tools/textpack.json, que lista cada arquivo de texto com:
  text     caminho dentro do disco (ex.: ETC/BP.MSB)
  table    tabela de traducao (ex.: traducao/BP.tsv)
  refs     lista de referencias (ex.: tools/textrefs/BP.json)
  maxsize  tamanho maximo em bytes (limitado pelos setores do arquivo no disco)
  drop_from  (opcional) indice a partir do qual as mensagens sao enchimento
           sem referencia e podem ser descartadas

Parte sempre dos arquivos intactos em original/ e grava o resultado em
patch/files/ (texto e overlays alterados). O executavel e a excecao: parte de
build/SLPM_863.41 (ja com o patch do armips) e e gravado de volta nele, entao
rode sempre depois do armips (o .bat faz isso).

Opcional no arquivo de referencias: "fixed": N  -> as mensagens 0..N-1 nao
podem mudar de posicao (tem referencias que nao foram mapeadas).

Formato do texto: cada mensagem termina em 0xFF; a mensagem seguinte comeca
em endereco par (se precisar, um 0x00 de alinhamento entra no meio). As
referencias apontam para o inicio (alinhado) de cada mensagem e podem ser:
  rel16   meia-palavra com o deslocamento dentro do arquivo
  abs_lo  instrucao com os 16 bits baixos do endereco absoluto (lui em 'lui')
  ptr32   palavra com o endereco absoluto
"""
import json, os, struct, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bptext


def parse(data):
    """Lista de (inicio, fim) de cada mensagem; fim = posicao do 0xFF.
    Zeros no fim do arquivo sao preenchimento, nao mensagem."""
    msgs, i = [], 0
    while i < len(data):
        if not data[i:].strip(b'\x00'):
            break
        j = data.find(b'\xff', i)
        if j < 0:
            msgs.append((i, len(data)))
            break
        msgs.append((i, j))
        i = j + 1
        if i % 2 == 1 and i < len(data) and data[i] == 0:
            i += 1
    return msgs


def build(contents, aligned):
    """Monta o arquivo: conteudo + 0xFF. Mensagens que comecavam em endereco
    par no original continuam em endereco par (com um 0x00 antes, se precisar)."""
    out = bytearray()
    starts = []
    for c, al in zip(contents, aligned):
        if al and len(out) % 2 == 1:
            out.append(0)
        starts.append(len(out))
        out += c + b'\xff'
    return bytes(out), starts


def read_table(path):
    rows = {}
    if not os.path.exists(path):
        return rows
    lines = open(path, encoding='utf-8').read().splitlines()
    for line in lines[1:]:
        cols = line.split('\t')
        if len(cols) >= 5 and cols[4] != '':
            rows[int(cols[0])] = cols[4]
    return rows


def export_table(data, path):
    msgs = parse(data)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('indice\toffset\tbytes\tingles\ttraducao\n')
        for n, (s, e) in enumerate(msgs):
            f.write('%d\t%04x\t%d\t%s\t\n' % (n, s, e - s, bptext.decode(data[s:e]).replace('\t', ' ')))


class Files:
    """Copias em memoria dos arquivos do disco que recebem correcoes."""
    def __init__(self, root):
        self.root = root
        self.cache = {}

    EXE = 'SLPM_863.41'

    def src(self, rel):
        if rel == self.EXE:
            return os.path.join(self.root, 'build', rel)
        return os.path.join(self.root, 'original', rel)

    def dst(self, rel):
        if rel == self.EXE:
            return os.path.join(self.root, 'build', rel)
        return os.path.join(self.root, 'patch', 'files', rel)

    def get(self, rel):
        if rel not in self.cache:
            self.cache[rel] = bytearray(open(self.src(rel), 'rb').read())
        return self.cache[rel]


def patch_refs(files, spec, new_starts, old_starts):
    base = spec['base']
    hi_written = {}
    for r in spec['refs']:
        buf = files.get(r['file'])
        new_off = new_starts[r['msg']]
        o = r['offset']
        if r['kind'] == 'rel16':
            old = struct.unpack_from('<H', buf, o)[0]
            if old != old_starts[r['msg']]:
                raise SystemExit('%s+%x: esperava %x, achou %x' % (r['file'], o, old_starts[r['msg']], old))
            struct.pack_into('<H', buf, o, new_off)
        elif r['kind'] == 'ptr32':
            old = struct.unpack_from('<I', buf, o)[0]
            if old != base + old_starts[r['msg']]:
                raise SystemExit('%s+%x: esperava %x, achou %x' % (r['file'], o, base + old_starts[r['msg']], old))
            struct.pack_into('<I', buf, o, base + new_off)
        elif r['kind'] == 'abs_lo':
            addr = base + new_off
            w = struct.unpack_from('<I', buf, o)[0]
            op = w >> 26
            if (w & 0xFFFF) != ((base + old_starts[r['msg']]) & 0xFFFF):
                raise SystemExit('%s+%x: instrucao inesperada %08x' % (r['file'], o, w))
            lo = addr & 0xFFFF
            hi = (addr >> 16) if op == 0x0D else ((addr + 0x8000) >> 16) & 0xFFFF
            struct.pack_into('<I', buf, o, (w & 0xFFFF0000) | lo)
            k = r['lui']
            lw = struct.unpack_from('<I', buf, k)[0]
            key = (r['file'], k)
            if hi_written.get(key, hi) != hi:
                raise SystemExit('%s+%x: lui compartilhado com valores diferentes' % (r['file'], k))
            hi_written[key] = hi
            struct.pack_into('<I', buf, k, (lw & 0xFFFF0000) | hi)


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else '.'
    cfg = json.load(open(os.path.join(root, 'tools', 'textpack.json'), encoding='utf-8'))
    files = Files(root)
    outdir = os.path.join(root, 'patch', 'files')
    for spec_cfg in cfg:
        spec = json.load(open(os.path.join(root, spec_cfg['refs']), encoding='utf-8'))
        rel = spec_cfg['text']
        orig = open(os.path.join(root, 'original', rel), 'rb').read()
        msgs = parse(orig)
        old_starts = [s for s, e in msgs]
        table = os.path.join(root, spec_cfg['table'])
        if not os.path.exists(table):
            export_table(orig, table)
            print('tabela criada:', spec_cfg['table'])
        tr = read_table(table)

        contents = []
        long_ = 0
        for n, (s, e) in enumerate(msgs):
            en = orig[s:e]
            if n in tr:
                try:
                    pt = bptext.encode(tr[n])
                except ValueError as ex:
                    raise SystemExit('%s #%d: %s' % (spec_cfg['table'], n, ex))
                if spec_cfg.get('pad_to_original', True) and len(pt) < len(en):
                    pt += bytes(len(en) - len(pt))      # mantem a largura (espacos)
                long_ += len(pt) > len(en)
                contents.append(pt)
            else:
                contents.append(en)
        aligned = [st % 2 == 0 for st in old_starts]
        drop = spec_cfg.get('drop_from')
        if drop and tr:
            # mensagens de enchimento ("MISSING") sem referencia: saem para dar espaco
            contents, aligned = contents[:drop], aligned[:drop]
        new, new_starts = build(contents, aligned)
        if not tr:
            # sem traducao: tem que reproduzir o original byte a byte
            if new + bytes(len(orig) - len(new)) != orig:
                raise SystemExit('%s: remontagem nao reproduz o original' % rel)
            new = orig
        maxsize = spec_cfg['maxsize']
        if len(new) > maxsize:
            raise SystemExit('%s: %d bytes, passa do limite de %d' % (rel, len(new), maxsize))
        if len(new) < len(orig):
            new = new + bytes(len(orig) - len(new))
        for n in range(spec.get('fixed', 0)):
            if new_starts[n] != old_starts[n]:
                raise SystemExit('%s: a mensagem #%d mudou de posicao; as mensagens 0..%d '
                                 'nao podem ficar maiores que o ingles'
                                 % (spec_cfg['table'], n, spec['fixed'] - 2))
        patch_refs(files, spec, new_starts, old_starts)
        dst = os.path.join(outdir, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        open(dst, 'wb').write(new)
        print('%s: %d traducoes (%d maiores que o ingles), %d bytes (limite %d)'
              % (rel, len(tr), long_, len(new), maxsize))

    for rel, buf in files.cache.items():
        dst = files.dst(rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        open(dst, 'wb').write(bytes(buf))
        print('referencias corrigidas em', rel)


if __name__ == '__main__':
    main()
