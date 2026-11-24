;;  Patch de camera/controles do Baroque (PS1, versao em ingles)
;;  Rode 2_aplicar_patch_e_montar.bat para montar.
;;
;;  O que o jogo ja fazia (descoberto no codigo):
;;    - Com DualShock em modo analogico, o analogico ESQUERDO controla tudo
;;      no estilo "tanque": eixo X gira (0x800826F6 = LX), eixo Y anda (LY).
;;    - L1/R1 ja fazem strafe (andar de lado).
;;    - Personagem em 0x800C066C: rotacao X (pitch) em 0x800C0670,
;;      angulo (yaw) em 0x800C0672 (0..4095, girar p/ direita diminui).
;;    - Tela 384x240, dois buffers lado a lado; troca de quadro em 0x8001CC08.
;;
;;  O que este patch muda:
;;    1) Analogico DIREITO (X) gira a camera.
;;    2) Analogico ESQUERDO para os lados aperta L1/R1 = strafe.
;;    3) Analogico DIREITO (Y) olha para cima/baixo (+-45 graus; eixo normal,
;;       para cima = olhar para cima).
;;       R3 volta a camera para o centro.
;;    4) Select + Cima/Baixo (direcional) muda a velocidade da camera
;;       (5 niveis, comeca no 3 = velocidade original), com som de cursor
;;       e um indicador de 5 barras no canto superior direito.
;;    5) Distancia de desenho maior (o cenario nao "aparece" mais na frente).
;;    6) R2 liga/desliga a corrida (som de cursor + ">>" no canto da tela).
;;    7) Texto dos dialogos mais rapido; o botao de confirmar mostra o texto
;;       inteiro de uma vez (apertando de novo, passa para o proximo).
;;    8) Camera suave: o analogico direito tem aceleracao/desaceleracao.
;;    9) Campo de visao (FOV): Select + Esquerda/Direita (5 niveis; o jogo
;;       original usava H=384, bem fechado). Mostra o mesmo indicador.
;;   10) L2 = giro rapido de 180 graus (em 8 quadros).
;;   11) Velocidade da camera, FOV e corrida ficam guardados no save do
;;       sistema (bytes livres +0x21E..+0x221 do bloco em 0x8010B810).
;;    (O corte lateral para 16:9 fica em patch/overlays.asm, no GAME.BIN.)
;;
;;  Espaco para o codigo novo: 0x80051FF8..0x8005328F, uma funcao de
;;  biblioteca (4760 bytes) que o jogo nunca chama (sem jal, j, ponteiro
;;  ou desvio apontando para ela em nenhum arquivo do disco).

.psx
.open "build/SLPM_863.41", 0x80010000 - 0x800

FREE_START   equ 0x80051FF8
FREE_END     equ 0x80053290

PITCH_LIMIT  equ 0x200      ; 0x200 = 45 graus (4096 = volta inteira)
PITCH_DEAD   equ 0x20       ; zona morta do analogico direito (eixo Y)
SENS_DEFAULT equ 3
OV_FRAMES    equ 75         ; quanto tempo o indicador fica na tela (quadros)

RUN_MUL      equ 26         ; velocidade correndo = normal * 26/16 (~1,6x)
TEXT_CHARS   equ 2          ; letras por quadro no dialogo (original: 1)
SMOOTH_SHIFT equ 0          ; suavizacao da camera: 0 = desligada (dava sensacao de arrasto)
FOV_DEFAULT  equ 4          ; nivel inicial do FOV (1 = original)
QT_FRAMES    equ 8          ; giro de 180 graus em 8 quadros (8 * 0x100)
MAP_CX       equ 318        ; minimapa: centro do quadro de 96x96 (3/4 do
MAP_CY       equ 180        ;   original 1:1), canto inferior direito, longe da
                            ;   borda (o DuckStation corta ~8-16 px de overscan)
MAP_ABR      equ 3          ; transparencia: 0 = 50/50 (original), 3 = fundo + 25%
FLOOR_VAR    equ 0x800BF698 ; andar: byte alto 1 = torre, byte baixo = numero
FL_X         equ 18         ; numero do andar: canto superior esquerdo,
FL_Y         equ 14         ;   acima do emblema do nivel, pequeno e discreto
COL_FLOOR    equ 0x60B0B0B0 ; TILE opaco, branco acinzentado
SYS_CFG      equ 0x8010BA2E ; 4 bytes livres no save do sistema
CFG_MAGIC    equ 0xB7

; Funcoes do jogo / biblioteca
Mul12        equ 0x800171C4 ; (a0*a1)>>12
PlaySound    equ 0x80013188 ; a0 = id do som (0xAA09 = cursor do menu)
DrawOTag     equ 0x8005110C
TextPutChar  equ 0x800154E8 ; desenha a proxima letra do dialogo
TextUpload   equ 0x800162D4 ; manda o texto do dialogo para a VRAM

