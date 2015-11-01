[org 0x7c00]
BITS 16

section .text
start:		mov bp,0x8000		; Marca stack indiretamente
					mov sp,bp				; "Cria" stack
					mov si,intromsg	; Coloca msg de intro no reg de entrada
					call putstr			; Imprime msg de intro
					call puthex			; Imprime DX em Hexadecimal (Numero do Driver)
					mov dh,1				; Carrega 1 setor...
					mov bx,0x9000		; ... para 0x0000(ES):0x9000(BX)
					call readdsk		; Ler disco
					call putn
					mov dx,[0x9000]	; Carrega primeiro byte lido para DX
					call puthex			; Imprime DX em Hexadecimal
					mov dx,[0x9002]
					call puthex
					jmp $

; Rotina para passar para a proxima linha na tela
putn:		push si 				; Salva o que esta em SI
				mov si,newline	; Carrega caracteres de nova linha em SI
				call putstr			; Imprime a nova linha
				pop si					; Restaura o que estava em SI antes
				ret

; Imprime string apontada pelo SI
putstr.1:	call putchr		; Imprime caracteres carregado em AL
putstr:		lodsb					; Carrega o proximo caracter em AL
					cmp al,0			; Ver se AL = 0 ...
					jne putstr.1	; ... senao, imprime caractere em AL
					ret

; Imprime caractere armazenado no reg AL
putchr:		push bx			; Salva o que esta em BX
					mov bx,0x7	; Cor Cinza
					mov ah,0xe	; BIOS: funcao para imprimir na tela
					int 0x10		; BIOS: Interrupcao 10
					pop bx			; Restaura o que estava em BX antes
					ret

; Imprime em Hexadecimal
puthex:		push ax
					push bx
					push cx
					mov cx,0x1
; primeiro byte
puthexb.1	mov ax,dx				; Copia valor a ser impresso para AX
					mov ah,al				;
puthex.p:	lea bx,[TABLE]	; Armazena em BX o endereco da TABLE
					shr ah,4				; AH contem os 4 primeiros bits (valor = 0-F)
					and al,0x0F			; AL contem os 4 últimos bits (valor = 0-F)
					xlat						; Copia o valor da TABLE no índice AL para AL
					xchg ah,al			; Inverte AH e AL
					xlat						; Copia o valor da TABLE no índice AL para AL
					lea bx,[STRING]
					;xchg ah,al
					mov [bx],ax
					mov si,STRING
					call putstr
					cmp cx,0x2
					je puthex.e
; segundo byte
puthexb.2	mov cx,0x2
					mov ax,dx
					mov al,ah				;
					jmp puthex.p
puthex.e	pop cx
					pop bx
					pop ax
					ret

; Carrega 1o setor do disco no reg DL para a posicao de memoria ES:BX
readdsk:	push ax
					push cx
					push dx
					mov ah,0x2	; BIOS: funcao para ler setor
					mov dh,0		; Head 0
					mov cl,0x1	; Sector 1
					mov ch,0		; Cylinder 0
					mov al,1		; Ler 1 setor
					push ax 		; Salvar qnt de setores que devia ler
					int 0x13		; Lê
					jc disk_error ; Erro?
					pop dx			; Restaura qnt de setores que devia ler
					cmp dl,al		; Verifica se leu todos os sertores
					jne disk_error	; Erro?
					pop dx
					pop cx
					pop ax
					ret

disk_error:	call putn
						mov si,DISK_ERROR_MSG
						call putstr
						ret

; Strings e Constantes
intromsg: 	db `\r\nIniciando boot persoinalizado.\r\nProjeto Integrador V - Sistemas Operacionais\r\nDanilo Carvalho\r\nCarlos Romeu\r\nNicolas Alexandre\r\nProf: Flavia`,0
newline:	db `\r\n`
BASE:		dw 0x7c00
DISK_ERROR_MSG: db "Disk read error!",0
TABLE: 		db "0123456789ABCDEF",0

section .bss
STRING:		resb 50

section .text
times 510-($-$$) db 0
dw 0xaa55
