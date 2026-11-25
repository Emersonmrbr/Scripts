"""Tradutor de comentários de projetos CX-Programmer (.cxp).

Uso:
  python traduzir_cxp.py extrair  <projeto.cxp>
      Gera <projeto>_pendentes.tsv com os textos que ainda não estão no glossário.
  python traduzir_cxp.py mesclar  <projeto>_pendentes.tsv
      Copia para o glossário as linhas do arquivo de pendentes que já têm tradução.
  python traduzir_cxp.py aplicar  <projeto.cxp> [--sem-acentos]
      Gera <projeto>_traduzido.cxp (ou <projeto>_traduzido_sem_acentos.cxp).
      O arquivo original nunca é alterado.

Glossário: glossario.tsv (UTF-8), ao lado deste script, uma linha por padrão:
  <texto original>\t<tradução>
Números viram marcadores «0», «1»... (também aceita {0}, {1} na tradução).
A tradução pode reordenar ou omitir marcadores.

Formato .cxp: texto (Shift-JIS) compactado com PKWARE DCL implode.
"""
import json
import os
import re
import sys
import unicodedata

AQUI = os.path.dirname(os.path.abspath(__file__))
GLOSSARIO = os.path.join(AQUI, 'glossario.tsv')
COD_ORIGEM = 'cp932'     # codificação dos .cxp japoneses
COD_DESTINO = 'cp1252'   # Windows ocidental

# ---------------------------------------------------------------- blast/implode
MAXBITS = 13
LITLEN = [11, 124, 8, 7, 28, 7, 188, 13, 76, 4, 10, 8, 12, 10, 12, 10, 8, 23, 8,
          9, 7, 6, 7, 8, 7, 6, 55, 8, 23, 24, 12, 11, 7, 9, 11, 12, 6, 7, 22, 5,
          7, 24, 6, 11, 9, 6, 7, 22, 7, 11, 38, 7, 9, 8, 25, 11, 8, 11, 9, 12,
          8, 12, 5, 38, 5, 38, 5, 11, 7, 5, 6, 21, 6, 10, 53, 8, 7, 24, 10, 27,
          44, 253, 253, 253, 252, 252, 252, 13, 12, 45, 12, 45, 12, 61, 12, 45,
          44, 173]
LENLEN = [2, 35, 36, 53, 38, 23]
DISTLEN = [2, 20, 53, 230, 247, 151, 248]
BASE = [3, 2, 4, 5, 6, 7, 8, 9, 10, 12, 16, 24, 40, 72, 136, 264]
EXTRA = [0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8]


def _lengths(rep):
    out = []
    for b in rep:
        out += [b & 15] * ((b >> 4) + 1)
    return out


class _Huff:
    def __init__(self, rep):
        lengths = _lengths(rep)
        self.count = [0] * (MAXBITS + 1)
        for l in lengths:
            self.count[l] += 1
        offs = [0] * (MAXBITS + 1)
        for l in range(1, MAXBITS):
            offs[l + 1] = offs[l] + self.count[l]
        self.symbol = [0] * len(lengths)
        for s, l in enumerate(lengths):
            if l:
                self.symbol[offs[l]] = s
                offs[l] += 1


_LIT, _LEN, _DIST = _Huff(LITLEN), _Huff(LENLEN), _Huff(DISTLEN)


def descompactar(data):
    pos = 0
    bitbuf = bitcnt = 0

    def bits(need):
        nonlocal pos, bitbuf, bitcnt
        val = bitbuf
        while bitcnt < need:
            val |= data[pos] << bitcnt
            pos += 1
            bitcnt += 8
        bitbuf = val >> need
        bitcnt -= need
        return val & ((1 << need) - 1)

    def decode(h):
        code = first = index = 0
        for length in range(1, MAXBITS + 1):
            code |= bits(1) ^ 1
            count = h.count[length]
            if code < first + count:
                return h.symbol[index + (code - first)]
            index += count
            first = (first + count) << 1
            code <<= 1
        raise ValueError('código inválido')

    lit, dic = bits(8), bits(8)
    if lit > 1 or not 4 <= dic <= 6:
        raise ValueError('não é um arquivo PKWARE implode')
    out = bytearray()
    while True:
        if bits(1):
            s = decode(_LEN)
            length = BASE[s] + bits(EXTRA[s])
            if length == 519:
                break
            sh = 2 if length == 2 else dic
            dist = (decode(_DIST) << sh) + bits(sh) + 1
            start = len(out) - dist
            for k in range(length):
                out.append(out[start + k])
        else:
            out.append(decode(_LIT) if lit else bits(8))
    return bytes(out)