; Indicador (coordenadas na tela de 384x240)
OV_X         equ 312
OV_Y         equ 8
OV_W         equ 60
OV_H         equ 18
COL_BOX      equ 0x60080808 ; TILE opaco, quase preto
COL_ON       equ 0x6040B0F0 ; TILE, laranja claro (BGR)
COL_OFF      equ 0x60383838 ; TILE, cinza escuro

; ---------------------------------------------------------------------------
; Ganchos no codigo original

; Leitura do controle analogico (so roda com DualShock em modo analogico)
.org 0x8001AB2C
    lbu     v1, 0x26F4(at)          ; era 0x26F6 (LX); agora RX = analogico direito
.org 0x8001AB48
    j       StrafeHook              ; era "b 0x8001AB88" (fim da rotina)
    sh      v0, -0x7FBE(gp)         ; instrucao original do delay slot

; Giro: as duas chamadas de multiplicacao usam a velocidade maxima 0x45
.org 0x800278E4
    jal     TurnMul                 ; era "jal 0x800171C4"
.org 0x80027940
    jal     TurnMul                 ; era "jal 0x800171C4"

; Logo depois do giro, na funcao de controle do personagem (s1 = personagem)
.org 0x80027980
    j       PitchHook               ; era "lh v0,6(s1)"
    nop

; Velocidades de andar ja escolhidas (s7 frente, s6 tras, s5 lado)
.org 0x800275C8
    j       RunHook                 ; era "lui at,0x800C / lbu v0,-0x2438(at)"
    nop

; Dialogo: parte que escreve as letras (roda uma vez por quadro)
.org 0x800161B8
    j       TypeHook
    nop

; Minimapa estilo Diablo. O botao de mapa continua como no original (mapa
; grande no centro, jogo pausado enquanto apertado: modo 2 de 0x80025118,
; callback 0x80027500). Alem disso, no laco normal do jogo o mapa e desenhado
; sempre no canto inferior direito, menor e mais transparente (modo 1).
.org 0x80025CFC
    jal     MapDraw                 ; laco normal do jogo; era "jal 0x80026120"
.org 0x80025FDC
    jal     BigMapDraw              ; mapa grande (jogo pausado); era "jal 0x80025280"
.org 0x80025140                     ; modo 1 (sem uso no jogo) = minimapa
    addiu   at, zero, 1
    bne     v0, at, 0x80025278      ; outros modos: sem transformacao
    nop
    j       MapXform
    nop

; Troca de quadro: depois de desenhar a cena, desenha o indicador por cima
.org 0x8001CCF4
    jal     OverlayDraw             ; era "jal DrawOTag"

; Distancia de desenho. Antes de desenhar cada objeto do cenario, o jogo
; (GAME.BIN, 0x800E209C) descarta o que estiver alem de um limite definido
; por 0x800E1590(limite). No modo normal de exploracao (area de fora e
; andares) o limite era 0x240000, mas a neblina so fica completa em 0x280000
; (medido nos save states da area de fora), entao os objetos sumiam antes de
; a neblina esconde-los (o cenario "aparecendo" enquanto se anda). Os limites
; abaixo ficam depois do fim da neblina.
DRAW_FAR_NORMAL equ 0x2C0000 ; era 0x240000 (neblina termina em 0x280000)
DRAW_FAR_OTHER equ 0x300000 ; era 0x280000 (outros modos; neblina ate 0x2D0000)

.org 0x80025C50
    lui     a0, DRAW_FAR_OTHER >> 16
.org 0x80025C64
    lui     a0, DRAW_FAR_NORMAL >> 16
.org 0x800265EC
    lui     a0, DRAW_FAR_OTHER >> 16

; ---------------------------------------------------------------------------
.org FREE_START

; Dados ----------------------------------------------------------------------
SensLevel:  .byte SENS_DEFAULT      ; nivel atual (1..5)
TurnSpeed:  .byte 0x45              ; velocidade maxima de giro do nivel atual
PitchMul:   .byte SENS_DEFAULT+1    ; multiplicador do pitch (/16)
            .byte 0
OvTimer:    .halfword 0             ; quadros restantes do indicador
            .halfword 0
TurnTable:  .byte 0x20, 0x30, 0x45, 0x60, 0x80
RunOn:      .byte 0                 ; 1 = correndo
            .byte 0, 0
SmoothRX:   .halfword 0x8000        ; analogico direito filtrado (x256)
SmoothRY:   .halfword 0x8000
SaveA0:     .word 0
SaveRA:     .word 0
FovLevel:   .byte FOV_DEFAULT       ; 1..5
OvMode:     .byte 0                 ; indicador mostra: 0 = camera, 1 = FOV
QTurn:      .byte 0                 ; quadros restantes do giro de 180
FloorFlag:  .byte 0                 ; 1 = laco normal rodou neste quadro
PitchFree:  .byte 0                 ; 0 = olhar para cima/baixo travado (R3 alterna)
.align 2
; Distancia da tela de projecao (H do GTE). Menor = campo de visao maior.
; 384 = original (~53 graus na horizontal); 256 = ~74 graus.
FovTable:   .halfword 384, 320, 288, 256, 224
.align 4

