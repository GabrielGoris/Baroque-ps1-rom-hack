# Baroque (PS1): hack de câmera e controles

## Situação atual
- `disc\Baroque (English).cue`: o jogo **já traduzido** (o seu dump japonês + tradução v1.0.2). É a base do hack.
  - O seu dump vem de uma fonte diferente da que o tradutor usou (o MD5 não bate com o README). A tradução foi aplicada mesmo assim e só 2 setores (16 e 22) precisaram de correção de EDC/ECC. O resto da imagem foi verificado setor por setor.
- `original\`: cópia intacta dos arquivos de código (executável `SLPM_863.41` e as pastas BIN00/BIN01/BIN02 etc.). Não mexa.
- `extracted\`: os mesmos arquivos, para abrir no Ghidra.

## Ferramentas (pasta tools)
- DuckStation (portátil), Ghidra 12.2 + plugin PS1 + Java 21, armips, mkpsxiso/dumpsxiso, xdelta3
- `psxdisc.py`: grava um arquivo modificado direto dentro da imagem `.bin`, recalculando EDC/ECC. Precisa de Python.

## Scripts
- `abrir_duckstation.bat` / `abrir_ghidra.bat`
- `2_aplicar_patch_e_montar.bat`: aplica `patch\main.asm` e gera `build\Baroque (Camera Hack).cue`
- `3_gerar_xdelta.bat`: gera `build\baroque_camera_hack.xdelta` (o patch para distribuir; nunca distribua a imagem)
- `0_aplicar_traducao.bat` e `1_extrair_disco.bat`: só se precisar refazer a tradução ou extrair tudo de novo

## Configurar o DuckStation (uma vez)
- **BIOS**: aponte para a pasta com o BIOS do seu PS1 (de preferência japonês; ou use o mesmo BIOS para todas as regiões).
- **Controle**: Porta 1 = *Analog Controller (DualShock)*.
- **Gráficos**: PGXP ligado; Widescreen Rendering se quiser.
- Abra `disc\Baroque (English).cue` para jogar/pesquisar.

## Próximo passo: achar o ângulo da câmera
1. Entre na torre e fique parado.
2. Abra o Memory Scanner (menu Ferramentas/Tools; se não aparecer, ative o menu de debug em Configurações → Avançado).
3. Busque valor de 16 bits (halfword), sem sinal, "unknown/qualquer".
4. Gire um pouco para a direita → filtre "aumentou" (ou "mudou"). Parado → "não mudou". Repita até sobrarem poucos.
5. Edite o valor: se a visão girar na hora, achou. Uma volta completa costuma ser 4096.
6. Faça o mesmo para a posição X/Z do jogador (32 bits, muda quando você anda).
7. Mande os endereços para o Claude.

## Descobertas (endereços na RAM)
- Personagem: estrutura em `0x800C066C`. Ângulo em `0x800C0672` (0–4095; girar para a direita diminui). Posição X/Y/Z em `0x800C0678` / `0x800C067C` / `0x800C0680` (32 bits). `0x80069112` e `0x800C0696` são cópias do ângulo.
- Controle cru: `0x800826F0` = [status, id, botões, botões, RX, RY, LX, LY]. id `0x73` = DualShock em modo analógico.
- O jogo já suportava o analógico esquerdo no estilo tanque (X gira, Y anda) e strafe no L1/R1. A rotina de giro fica em `0x80027534`.

## Patch atual (patch\main.asm)
- Analógico direito (X) gira a câmera.
- Analógico esquerdo: frente/trás anda; para os lados faz strafe (aperta L1/R1 por baixo dos panos).
- Analógico direito (Y) olha para cima/baixo (para cima = olhar para cima), até 45°. R3 volta a câmera para o centro. Usa a rotação X do personagem (`0x800C0670`).
- **Select + direcional cima/baixo**: muda a velocidade da câmera (5 níveis, começa no 3 = velocidade original), com som de cursor e um indicador de 5 barras no canto superior direito. Volta ao 3 quando o jogo reinicia.
- Só funciona com o controle em modo analógico (DualShock com a luz de "Analog" ligada).

## Distância de desenho
- Antes de desenhar cada objeto do cenário, o jogo (`GAME.BIN`, `0x800E209C`) descarta o que passa de um limite definido por `0x800E1590`. No modo normal de exploração (área de fora e andares) o limite era `0x240000`, mas a neblina só fica completa em `0x280000`, por isso o cenário "aparecia" na frente. O patch usa `0x2C0000` no modo normal e `0x300000` nos outros modos (`DRAW_FAR_NORMAL` / `DRAW_FAR_OTHER` no `main.asm`).
- Os níveis de detalhe ficam em `0x80069164` (`0x80000`) e `0x80069160` (`0x100000`).

## Espaço para código novo
- O código novo fica em `0x80051FF8`–`0x8005328F`: uma função de biblioteca (4760 bytes) que o jogo nunca chama. Sobram ~3,6 KB.
- A tela é 384x240, com dois buffers lado a lado. A troca de quadro fica em `0x8001CC08`; o indicador é desenhado logo depois da cena, com um segundo DrawOTag.

## Tradução pt-BR (em andamento)
- **Fonte:** `tools/fontaccents.py` desenha á à â ã é ê í ó ô õ ú ç (e maiúsculas) nos códigos 0x30–0x4B do `FONT.BIN`, que estavam vazios. Roda sozinho no `2_aplicar_patch_e_montar.bat`.
- **Textos:** `tools/textpack.py` remonta cada arquivo de texto listado em `tools/textpack.json` com a coluna `traducao` da tabela (`traducao/*.tsv`) e corrige todas as referências no código (listadas em `tools/textrefs/*.json`). As frases **podem ser maiores que o inglês**, até o limite de setores do arquivo no disco. Nos menus (`BP`), frases menores são completadas com espaços até a largura original; nos itens não (`"pad_to_original": false`), porque muitas frases são pedaços que o jogo junta com o nome do item.
- `tools/bptext.py`: codificação (tabela de caracteres) usada pelas outras ferramentas.
- `traducao/BP.tsv`: menus (título, Opções, cartão de memória), traduzido. 174 referências em `BIN01/MOVIE.BIN`. Termos: *suspend* = save de pausa (Retomar), *arising* = save de renascer (Renascer).
- `traducao/ITEM.tsv`: itens (nomes, descrições, comandos do menu de item e mensagens de status/combate), mensagens 9–680 traduzidas. 882 referências: `BIN01/GAME.BIN` (código e tabelas de ponteiros) e o executável (código e a tabela de pares nome/descrição em `0x80068750`–`0x80068C4C`). As mensagens 0–8 (LV, HP, VT, ATK, DEF, MAX) têm referências que não mudam entre japonês e inglês, então não podem crescer (`"fixed": 9`). As mensagens 681 em diante são enchimento (`MISSING`) que o tradutor do inglês colocou para manter o tamanho do arquivo; são descartadas (`"drop_from": 681`).
  - O ícone no começo do nome (`{7f}{80}` espada, `{81}{82}` casaco, `{83}{84}` asas, `{85}{86}` coração, `{79}{7a}` carne, `{87}{88}` caixa, `{89}{8a}` injeção, `{8b}{8c}` marca, `{93}{94}` torturador, `{8d}{8e}` padrão, `{8f}{90}` osso, `{91}{92}` verme, `{95}{96}` Sefirah) faz o papel do substantivo; os adjetivos concordam com ele (Espada Patética, Casaco Patético).
  - Descrições: até 20 caracteres por linha e 5 linhas. Nomes: até 13 caracteres. "Stomachache" virou **cólica**.
  - O executável é corrigido a partir de `build/SLPM_863.41` (depois do armips) e gravado de volta nele, por isso o `.bat` roda o armips antes do `textpack.py`.
- Na tabela: `|` = quebra de linha; `{xx}` = ícone de botão ou código de controle (não mexa).
- Tudo o que estiver em `patch/files/` é gravado na imagem com o mesmo caminho (ex.: `patch/files/ETC/FONT.BIN`).

### Como o jogo acha os textos
- Os arquivos de texto são carregados em endereços fixos (ex.: `CUD.MSB` em `0x801C0800`, `ITEM.MSB` em `0x801C1000`, `FONT.BIN` em `0x801C6800`, diálogos `MSG0/1/2.MSB` em `0x801B6800`), e o código aponta direto para o endereço de cada frase (`lui 0x801C` + `ori`).
- As referências de cada arquivo foram achadas comparando o jogo japonês com o inglês: o tradutor do inglês teve que corrigir cada uma, então toda referência a texto aparece como diferença entre os dois. A ferramenta guarda essa lista e não precisa do jogo japonês para montar.
- Mensagens terminam em `0xFF`; as que começavam em endereço par continuam em endereço par (com um `0x00` de alinhamento).

### Diálogos (MSG0/1/2)
- O jogo japonês tinha um único `ETC/ALLMSG.MSB`. O tradutor do inglês criou `MSG/MSG0.MSB`, `MSG1.MSB` e `MSG2.MSB` (no fim do disco) e uma tabela em `0x800677A0` (pares *entrada de carregamento da cena* → posição MSF no disco) que troca o arquivo de diálogo conforme a área. Todos são carregados em `0x801B6800` (limite de 40960 bytes, até o `CUD.MSB`).
  - `MSG0`: área de fora (`GROUND*.BIN`).
  - `MSG1`: `BF10`–`BF19`, `TRN00`–`02`, `TURO`, `LAB`.
  - `MSG2`: `BF01`–`BF09`, `BF21`, `BF22`.
- Os scripts das áreas guardam o deslocamento de cada fala (16 bits, às vezes em tabelas de meias-palavras). As referências foram achadas comparando com o japonês e exigindo que o valor japonês também fosse início de mensagem (do `ALLMSG` ou do `ITEM`). A ordem das mensagens é mantida (algumas falas são lidas em sequência, sem referência própria); o enchimento `MISSING` do fim sai.
- `ALLMSG.MSB` (mensagens 1–263) é usado pelo `MOVIE.BIN` (tabela em `0x800DE220`) e pela tabela do executável em `0x80068540`; traduzido reaproveitando as falas iguais dos MSG.
- `AB_MES.MSB` (tela de brilho) é carregado pelo `BRIGHT.BIN` em `0x80145AE0`; limite mantido no tamanho original (322 bytes) por segurança.
- Falta: `ITEM2.MSB` (enciclopédia de itens do título, ainda em japonês também na versão em inglês).
- Termos: Sense Sphere = Esfera Sensorial; Nerve Tower = Torre dos Nervos; Great Heat Wave = Grande Onda de Calor; pretend angels = falsos anjos; Littles = Pequeninos; imitation wings = asas de simulacro; Idea Sefirah = Ideia Sefirah; Malkuth Order = Ordem de Malkuth; Lord Archangel = Senhor Arcanjo; Outer World = Mundo Exterior; bordão do Homem Caixão ("goddammit") = "droga".

## Qualidade de vida (patch/main.asm e patch/overlays.asm)
- **Correr:** R2 liga/desliga (som de cursor e um ">>" laranja no canto superior direito). As velocidades de andar (frente 0x9000, trás 0x4000, lado 0x6000, escolhidas em `0x800275A0`) ficam 26/16 maiores (`RUN_MUL`).
- **Texto:** o diálogo escreve `TEXT_CHARS` letras por quadro (original: 1). O botão de confirmar escreve o resto de uma vez; apertando de novo, a janela passa (comportamento original). Rotina por quadro em `0x80016054`; a parte das letras (`0x800161B8`) foi trocada por `TypeHook`. Textos com a flag 0x20 (não puláveis) continuam iguais.
- **Câmera suave:** o analógico direito passa por um filtro (`SMOOTH_SHIFT`), dando aceleração/desaceleração no giro e no olhar para cima/baixo.
- **FOV:** o `GAME.BIN` define a distância de projeção do GTE (H) como 384 em `0x800E1288` (~53° na horizontal, bem fechado). O patch reaplica H todo quadro a partir de `FovTable` (384/320/288/256/224); **Select + Esquerda/Direita** troca, começa no 256 (~74°).
- **16:9:** o `GAME.BIN` descartava objetos fora de um cone de ~30° (cosseno 0xDDB/0xD91 em `0x800E2230`, `0x800E2988`, `0x800D0698`). Agora ~60° (`patch/overlays.asm`, roda depois do `textpack.py`). Use junto com "Widescreen Rendering" do DuckStation.
- **Modo analógico:** o jogo usa a libpad mas nunca troca o modo do controle, e sem modo analógico não há leitura dos analógicos. Use no DuckStation a opção do controle "Force Analog Mode on Reset" (Forçar modo analógico ao reiniciar).
- **Indicadores na tela:** o jogo desenha com deslocamento (0,0) e coordenadas absolutas; os dois buffers ficam um em cima do outro na VRAM (y = 0 e y = 256, DRAWENV em `0x80086994 + idx*0xCFF0 + 0x5C`). As listas dos indicadores começam com um comando GP0 E5 (deslocamento) preenchido a cada quadro com o y do buffer atual e terminam voltando para (0,0).
- **Giro de 180°:** L2, em 8 quadros (`QT_FRAMES`).
- **Configurações salvas:** velocidade da câmera, FOV e corrida ficam em 4 bytes livres do save do sistema (bloco em `0x8010B810`, bytes +0x21E..+0x221, com a marca 0xB7). O jogo recalcula a soma de verificação ao salvar (`0x8005E0DC`), então elas vão para o cartão quando o save do sistema é gravado.

### Enciclopédia de itens (tela título)
- O `ETC/ITEM2.MSB` ficou em japonês e **não é usado** pela versão inglesa. O tradutor pôs o texto inglês dentro do `ETC/FONT.BIN`, a partir de `0x5000` (carregado em `0x801CB800`, até `0x9688`; depois vem desenho da fonte), e trocou o `ori 0x1000` por `ori 0xB800` em `MOVIE.BIN` `0x800D5984`.
- Tabelas no `BIN01/MOVIE.BIN`: `0x127EC` = 244 palavras (16 bits altos = categoria, 16 baixos = posição do texto no bloco); `0x12BDC` = 12 meias-palavras (filmes, finais, extras). O "???" usa a posição `0x4C` (exe `0x80068728`, gp-0x7DB8), no cabeçalho de `0x6C` bytes que fica igual.
- Texto em `traducao/ENCICLOPEDIA.tsv` (chave `T0..T243` na ordem da tabela, `S0..S11` especiais; até 42 letras por linha e 4 linhas). `tools/enciclopedia.py` monta o bloco (limite 18056 bytes) e corrige as tabelas; roda depois do `textpack.py`.
- O rótulo japonês 投 ("THROW" no inglês) é o dano/efeito quando o item é **arremessado**: ficou `ARREM`.

### Minimapa estilo Diablo (patch/main.asm)
- Original: o botão de mapa (máscara em `0x800BF68E`) só mostrava o mapa enquanto ficava apertado, pausando o jogo (callback `0x80027500` em `0x800C6AAC`, modo `gp-0x7674` = 2), ampliado 1,5x no centro (função de coordenadas `0x80025118`).
- Agora: o botão de mapa continua como no original (mapa grande, jogo pausado). No laço normal do jogo (`0x80025CFC` → `MapDraw`; o laço das telas pausadas é outro, em `0x80025F54`) o mapa é desenhado sempre no canto com o modo 1 de `0x80025118` (sem uso no original; `0x80025140` → `MapXform`): 3/4 do tamanho, centro em `MAP_CX`/`MAP_CY` (quadro 96x96 no canto inferior direito), transparência `MAP_ABR` = 3 (fundo + 25%) aplicada nos tpage dos dois POLY_FT4 (`0x800BDB4E`/`0x800BDB76`).
- Andar: `0x800BF698` (byte alto 1 = torre, byte baixo = número; o jogo soma 1 ao descer, `0x80026D2C`). `FloorDraw` desenha o número em 7 segmentos (TILEs) acima do minimapa, só na torre e só no laço normal.
- Indicadores: a OT do jogo termina com um DR_ENV (buffer+0xC0) que põe a área de desenho fora da tela. Os buffers ficam lado a lado (x = 0 e x = 384). As listas dos indicadores começam com E3/E4/E5 do buffer atual e terminam repetindo o E3/E4/E5 do jogo.
- Mapa grande: `0x80025FDC` → `BigMapDraw` põe um TILE preto semitransparente (tela toda) na camada 6 da OT depois do mapa (na OT, o último adicionado numa camada é desenhado primeiro), escurecendo o cenário. O jogo já pausava (callback `0x80027500`), igual ao original.
- O DuckStation corta alguns pixels de overscan nas bordas: minimapa fica a ~16 px da borda (`MAP_CX`/`MAP_CY`); o andar fica pequeno no canto superior esquerdo (`FL_X`/`FL_Y`). O indicador ">>" da corrida foi removido (a corrida continua no R2).
- Savestates do DuckStation guardam a VRAM inteira: dá para ver os dois buffers (x = 0 e x = 384) e conferir o que foi desenhado.

### Ajustes de 18/11
- **Sempre montar pelo processo completo** (`2_aplicar_patch_e_montar.bat`): o `textpack.py` corrige as referências de texto dentro do `SLPM_863.41`. Recompilar só o `main.asm` e gravar deixa várias telas apontando para os textos em inglês (ex.: "lvar"/"do" na tela de salvar do Next Floor).
- Coisa do Caixão: o tique "goddammit" virou "droga" (antes "porra").
- Câmera: suavização desligada (`SMOOTH_SHIFT` 0, dava sensação de arrasto). Olhar para cima/baixo começa travado (câmera reta); R3 alterna (`PitchFree`, salvo em `SYS_CFG+4`).