def _canon(rep):
    lengths = _lengths(rep)
    codes, code = {}, 0
    for ln in range(1, MAXBITS + 1):
        for s, l in enumerate(lengths):
            if l == ln:
                codes[s] = (code, ln)
                code += 1
        code <<= 1
    return codes


_LENC, _DISTC = _canon(LENLEN), _canon(DISTLEN)


def compactar(data, dic=6):
    out = bytearray()
    buf = nb = 0

    def put(val, n):
        nonlocal buf, nb
        buf |= val << nb
        nb += n
        while nb >= 8:
            out.append(buf & 255)
            buf >>= 8
            nb -= 8

    def huff(codes, sym):
        c, ln = codes[sym]
        for k in range(ln - 1, -1, -1):
            put(((c >> k) & 1) ^ 1, 1)

    def lsym(length):
        for s in range(16):
            if BASE[s] <= length < BASE[s] + (1 << EXTRA[s]):
                return s

    put(0, 8)
    put(dic, 8)
    win, n = 64 << dic, len(data)
    head, prev = {}, [-1] * n

    def insert(p):
        if p + 2 < n:
            k = data[p:p + 3]
            prev[p] = head.get(k, -1)
            head[k] = p

    i = 0
    while i < n:
        blen = bdist = 0
        if i + 2 < n:
            cand, tries, lim = head.get(data[i:i + 3], -1), 48, min(518, n - i)
            while cand >= 0 and i - cand <= win and tries:
                l = 3
                while l < lim and data[cand + l] == data[i + l]:
                    l += 1
                if l > blen:
                    blen, bdist = l, i - cand
                    if l == lim:
                        break
                cand, tries = prev[cand], tries - 1
        if blen >= 3:
            s = lsym(blen)
            put(1, 1)
            huff(_LENC, s)
            put(blen - BASE[s], EXTRA[s])
            d = bdist - 1
            huff(_DISTC, d >> dic)
            put(d & ((1 << dic) - 1), dic)
            for p in range(i, i + blen):
                insert(p)
            i += blen
        else:
            put(0, 1)
            put(data[i], 8)
            insert(i)
            i += 1
    put(1, 1)
    huff(_LENC, 15)
    put(519 - BASE[15], EXTRA[15])
    if nb:
        out.append(buf & 255)
    return bytes(out)

# ---------------------------------------------------------------- localizar textos
NA = re.compile(r'[^\x00-\x7f]')
DIG = re.compile(r'[0-9０-９]+')
VAR_RE = re.compile(r'^(   [^,"]*,[^,"]*,[^,"]*,[^,"]*,[^,"]*,[^,"]*,)(.*)$')
QUOTED_RE = re.compile(r'^(\s*(?:Com|SecName|\d+):=")(.*)(";)$')
SPLIT = re.compile(r'(\r?\n|\$\?St\$Bk\?_#\[\d+\];?)')
JP = re.compile(r'[぀-ヺー-ヿｦ-ﾟ一-鿿]')


def normalizar(s):
    nums = DIG.findall(s)
    it = iter(range(1000))
    return DIG.sub(lambda m: '«%d»' % next(it), s), nums


def secoes(lines):
    sec = {'var': [], 'multi': []}
    cur = start = None
    for i, b in enumerate(lines):
        s = b.strip()
        if s == b'VariableList:=':
            cur = 'var'
        elif s in (b'VariableMultiCommentList:=', b'VariablePredefinedMultiCommentList:='):
            cur = 'multi'
        elif s.startswith(b'BEGIN_LIST_') and cur:
            start = i + 1
        elif s.startswith(b'END_LIST_') and cur and start is not None:
            sec[cur].append((start, i + 1))
            cur = start = None
    return sec