; Indicador de corrida ">>": dois triangulos (POLY_F3), com o mesmo esquema
RUN_X        equ 352
RUN_Y        equ 30
COL_RUN      equ 0x2040B0F0         ; POLY_F3 opaco, laranja claro
RunList:
    .word (3 << 24) | ((RunList + 16) & 0xFFFFFF)
    .word 0xE3000000, 0xE4000000, 0xE5000000 ; area/deslocamento (no quadro)
    .word (4 << 24) | ((RunList + 36) & 0xFFFFFF)
    .word COL_RUN
    .word (RUN_Y << 16) | RUN_X
    .word ((RUN_Y + 10) << 16) | RUN_X
    .word ((RUN_Y + 5) << 16) | (RUN_X + 7)
    .word (4 << 24) | ((RunList + 56) & 0xFFFFFF)
    .word COL_RUN
    .word (RUN_Y << 16) | (RUN_X + 9)
    .word ((RUN_Y + 10) << 16) | (RUN_X + 9)
    .word ((RUN_Y + 5) << 16) | (RUN_X + 16)
RunEnd:
    .word (3 << 24) | 0xFFFFFF
    .word 0xE3000000, 0xE4000000, 0xE5000000 ; volta ao estado do jogo

; Listas de primitivas dos indicadores. Os dois buffers ficam lado a lado na
; VRAM (x = 0 e x = 384) e a OT do jogo termina com um DR_ENV que deixa a
; area de desenho fora da tela. Por isso cada lista comeca com E3/E4/E5 (area
; e deslocamento do buffer atual, preenchidos a cada quadro) e termina
; repetindo o estado final do jogo.
; TILE = 4 palavras: tag (tamanho 3 + proximo), cor/codigo, y<<16|x, h<<16|w
.macro Tile, next, col, x, y, w, h
    .word (3 << 24) | ((next) & 0xFFFFFF)
    .word col
    .word ((y) << 16) | (x)
    .word ((h) << 16) | (w)
.endmacro

OvList:
    .word (3 << 24) | ((OvList + 16) & 0xFFFFFF)
    .word 0xE3000000, 0xE4000000, 0xE5000000 ; area/deslocamento (no quadro)
OvTiles:
    Tile OvList+16+16*1, COL_BOX, OV_X, OV_Y, OV_W, OV_H
    Tile OvList+16+16*2, COL_OFF, OV_X+4,  OV_Y+16-6,  8, 6
    Tile OvList+16+16*3, COL_OFF, OV_X+15, OV_Y+16-8,  8, 8
    Tile OvList+16+16*4, COL_OFF, OV_X+26, OV_Y+16-10, 8, 10
    Tile OvList+16+16*5, COL_OFF, OV_X+37, OV_Y+16-12, 8, 12
    Tile OvList+16+16*6, COL_OFF, OV_X+48, OV_Y+16-14, 8, 14
OvEnd:
    .word (3 << 24) | 0xFFFFFF
    .word 0xE3000000, 0xE4000000, 0xE5000000 ; volta ao estado do jogo

; Analogico esquerdo para os lados -> L1/R1 (strafe) -------------------------
StrafeHook:
    lui     at, 0x8008
    lbu     t0, 0x26F6(at)          ; LX (0x00..0xFF, centro ~0x80)
    lhu     t1, -0x7FC2(gp)         ; botoes crus (bit 0 = apertado)
    sltiu   t2, t0, 0x50
    beqz    t2, @@NotLeft
    sltiu   t3, t0, 0xB1            ; (delay slot)
    andi    t1, t1, 0xFFFB          ; esquerda -> aperta L1
@@NotLeft:
    bnez    t3, @@Done
    nop
    andi    t1, t1, 0xFFF7          ; direita -> aperta R1
@@Done:
    sh      t1, -0x7FC2(gp)
    ; camera suave: filtra o analogico direito (X) que o giro vai ler
    lbu     t0, 0x26F4(at)          ; RX cru
    lui     t3, hi(SmoothRX)
    lhu     t4, lo(SmoothRX)(t3)
    sll     t0, t0, 8
    subu    t0, t0, t4
    sra     t0, t0, SMOOTH_SHIFT
    addu    t4, t4, t0
    sh      t4, lo(SmoothRX)(t3)
    srl     t4, t4, 8
    jr      ra
    sb      t4, -0x7FBD(gp)         ; byte alto do analogico = RX filtrado

; Multiplicacao do giro com a velocidade do nivel atual ----------------------
TurnMul:
    lui     t3, hi(TurnSpeed)
    lbu     a0, lo(TurnSpeed)(t3)
    j       Mul12
    nop

