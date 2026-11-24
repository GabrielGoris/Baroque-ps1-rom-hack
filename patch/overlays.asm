;;  Patches nos overlays (rodam DEPOIS do textpack.py, sobre patch/files).
;;
;;  16:9 de verdade: antes de desenhar cada objeto, o GAME.BIN compara o
;;  cosseno do angulo entre o objeto e a direcao da camera com um limite e
;;  descarta o que estiver fora de um cone de ~30 graus para cada lado.
;;  O limite novo (~60 graus) cobre o 16:9, o FOV maior e o olhar para
;;  cima/baixo do patch de camera.
;;  Com o widescreen do DuckStation a tela fica mais larga e os objetos das
;;  bordas sumiam.

.psx

WIDE_CULL equ 0x0800        ; cos(60 graus) * 4096 (originais: 0xDDB e 0xD91)

.open "patch/files/BIN01/GAME.BIN", 0x800CC200
.org 0x800E2230
    slti    at, a1, WIDE_CULL       ; era 0xDDB (objetos do cenario)
.org 0x800E2988
    slti    at, a1, WIDE_CULL       ; era 0xD91
.org 0x800D0698
    slti    at, v0, WIDE_CULL       ; era 0xD91
.close
