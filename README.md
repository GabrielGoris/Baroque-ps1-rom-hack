# Baroque PT-BR + Camera Hack (PS1)

Tradução para português do Brasil e pacote de melhorias de jogabilidade para
**Baroque: Yuganda Mousou** (PlayStation, SLPM-86341), feito sobre a tradução
inglesa de fãs v1.0.2.

Pensado para jogar em emulador (testado no DuckStation, no PC e no Android).

## O que tem

### Tradução
- Todo o texto do jogo em português: diálogos, itens e descrições, menus,
  telas de salvar e carregar, mensagens de combate e a enciclopédia de itens da
  tela título.
- Letras acentuadas (á, ã, ç, é, ô…) desenhadas na fonte do jogo.

### Câmera e controles
- **Analógico direito gira a câmera.** O analógico esquerdo anda e dá passos para os lados.
- **Olhar para cima e para baixo** fica travado por padrão (câmera reta).
  **R3** alterna entre travado e livre.
- **Sensibilidade da câmera:** Select + ↑/↓ (5 níveis).
- **Campo de visão (FOV):** Select + ←/→ (5 níveis).
- **Giro rápido de 180°:** L2.
- **Corrida:** R2 liga e desliga (cerca de 1,6× a velocidade normal).

### Interface e conforto
- **Texto mais rápido:** o botão de confirmar mostra a fala inteira de uma vez
  e, apertando de novo, avança.
- **Minimapa** semitransparente sempre visível no canto inferior direito.
  O botão de mapa continua abrindo o mapa grande, com o jogo pausado e o fundo
  escurecido.
- **Número do andar** discreto no canto superior esquerdo (0 fora da torre).
- **16:9 de verdade:** objetos não somem mais nas laterais com o widescreen
  do emulador.
- **Distância de desenho maior:** o cenário não "brota" na frente do jogador.
- As configurações (câmera, FOV, corrida, olhar livre) ficam salvas no save do
  sistema do cartão de memória.

## Como aplicar

Você precisa do seu próprio dump do jogo japonês: `Track 1` e `Track 2`
(áudio), mais o `.cue`.

1. Aplique a **tradução inglesa v1.0.2** ([Nerve Tower](https://nervetower.neocities.org/main.html))
   no `Baroque - Yuganda Mousou (Japan) (Track 1).bin`.
2. Aplique o `.xdelta` deste projeto (aba **Releases**) no Track 1 em inglês
   gerado no passo 1. Pode usar o Delta Patcher ou o xdelta UI.
3. Use o Track 1 resultante com o Track 2 japonês original e um `.cue`
   apontando para os dois.

O patch foi gerado a partir de um Track 1 em inglês com MD5
`2ab9c47dbf6aec9043a806e2d821ca0d`. Se o seu dump japonês for de outra fonte, o
Track 1 em inglês pode ficar ligeiramente diferente. Nesse caso, aplique com a
verificação de checksum desligada.

### Configuração recomendada no DuckStation
- Controle: **Force Analog Mode on Reset** (sem isso os analógicos não funcionam).
- Widescreen Rendering + proporção 16:9.
- PGXP e aceleração de leitura do CD são opcionais, mas ajudam bastante.

## Compilar a partir do código

Requisitos: Windows, Python 3, [armips](https://github.com/Kingcom/armips),
[xdelta3](https://github.com/jmacd/xdelta) e `dumpsxiso` do
[mkpsxiso](https://github.com/Lameguy64/mkpsxiso). Coloque-os em:

```
tools/armips/armips.exe
tools/xdelta/xdelta3-3.1.0-x86_64.exe
tools/mkpsxiso/mkpsxiso-2.30-win64/dumpsxiso.exe
```

Coloque na pasta `disc/` o Track 1 em inglês (`Baroque (English) (Track 1).bin`
e o `.cue`) e o Track 2 japonês. Depois:

| Script | O que faz |
|---|---|
| `0_aplicar_traducao.bat` | (opcional) gera o Track 1 em inglês a partir do dump japonês |
| `1_extrair_disco.bat` | extrai os arquivos do disco para `extracted/` e `original/` |
| `2_aplicar_patch_e_montar.bat` | monta tudo e grava em `build/` |
| `3_gerar_xdelta.bat` | gera o patch `.xdelta` |

Monte sempre pelo `2_aplicar_patch_e_montar.bat`, porque a ordem das etapas
importa.

### Estrutura
- `patch/main.asm`: melhorias no executável (armips).
- `patch/overlays.asm`: ajustes no `GAME.BIN` (corte de objetos para 16:9).
- `traducao/*.tsv`: textos (índice, inglês, português; `|` = quebra de linha,
  `{xx}` = código de controle ou ícone).
- `tools/textpack.py`: remonta os arquivos de texto e corrige as referências
  no código.
- `tools/enciclopedia.py`: enciclopédia de itens da tela título.
- `tools/fontaccents.py`: desenha as letras acentuadas na fonte.
- `tools/psxdisc.py`: grava os arquivos na imagem `.bin` recalculando EDC/ECC.
- `docs/NOTAS-TECNICAS.md`: anotações de engenharia reversa (endereços,
  formatos e como cada coisa foi feita).

## Créditos
- Tradução inglesa v1.0.2: hacking de [Plissken](https://twitter.com/Plissken___),
  tradução da [Nerve Tower](https://nervetower.neocities.org/main.html) e sprite
  da fonte de [blametherobots](https://twitter.com/blametherobots). Este projeto
  parte do trabalho deles, e a coluna em inglês dos `.tsv` é o texto dessa
  tradução.
- Baroque © Sting / Entertainment Software Publishing. Este é um projeto de fãs,
  sem fins lucrativos. Nenhum arquivo do jogo é distribuído aqui.

## Licença
O código e os scripts estão sob a licença MIT (veja `LICENSE`). Os textos
traduzidos são distribuídos apenas para uso não comercial.