; Select + Cima/Baixo: velocidade da camera; Select + Esq/Dir: FOV ----------
HotkeyApply:
    lui     at, 0x800C
    lhu     t0, -0x2448(at)         ; botoes segurados
    lhu     t1, -0x2446(at)         ; botoes recem-apertados
    lui     t3, hi(SensLevel)
    andi    t0, t0, 0x0100          ; Select
    beqz    t0, @@Ret
    andi    t0, t1, 0x2000          ; (delay slot) Direita
    sltu    t0, zero, t0
    andi    t2, t1, 0x8000          ; Esquerda
    sltu    t2, zero, t2
    subu    t0, t0, t2              ; +1, -1 ou 0
    beqz    t0, @@Sens
    lbu     t2, lo(FovLevel)(t3)    ; (delay slot)
    addiu   t1, zero, OV_FRAMES
    sh      t1, lo(OvTimer)(t3)
    addiu   t1, zero, 1
    sb      t1, lo(OvMode)(t3)      ; indicador mostra o FOV
    addu    t4, t2, t0
    addiu   t0, t4, -1
    sltiu   t0, t0, 5
    beqz    t0, @@Ret
    nop
    b       @@Sound
    sb      t4, lo(FovLevel)(t3)    ; (delay slot)
@@Sens:
    andi    t0, t1, 0x1000          ; Cima
    sltu    t0, zero, t0
    andi    t1, t1, 0x4000          ; Baixo
    sltu    t1, zero, t1
    subu    t0, t0, t1              ; +1, -1 ou 0
    beqz    t0, @@Ret
    lbu     t2, lo(SensLevel)(t3)   ; (delay slot)
    addiu   t1, zero, OV_FRAMES
    sh      t1, lo(OvTimer)(t3)     ; mostra o indicador (mesmo no limite)
    sb      zero, lo(OvMode)(t3)    ; indicador mostra a camera
    addu    t4, t2, t0              ; novo nivel
    addiu   t0, t4, -1
    sltiu   t0, t0, 5               ; 1..5?
    beqz    t0, @@Ret
    addu    t5, t3, t4              ; (delay slot)
    lbu     t6, lo(TurnTable)-1(t5)
    sb      t4, lo(SensLevel)(t3)
    addiu   t7, t4, 1
    sb      t6, lo(TurnSpeed)(t3)
    sb      t7, lo(PitchMul)(t3)
@@Sound:
    ori     a0, zero, 0xAA09        ; som de cursor do menu
    move    a1, zero
    j       PlaySound               ; toca o som e volta direto para o PitchHook
    move    a2, zero
@@Ret:
    jr      ra
    nop

; Pitch (olhar para cima/baixo) no analogico direito -------------------------
PitchHook:
    jal     CfgLoad                 ; configuracoes do save do sistema
    nop
    jal     HotkeyApply
    nop
    jal     CfgStore                ; grava o que mudou
    nop
    ; L2: giro rapido de 180 graus
    lui     at, 0x800C
    lhu     t0, -0x2446(at)         ; recem-apertados
    lui     t3, hi(QTurn)
    andi    t0, t0, 0x0001          ; L2
    lbu     t1, lo(QTurn)(t3)
    beqz    t0, @@NoQT
    nop
    bnez    t1, @@NoQT              ; ja girando
    nop
    li      t1, QT_FRAMES
@@NoQT:
    beqz    t1, @@QTDone
    nop
    addiu   t1, t1, -1
    lhu     t2, 6(s1)               ; yaw
    nop
    addiu   t2, t2, 0x100
    andi    t2, t2, 0x0FFF
    sh      t2, 6(s1)
@@QTDone:
    sb      t1, lo(QTurn)(t3)
    lui     t3, hi(FovLevel)        ; aplica o FOV (H do GTE) todo quadro
    lbu     t0, lo(FovLevel)(t3)
    nop
    sll     t0, t0, 1
    addu    t0, t0, t3
    lhu     t0, lo(FovTable)-2(t0)
    nop
    ctc2    t0, $26
    ; R3 trava/destrava olhar para cima e para baixo (travado = camera reta)
    lui     at, 0x800C
    lhu     t0, -0x2446(at)         ; recem-apertados
    lui     t3, hi(PitchFree)
    andi    t0, t0, 0x0400          ; R3
    lbu     t1, lo(PitchFree)(t3)
    beqz    t0, @@NoToggle
    nop
    xori    t1, t1, 1
    sb      t1, lo(PitchFree)(t3)   ; (o CfgStore do proximo quadro salva)
@@NoToggle:
    bnez    t1, @@Free
    nop
    b       @@Store
    move    t1, zero                ; (delay slot) travado: pitch = 0
@@Free:
    lui     at, 0x8008
    lbu     t0, 0x26F5(at)          ; RY do analogico direito
    lui     t3, hi(SmoothRY)
    lhu     t4, lo(SmoothRY)(t3)    ; filtra (camera suave)
    sll     t0, t0, 8
    subu    t0, t0, t4
    sra     t0, t0, SMOOTH_SHIFT
    addu    t4, t4, t0
    sh      t4, lo(SmoothRY)(t3)
    srl     t0, t4, 8
    lbu     t4, lo(PitchMul)(t3)
    addiu   t0, t0, -0x80           ; centraliza: -128..127
    subu    t0, zero, t0            ; inverte: analogico para cima = olhar para cima
    lh      t1, 4(s1)               ; pitch atual
    lhu     t5, -0x7FC2(gp)         ; botoes crus (bit 0 = apertado)
    slti    t2, t0, -PITCH_DEAD
    bnez    t2, @@Apply
    slti    t2, t0, PITCH_DEAD+1    ; (delay slot)
    bnez    t2, @@Recenter          ; zona morta: nao mexe
    nop