def unidades(lines):
    """Gera (chave, texto) de cada comentário com caracteres não-ASCII."""
    sec = secoes(lines)
    em = lambda i, k: any(a <= i < b for a, b in sec[k])
    for i, b in enumerate(lines):
        multi = em(i, 'multi')
        if not multi and not any(x > 127 for x in b):
            continue
        if multi:
            parts = b.split(b',')
            for j in (3, 4):
                if j < len(parts) and parts[j].rstrip(b';'):
                    try:
                        txt = bytes.fromhex(parts[j].rstrip(b';').decode()).decode(COD_ORIGEM)
                    except ValueError:
                        continue
                    if NA.search(txt):
                        yield ('hex', i, j), txt
            continue
        s = b.decode(COD_ORIGEM)
        if s.lstrip().startswith(('Name:=', 'ConnectedtoPLCName:=')):
            continue  # nomes do projeto/PLC: não mexer
        if em(i, 'var'):
            m = VAR_RE.match(s)
            if m:
                pre, body, suf = m.group(1), m.group(2), ''
                if body.endswith(';'):
                    body, suf = body[:-1], ';'
                if len(body) >= 2 and body[0] == body[-1] == '"':
                    body, pre, suf = body[1:-1], pre + '"', '"' + suf
                yield ('line', i, pre, suf, 'var'), body
                continue
        m = QUOTED_RE.match(s)
        if m:
            yield ('line', i, m.group(1), m.group(3), 'q'), m.group(2)
            continue
        pre = suf = ''
        body = s
        m1 = re.match(r'^(\$\?St\$Bk\?_#\[\d+\])(.*)$', body)
        if m1:
            pre, body = m1.groups()
        m2 = re.match(r'^(.*?)(\$\?St\$Bk\?_#\[\d+\];?)$', body)
        if m2:
            body, suf = m2.groups()
        yield ('line', i, pre, suf, 'free'), body


def segmentos(txt):
    ps = SPLIT.split(txt)
    return [(k, p) for k, p in enumerate(ps) if k % 2 == 0 and NA.search(p)], ps

# ---------------------------------------------------------------- glossário
def ler_glossario():
    g = {}
    if os.path.exists(GLOSSARIO):
        for ln in open(GLOSSARIO, encoding='utf-8').read().split('\n'):
            if '\t' in ln:
                k, v = ln.split('\t', 1)
                g[k] = v
    return g


def ler_cxp(path):
    return descompactar(open(path, 'rb').read()).split(b'\r\n')


SAN = {'→': '->', '←': '<-', '↑': '^', '↓': 'v', '～': '~', '〜': '~', 'θ': 'teta',
       '∟': '-', '（': '(', '）': ')', '：': ':', '　': ' ', '・': '/', '･': '/',
       '【': '[', '】': ']', '－': '-', '①': '1)', '②': '2)', '③': '3)', '④': '4)',
       '⑤': '5)', '※': '*', 'μ': 'µ', '，': ',', '＝': '=', '≧': '>=', '≦': '<=',
       '＞': '>', '＜': '<', '≠': '<>', '［': '[', '］': ']', '％': '%', '＋': '+',
       '／': '/', '＆': '&', '！': '!', '？': '?', '＃': '#', '　': ' '}
FW = str.maketrans('０１２３４５６７８９', '0123456789')
ASCII_EXTRA = {'µ': 'u', '×': 'x', 'ª': 'a', 'º': 'o', '±': '+/-', '°': 'graus'}


def sanear(s, sem_acentos):
    for a, b in SAN.items():
        s = s.replace(a, b)
    s = s.translate(FW)
    if sem_acentos:
        for a, b in ASCII_EXTRA.items():
            s = s.replace(a, b)
        s = unicodedata.normalize('NFKD', s).encode('ascii', 'ignore').decode('ascii')
    s.encode(COD_DESTINO)
    return s

# ---------------------------------------------------------------- comandos
def cmd_extrair(cxp):
    lines = ler_cxp(cxp)
    g = ler_glossario()
    sec = secoes(lines)
    eng = {}  # dica em inglês por endereço
    for a, b in sec['multi']:
        for i in range(a, b):
            p = lines[i].split(b',')
            if len(p) > 4 and p[4]:
                try:
                    e = bytes.fromhex(p[4].rstrip(b';').decode()).decode(COD_ORIGEM)
                except ValueError:
                    continue
                if not NA.search(e):
                    eng.setdefault(p[2].decode().strip(), e)
    pend = {}
    for key, txt in unidades(lines):
        dica = ''
        if key[0] == 'hex':
            dica = eng.get(lines[key[1]].split(b',')[2].decode().strip(), '')
        elif key[4] == 'var':
            dica = eng.get(lines[key[1]].decode(COD_ORIGEM).split(',')[1].strip(), '')
        for _, seg in segmentos(txt)[0]:
            p, _ = normalizar(seg)
            if p not in g and p not in pend:
                # texto em inglês com símbolos japoneses: tradução = ele mesmo
                pend[p] = (p if not JP.search(p) else '', dica)
    saida = os.path.splitext(cxp)[0] + '_pendentes.tsv'
    with open(saida, 'w', encoding='utf-8') as f:
        f.write('# original\ttradução\tdica (coluna em inglês)\n')
        for p, (t, d) in pend.items():
            f.write('%s\t%s\t%s\n' % (p, t, d))
    vazios = sum(1 for t, _ in pend.values() if not t)
    print('%d textos novos (%d precisam de tradução) -> %s' % (len(pend), vazios, saida))


