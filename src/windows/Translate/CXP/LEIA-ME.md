# Tradutor de comentários CX-Programmer (.cxp)

Traduz os comentários (I/O, rungs, comentários anexados e colunas multilíngues) de projetos
CX-Programmer em japonês. A lógica ladder não é alterada e o `.cxp` original nunca é modificado.

Requer só Python 3 (sem bibliotecas extras).

## Arquivos
- `traduzir_cxp.py`: a ferramenta.
- `glossario.tsv`: traduções já feitas (texto original TAB tradução, UTF-8). Cresce a cada projeto.

## Passo a passo para um novo projeto

1. **Extrair** os textos que o glossário ainda não conhece:
   ```
   python traduzir_cxp.py extrair C:\caminho\projeto.cxp
   ```
   Isso gera `projeto_pendentes.tsv` com as colunas: original | tradução | dica em inglês.
   Textos que já estão em inglês vêm preenchidos.

2. **Traduzir** os pendentes: preencha a 2ª coluna (num editor de texto ou no Excel, salvando
   como texto separado por tabulação, UTF-8). Também dá para pedir ao Claude:
   "traduza o arquivo projeto_pendentes.tsv seguindo o glossario.tsv".
   - `«0»`, `«1»`... são números do texto original. Mantenha-os na tradução (pode mudar a ordem
     ou tirar). Também aceita `{0}`, `{1}`.
   - Não use aspas duplas (`"`).

3. **Mesclar** no glossário:
   ```
   python traduzir_cxp.py mesclar C:\caminho\projeto_pendentes.tsv
   ```

4. **Aplicar**:
   ```
   python traduzir_cxp.py aplicar C:\caminho\projeto.cxp                  (com acentos)
   python traduzir_cxp.py aplicar C:\caminho\projeto.cxp --sem-acentos    (sem acentos)
   ```
   Gera `projeto_traduzido.cxp` / `projeto_traduzido_sem_acentos.cxp` (e copia o `.opt`).
   Se faltar alguma tradução, o comando avisa e não gera nada.

## Acentos
O CX-Programmer lê os textos na codificação do "Idioma para programas não Unicode" do Windows.
- Versão **com acentos**: precisa do Windows configurado em Português/Inglês (cp1252).
- Versão **sem acentos**: funciona em qualquer configuração (inclusive chinês/japonês).

## Limitações
- Feito para projetos em japonês (Shift-JIS). Projetos salvos em Windows chinês têm outra
  codificação: troque `COD_ORIGEM = 'cp932'` por `'gbk'` no início do script.
- O nome do projeto e do PLC não são traduzidos.