@@Apply:
    mult    t0, t4
    mflo    t0
    sra     t0, t0, 4
    addu    t1, t1, t0
    slti    t2, t1, -PITCH_LIMIT
    beqz    t2, @@NotLow
    slti    t2, t1, PITCH_LIMIT+1   ; (delay slot)
    b       @@Recenter
    addiu   t1, zero, -PITCH_LIMIT  ; (delay slot)
@@NotLow:
    bnez    t2, @@Recenter
    nop
    addiu   t1, zero, PITCH_LIMIT
@@Recenter:
@@Store:
    sh      t1, 4(s1)
    lh      v0, 6(s1)               ; instrucao original
    j       0x80027988
    nop

; Desenha a cena (DrawOTag original) e, se for o caso, os indicadores -------
OverlayDraw:
    addiu   sp, sp, -0x18
    sw      ra, 0x10(sp)
    jal     DrawOTag                ; a0 = OT do jogo (vem do delay slot original)
    nop
    ; deslocamento do buffer atual: area de desenho (x,y) do DRAWENV
    lhu     t2, -0x76A2(gp)         ; buffer de tela atual (0/1)
    ori     t3, zero, 0xCFF0
    multu   t2, t3
    mflo    t2
    li      t3, 0x80086994 + 0x5C   ; DRAWENV do buffer 0
    addu    t2, t2, t3
    ; A OT do jogo termina com um DR_ENV (buffer+0xC0) que deixa a area de
    ; desenho fora da tela; sem refazer E3/E4/E5 tudo era cortado.
    lhu     t4, 0(t2)               ; x da area de desenho
    lhu     t5, 2(t2)               ; y
    lhu     t6, 4(t2)               ; largura
    lhu     t7, 6(t2)               ; altura
    addu    t6, t6, t4
    addiu   t6, t6, -1              ; x final
    addu    t7, t7, t5
    addiu   t7, t7, -1              ; y final
    la      t0, OvList
    la      t1, RunList
    lui     t8, 0xE300              ; E3: canto superior esquerdo
    or      t8, t8, t4
    sll     t9, t5, 10
    or      t8, t8, t9
    sw      t8, 4(t0)
    sw      t8, 4(t1)
    lui     t8, 0xE400              ; E4: canto inferior direito
    or      t8, t8, t6
    sll     t9, t7, 10
    or      t8, t8, t9
    sw      t8, 8(t0)
    sw      t8, 8(t1)
    lui     t8, 0xE500              ; E5: deslocamento = canto da area
    or      t8, t8, t4
    sll     t9, t5, 11
    or      t8, t8, t9
    sw      t8, 12(t0)
    sw      t8, 12(t1)
    lw      t4, 0xC4-0x5C(t2)       ; estado final do jogo (E3, E4, E5)
    lw      t5, 0xC8-0x5C(t2)
    lw      t6, 0xCC-0x5C(t2)
    la      t0, OvEnd
    la      t1, RunEnd
    sw      t4, 4(t0)
    sw      t5, 8(t0)
    sw      t6, 12(t0)
    sw      t4, 4(t1)
    sw      t5, 8(t1)
    sw      t6, 12(t1)

    lui     t0, hi(OvTimer)
    lhu     t1, lo(OvTimer)(t0)
    nop
    beqz    t1, @@Run
    addiu   t1, t1, -1              ; (delay slot)
    sh      t1, lo(OvTimer)(t0)
    lbu     t3, lo(OvMode)(t0)
    nop
    beqz    t3, @@ModeSens
    lbu     t3, lo(SensLevel)(t0)   ; (delay slot) nivel 1..5
    lbu     t3, lo(FovLevel)(t0)
@@ModeSens:
    li      t4, COL_ON
    li      t5, COL_OFF
    la      t6, OvTiles+16+4        ; cor da primeira barra
    li      t7, 1                   ; numero da barra
@@Bar:
    slt     t8, t3, t7              ; barra > nivel?
    bnez    t8, @@Off
    sw      t5, 0(t6)               ; (delay slot) apagada
    sw      t4, 0(t6)               ; acesa
@@Off:
    addiu   t7, t7, 1
    slti    t8, t7, 6
    bnez    t8, @@Bar
    addiu   t6, t6, 16              ; (delay slot)
    la      a0, OvList
    jal     DrawOTag                ; entra na fila depois da cena
    nop