def cmd_mesclar(tsv):
    g = ler_glossario()
    novos = 0
    vazios = 0
    for ln in open(tsv, encoding='utf-8').read().split('\n'):
        if not ln.strip() or ln.startswith('#'):
            continue
        cols = ln.split('\t')
        if len(cols) < 2 or not cols[1].strip():
            vazios += 1
            continue
        if cols[0] not in g:
            novos += 1
        g[cols[0]] = re.sub(r'\{(\d+)\}', r'«\1»', cols[1])
    with open(GLOSSARIO, 'w', encoding='utf-8') as f:
        for k, v in g.items():
            f.write('%s\t%s\n' % (k, v))
    print('%d entradas adicionadas, %d ainda sem tradução. Glossário: %d entradas' % (novos, vazios, len(g)))


def cmd_aplicar(cxp, sem_acentos):
    lines = ler_cxp(cxp)
    g = ler_glossario()
    novo = list(lines)
    faltando = set()
    hexed = {}

    def traduzir(txt):
        idx, ps = segmentos(txt)
        for k, seg in idx:
            p, nums = normalizar(seg)
            if p not in g:
                faltando.add(p)
                continue
            t = re.sub(r'«(\d+)»', lambda m: nums[int(m.group(1))] if int(m.group(1)) < len(nums) else '', g[p])
            ps[k] = sanear(t.replace('"', "'"), sem_acentos)
        return ''.join(ps)

    for key, txt in unidades(lines):
        t = traduzir(txt)
        if key[0] == 'hex':
            hexed.setdefault(key[1], {})[key[2]] = t
        else:
            _, i, pre, suf, kind = key
            if kind == 'var' and ',' in t and not pre.endswith('"'):
                pre, suf = pre + '"', '"' + suf
            novo[i] = (pre + t + suf).encode(COD_DESTINO)
    if faltando:
        print('ERRO: %d textos sem tradução no glossário. Rode "extrair" primeiro.' % len(faltando))
        for p in list(faltando)[:10]:
            print('   ', p)
        sys.exit(1)
    for i, ed in hexed.items():
        parts = lines[i].split(b',')
        for j, t in ed.items():
            semi = parts[j].endswith(b';')
            parts[j] = t.encode(COD_DESTINO).hex().encode() + (b';' if semi else b'')
        novo[i] = b','.join(parts)
    for i, b in enumerate(novo):  # renomeia a coluna japonesa para PT
        if b.strip().startswith(b'VariableMultiCommentHeader:='):
            def rel(m):
                lab = bytes.fromhex(m.group(0)).decode(COD_ORIGEM)
                lab = lab.replace('ｺﾒﾝﾄ', 'Comment').replace('(JP)', '(PT)').replace('(J)', '(PT)')
                return sanear(lab, True).encode(COD_DESTINO).hex()
            novo[i] = re.sub(r'[0-9a-f]{6,}', rel, b.decode('ascii')).encode('ascii')
    texto = b'\r\n'.join(novo)
    comp = compactar(texto)
    assert descompactar(comp) == texto, 'falha na verificação da compactação'
    base = os.path.splitext(cxp)[0]
    saida = base + ('_traduzido_sem_acentos.cxp' if sem_acentos else '_traduzido.cxp')
    open(saida, 'wb').write(comp)
    if os.path.exists(base + '.opt'):
        open(os.path.splitext(saida)[0] + '.opt', 'wb').write(open(base + '.opt', 'rb').read())
    print('OK -> %s' % saida)


if __name__ == '__main__':
    a = sys.argv[1:]
    if len(a) >= 2 and a[0] == 'extrair':
        cmd_extrair(a[1])
    elif len(a) >= 2 and a[0] == 'mesclar':
        cmd_mesclar(a[1])
    elif len(a) >= 2 and a[0] == 'aplicar':
        cmd_aplicar(a[1], '--sem-acentos' in a)
    else:
        print(__doc__)