@@Run:                              ; (indicador ">>" da corrida removido)
@@Ret:
    jal     FloorDraw
    nop
    lw      ra, 0x10(sp)
    nop
    jr      ra
    addiu   sp, sp, 0x18

; Configuracoes no save do sistema -------------------------------------------
; CfgLoad: se o bloco tem a marca, copia (validando) para as variaveis;
; senao grava as atuais. CfgStore: grava as variaveis no bloco.
CfgLoad:
    lui     t8, hi(SYS_CFG)
    lbu     t0, lo(SYS_CFG)(t8)
    li      t1, CFG_MAGIC
    bne     t0, t1, CfgStore
    lui     t3, hi(SensLevel)       ; (delay slot)
    lbu     t0, lo(SYS_CFG)+1(t8)   ; velocidade da camera
    nop
    addiu   t1, t0, -1
    sltiu   t1, t1, 5
    beqz    t1, @@Fov
    addu    t5, t3, t0              ; (delay slot)
    lbu     t6, lo(TurnTable)-1(t5)
    sb      t0, lo(SensLevel)(t3)
    addiu   t7, t0, 1
    sb      t6, lo(TurnSpeed)(t3)
    sb      t7, lo(PitchMul)(t3)
@@Fov:
    lbu     t0, lo(SYS_CFG)+2(t8)
    nop
    addiu   t1, t0, -1
    sltiu   t1, t1, 5
    beqz    t1, @@RunCfg
    nop
    sb      t0, lo(FovLevel)(t3)
@@RunCfg:
    lbu     t0, lo(SYS_CFG)+3(t8)
    nop
    sltiu   t1, t0, 2
    beqz    t1, @@PitchCfg
    nop
    sb      t0, lo(RunOn)(t3)
@@PitchCfg:
    lbu     t0, lo(SYS_CFG)+4(t8)
    nop
    sltiu   t1, t0, 2
    beqz    t1, @@Done
    nop
    sb      t0, lo(PitchFree)(t3)
@@Done:
    jr      ra
    nop

CfgStore:
    lui     t3, hi(SensLevel)
    lui     t8, hi(SYS_CFG)
    li      t0, CFG_MAGIC
    sb      t0, lo(SYS_CFG)(t8)
    lbu     t0, lo(SensLevel)(t3)
    nop
    sb      t0, lo(SYS_CFG)+1(t8)
    lbu     t0, lo(FovLevel)(t3)
    nop
    sb      t0, lo(SYS_CFG)+2(t8)
    lbu     t0, lo(RunOn)(t3)
    nop
    sb      t0, lo(SYS_CFG)+3(t8)
    lbu     t0, lo(PitchFree)(t3)
    jr      ra
    sb      t0, lo(SYS_CFG)+4(t8)

; Corrida: R2 liga/desliga; correndo, multiplica as velocidades ---------------
; (no meio da funcao de movimento: a0 = flags do personagem, s5/s6/s7 vivos)
RunHook:
    lui     at, 0x800C
    lhu     t0, -0x2446(at)         ; botoes recem-apertados
    lui     t3, hi(RunOn)
    andi    t0, t0, 0x0002          ; R2
    beqz    t0, @@Scale
    lbu     t1, lo(RunOn)(t3)       ; (delay slot)
    nop
    xori    t1, t1, 1
    sb      t1, lo(RunOn)(t3)
    sw      a0, lo(SaveA0)(t3)      ; (sem som; preserva a0 e ra)
    sw      ra, lo(SaveRA)(t3)
    jal     CfgStore                ; guarda no save do sistema
    nop
    lui     t3, hi(RunOn)
    lw      a0, lo(SaveA0)(t3)
    lw      ra, lo(SaveRA)(t3)
    lbu     t1, lo(RunOn)(t3)
    nop
@@Scale:
    nop                             ; espera o lbu de RunOn (atraso de load)
    beqz    t1, @@Done
    li      t2, RUN_MUL             ; (delay slot)
    mult    s7, t2
    mflo    s7
    sra     s7, s7, 4
    mult    s6, t2
    mflo    s6
    sra     s6, s6, 4
    mult    s5, t2
    mflo    s5
    sra     s5, s5, 4
@@Done:
    lui     at, 0x800C              ; instrucoes originais
    lbu     v0, -0x2438(at)
    j       0x800275D0
    nop

; Laco normal do jogo (0x80025CFC): monta o minimapa na OT antes de
; 0x80026120. (O laco das telas pausadas, em 0x80025F54, e outro.)
MapDraw:
    addiu   sp, sp, -0x18
    sw      ra, 0x10(sp)
    lhu     t0, -0x7674(gp)         ; botao de mapa ja pediu o mapa grande?
    nop
    bnez    t0, @@Done              ; entao nao mexe no modo
    li      t0, 1                   ; (delay slot)
    sh      t0, -0x7674(gp)         ; modo 1 = minimapa (ver MapXform)
    jal     0x80025280              ; monta o mapa na OT do quadro
    nop
    sh      zero, -0x7674(gp)
    lui     at, 0x800C              ; transparencia das duas metades do mapa
    lhu     t0, -0x24B2(at)         ; (tpage dos POLY_FT4 em 0x800BDB38/60)
    lhu     t1, -0x248A(at)
    ori     t0, t0, MAP_ABR << 5
    ori     t1, t1, MAP_ABR << 5
    sh      t0, -0x24B2(at)
    sh      t1, -0x248A(at)
    lui     t0, hi(FloorFlag)
    li      t1, 1
    sb      t1, lo(FloorFlag)(t0)   ; mostra o andar neste quadro
@@Done:
    lw      ra, 0x10(sp)
    addiu   sp, sp, 0x18
    j       0x80026120              ; chamada original
    nop

; Mapa grande (botao de mapa): depois de montar o mapa, poe na mesma camada
; da OT um TILE preto semitransparente da tela toda. Na OT, o que entra por
; ultimo numa camada e desenhado primeiro, entao ele escurece o cenario e o
; mapa fica por cima. Um pacote por buffer (a OT anterior pode estar sendo
; desenhada).
.align 4
DarkTile:
    .word (4 << 24) | 0xFFFFFF, 0xE100060A, 0x62000000, 0, (240 << 16) | 384
    .word (4 << 24) | 0xFFFFFF, 0xE100060A, 0x62000000, 0, (240 << 16) | 384
BigMapDraw:
    addiu   sp, sp, -0x18
    sw      ra, 0x10(sp)
    jal     0x80025280
    nop
    lhu     t0, -0x76A2(gp)         ; buffer atual (0/1)
    la      a0, DarkTile
    sll     t0, t0, 4
    sll     t1, t0, 2               ; idx * 20 = idx*16 + idx*4
    srl     t1, t1, 4
    addu    a0, a0, t0
    addu    a0, a0, t1
    jal     0x8001CFD4              ; AddPrim na camada 6 da OT atual
    li      a1, 6
    lw      ra, 0x10(sp)
    nop
    jr      ra
    addiu   sp, sp, 0x18

; Modo 1 de 0x80025118 (a0 = &x, a1 = &y): 3/4 do tamanho, no canto.
MapXform:
    lh      v0, 0(a0)
    lh      v1, 0(a1)
    addiu   v0, v0, -0xC0           ; centro original do mapa (192,120)
    addiu   v1, v1, -0x78
    sll     t0, v0, 1
    addu    v0, v0, t0
    sra     v0, v0, 2               ; x * 3/4
    sll     t0, v1, 1
    addu    v1, v1, t0
    sra     v1, v1, 2               ; y * 3/4
    addiu   v0, v0, MAP_CX
    addiu   v1, v1, MAP_CY
    sh      v0, 0(a0)
    jr      ra
    sh      v1, 0(a1)

; Numero do andar (0 fora da torre) em digitos de 7 segmentos (5x7) feitos de
; TILEs, no canto superior esquerdo. Chamado no fim do OverlayDraw.
SEG_A equ 0x01
SEG_B equ 0x02
SEG_C equ 0x04
SEG_D equ 0x08
SEG_E equ 0x10
SEG_F equ 0x20
SEG_G equ 0x40
SegMask:
    .byte 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F
SegRect:                            ; x, y, largura, altura (digito 5x7)
    .byte 0, 0, 5, 1                ; a
    .byte 4, 0, 1, 4                ; b
    .byte 4, 3, 1, 4                ; c
    .byte 0, 6, 5, 1                ; d
    .byte 0, 3, 1, 4                ; e
    .byte 0, 0, 1, 4                ; f
    .byte 0, 3, 5, 1                ; g
FloorDig:
    .byte 0, 0, 0, 0
.align 4
FloorList:
    .word (3 << 24) | 0xFFFFFF      ; proximo: preenchido no quadro
    .word 0xE3000000, 0xE4000000, 0xE5000000
FloorEnd:
    .word (3 << 24) | 0xFFFFFF
    .word 0xE3000000, 0xE4000000, 0xE5000000
FloorPrims:
    .fill 3 * 7 * 16

FloorDraw:
    lui     t0, hi(FloorFlag)
    lbu     t1, lo(FloorFlag)(t0)
    nop
    beqz    t1, @@Ret
    sb      zero, lo(FloorFlag)(t0) ; (delay slot)
    lui     at, hi(FLOOR_VAR)
    lhu     t1, lo(FLOOR_VAR)(at)
    nop
    andi    t2, t1, 0xFF00
    li      t3, 0x100
    beq     t2, t3, @@Tower
    andi    t1, t1, 0xFF            ; (delay slot)
    move    t1, zero                ; fora da torre: mostra 0
@@Tower:
    li      t6, 10                  ; separa os digitos (unidades primeiro)
    li      t3, 0
    la      t4, FloorDig
@@Div:
    divu    t1, t6
    mfhi    t5
    mflo    t1
    sb      t5, 0(t4)
    addiu   t4, t4, 1
    addiu   t3, t3, 1
    bnez    t1, @@Div
    nop
    la      t8, OvList              ; area/deslocamento do quadro atual
    la      t5, FloorList
    lw      t0, 4(t8)
    lw      t1, 8(t8)
    lw      t2, 12(t8)
    sw      t0, 4(t5)
    sw      t1, 8(t5)
    sw      t2, 12(t5)
    la      t8, OvEnd
    la      t5, FloorEnd
    lw      t0, 4(t8)
    lw      t1, 8(t8)
    lw      t2, 12(t8)
    sw      t0, 4(t5)
    sw      t1, 8(t5)
    sw      t2, 12(t5)
    la      t8, FloorList           ; ultimo pacote escrito
    la      t9, FloorPrims          ; proximo pacote livre
    la      t4, FloorDig
    sll     v0, t3, 1               ; x das unidades = FL_X + (digitos-1)*6
    addu    v0, v0, t3
    sll     v0, v0, 1
    addiu   t7, v0, FL_X - 6        ; (desenha da direita para a esquerda)
@@Digit:
    lbu     t5, 0(t4)
    la      a0, SegMask
    addu    a0, a0, t5
    lbu     a1, 0(a0)
    la      a2, SegRect
    li      a3, 0
@@Seg:
    andi    v0, a1, 1
    beqz    v0, @@NoSeg
    nop
    li      v1, COL_FLOOR
    sw      v1, 4(t9)
    lbu     v0, 0(a2)
    lbu     v1, 1(a2)
    addu    v0, v0, t7
    addiu   v1, v1, FL_Y
    sll     v1, v1, 16
    or      v0, v0, v1
    sw      v0, 8(t9)
    lbu     v0, 2(a2)
    lbu     v1, 3(a2)
    nop
    sll     v1, v1, 16
    or      v0, v0, v1
    sw      v0, 12(t9)
    lw      v1, 0(t8)               ; liga o pacote anterior a este
    lui     v0, 0xFF00
    and     v1, v1, v0
    sll     v0, t9, 8
    srl     v0, v0, 8
    or      v1, v1, v0
    sw      v1, 0(t8)
    lui     v0, 0x0300
    sw      v0, 0(t9)
    move    t8, t9
    addiu   t9, t9, 16
@@NoSeg:
    srl     a1, a1, 1
    addiu   a3, a3, 1
    slti    v0, a3, 7
    bnez    v0, @@Seg
    addiu   a2, a2, 4               ; (delay slot)
    addiu   t3, t3, -1
    addiu   t4, t4, 1
    bnez    t3, @@Digit
    addiu   t7, t7, -6              ; (delay slot)
    la      t9, FloorEnd            ; ultimo segmento -> fim
    lw      v1, 0(t8)
    lui     v0, 0xFF00
    and     v1, v1, v0
    sll     v0, t9, 8
    srl     v0, v0, 8
    or      v1, v1, v0
    sw      v1, 0(t8)
    la      a0, FloorList
    j       DrawOTag                ; volta direto para quem chamou
    nop
@@Ret:
    jr      ra
    nop

; Dialogo: escreve TEXT_CHARS letras por quadro; o botao de confirmar
; escreve tudo de uma vez. (substitui 0x800161B8..0x80016264; a0 = flags)
TypeHook:
    lui     at, 0x800C
    lhu     v1, -0x2446(at)         ; recem-apertados
    lhu     v0, -0x0978(at)         ; mascara do botao de confirmar
    andi    t0, a0, 0x20            ; 0x20 = texto que nao pode ser pulado
    and     v0, v1, v0
    beqz    v0, @@Timer
    nop
    bnez    t0, @@Timer
    nop
    b       @@Loop
    li      s0, 2000                ; tudo de uma vez (limite de seguranca)
@@Timer:
    lhu     v0, -0x76EE(gp)         ; contador de espera entre letras
    nop
    beqz    v0, @@Reload
    addiu   v0, v0, -1              ; (delay slot)
    sh      v0, -0x76EE(gp)
    bnez    v0, @@Exit
    nop
@@Reload:
    lhu     v0, -0x76EC(gp)
    nop
    sh      v0, -0x76EE(gp)
    li      s0, TEXT_CHARS
@@Loop:
    lhu     v1, -0x76FA(gp)
    nop
    andi    v0, v1, 6
    beqz    v0, @@Upload
    nop
    jal     TextPutChar
    andi    a0, v1, 8               ; (delay slot)
    lw      v0, -0x76F8(gp)
    nop
    lbu     v0, 0(v0)
    li      t1, 0xFF
    bne     v0, t1, @@Next
    nop
    b       @@Upload
    sw      zero, -0x76F8(gp)       ; (delay slot) fim do texto
@@Next:
    addiu   s0, s0, -1
    bgtz    s0, @@Loop
    nop
@@Upload:
    jal     TextUpload
    nop
@@Exit:
    j       0x80016268              ; epilogo original (restaura ra e s0)
    nop

.if . > FREE_END
    .error "Codigo novo passou do espaco livre"
.endif

.close
