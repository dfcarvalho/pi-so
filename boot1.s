[org 0x7c00]
BITS 16

section .text
start:
	jmp main

times 3-($-$$) db 0
oemid: times 0x8 db 0

times 11-($-$$) db 0
bpb:
	dw 0x200
	db 0
	dw 0
	db 0
	dw 0
	dw 0
	db 0
	dw 0
	dw 0x12
	dw 0x2
	dd 0
	dd 0

times 36-($-$$) db 0
ebpb:
	db 0

times 37-($-$$) db 0x90

; Lê MBR
; Também usado pelo boot2 - por isso está no inicio
; Argumentos:
;	CX:AX 	- posição LBA para ler
;	ES:BX 	- buffer onde escrever o dado lido
; 	DL 		- Drive/Partição para ler
;	DH 		- Número de setores para ler
xread:
	; call putn	; debug - para ver se está sendo chamada
	; mov si,READ	; debug
	; call putstr ; debug
	; call putn	; debug
	push ss
	pop ds
.1:
	push dword 0x0
	push cx
	push ax
	push es
	push bx
	xor ax,ax
	mov al,dh
	push ax
	push 0x10
	mov bp,sp
	call read
	lea sp,[bp+0x10]
	retf

main:
	cld
	xor cx,cx		; Zera registrador CX
	mov es,cx		; Zera endereço base do Segmento Extra (ES)
	mov ds,cx		; Zera endereço base do Segmento de Dados (DS)
	mov ss,cx		; Zera endereço base do Segmento de Stack (SS)
	mov sp,start	; Aponta Stack Pointer (SP) para o inicio do código
	; intro msg
	mov si,intromsg
	call putstr
	; copia este código para o endereço 0x700
	mov si,sp		; Fonte
	mov di,0x700	; Destino
	inc ch			; CX = 0x100 (256 words = 512 bytes)
	rep				; Repete até CX = 0
	movsw			; Copia uma word (2 bytes) de SI para DI e decrementa CX
	; escaneia tabela de partições
	mov si,FAKEPART	; SI aponta para Partição falsa
	cmp dl,0x80		; Verifica se bootou de um HD
	jb main.4		; Não é HD, ler partição por CHS (não LBA)
	mov dh,0x1		; Quantidade de blocos
	call nread		; Lê MBR
	mov cx,0x1		; Duas passadas
.1:
	mov si,[MEM_BUF]; MBR lido
	add si,0x1be	; Tabela de partições
	mov dh,0x1		; Primeira entrada da tabela
.2:
	cmp byte [si+0x4],0xa5	; Partição FreeBSD?
	jne .3	; Não, pula esta
	jcxz .5	; Se for segunda passada, lê mesmo se não estiver ativa
	test byte [si],0x80	; Ver partição está ativa
	jnz .5	; Partição válida, lê-la
.3:
	add si,0x10	; SI -> próxima entrada na tabela
	inc dh		; Incrementa contadore de entradas
	cmp dh,0x5 	; Verifica contador
	jb .2		; Se dh < 0x5, lê próxima entrada da tabela
	dec cx		; Fim da tabela, decrementa contador de passadas
	jcxz .1		; Volta e inicia segunda passada
	jmp error	; Terminou segunda passada, erro
.4:
	xor dx,dx	; floppy: disco 0, partição 0
; lê particão em SI (entrada na tabela)
.5:
	mov [0x900],dx; MEM_ARG = 0x900
	mov dh,[NSECT]	; NSECT = 0x10 (número de setores para ler - BTX e boot2)
	call nread		; lê DH setores da partição apontada por SI
	mov bx,[MEM_BTX]; MEM_BTX = 0x9000
	mov si,[bx+0xa]	;
	add si,bx		; SI -> inicio de boot2.bin
	push ax			;
	xor ax,ax		;
	mov ax,[PAGE_SZ]; PAGE_SZ = 0x1000
	shl ax,0x1		; PAGE_SZ * 2 = 0x2000
	add ax,[MEM_USR]; MEM_USR = 0XA000, MEM_USR + PAGE_SZ*2 = 0xC000
	mov di,ax		; DI -> Page 2 do client
	mov ax,[NSECT]	; NSECT = 0x10
	sub ax,0x1		; NSECT-1 = 0x0F
	push bx			; Salva BX
	mov bx,[SECT_SZ]; SECT_SZ = 0x200 (Tamanho de setor)
	mul bx			; AX = AX * BX = SECT_SZ * (NSECT-1) = 0x1E00
	pop bx			; Restaura BX
	add ax,[MEM_BTX]; AX = MEM_BTX + SECT_SZ*(NSECT-1) = 0xAE00
	mov cx,ax		; CX = AX = MEM_BTX + SECT_SZ*(NSECT-1) = 0xAE00 ()
	pop ax
	sub cx,si
	rep
	movsb
; Libera Linha A20 (Mem acima de 1MB) com comandos para o Keyboard Controller
setA20:
	cli
.1:
	dec cx
	jz .3
	in al,0x64	; Status do Keyboard Controller
	test al,0x2	; Ocupado?
	jnz .1		; Sim, tenta novamente
	mov al,0xd1	; Envia comando para escrever
	out 0x64,al	; ....
.2:
	in al,0x64	; Status do Keyboard Controller
	test al,0x2	; Ocupado?
	jnz .2		; Sim, Tenta novamente
	mov al,0xdf	; Libera A20
	out 0x60,al	; ...
.3:
	sti
	jmp start+0x9010-0x7c00

nread:
	mov bx,[MEM_BUF]; Posição onde carregar
	mov ax,[si+0x8]	; Lê descrição LBA da partição (primeiro setor)
	mov cx,[si+0xa]	; ...
	push cs			; Salva Code Segment (0x0)
	call xread.1
	jnc return		; Retorna se não houver Erro
	mov si,DISK_ERROR_MSG
					; Continua para a rotina de erro se houver
error:
	call putstr
	mov si,ERROR
	call putstr
	xor ah,ah
	int 0x16
	jmp $

ereturn:
	mov si,ERROR
	call putstr
	mov ah,0x1
	stc
return:
	ret

read:
	;push cx
	;mov cx,0x700+0x80
	;test cs:cx,0x80
	;pop cx
	;jz .1
	cmp dl,0x80
	jb .1
	mov bx,0x55aa
	push dx
	mov ah,0x41
	int 0x13
	pop dx
	jc .1
	cmp bx,0xaa55
	jne .1
	test cl,0x1
	jz .1
	mov si,bp
	mov ah,0x42
	int 0x13
	ret
.1:
	push dx			; Salva
	mov ah,0x8		; BIOS: Lê parâmetros do disco
	int 0x13		; BIOS: Interrupção 13h
	mov ch,dh		; Máximo número de Head
	pop dx
	jc return
	and cl,0x3f
	jz ereturn
	cli				; Desabilita interruções
	mov eax,[bp+0x8] ; LBA do Stack
	push dx
	movzx ebx,cl	; Último indíce de setor (por track)
	xor edx,edx
	div ebx			; Div EAX (LBA) por ebx (indíce último setor)
	mov bl,ch		; Último indíce de cabeça
	mov ch,dl		; zero
	inc bx			;
	xor dl,dl
	div ebx
	mov bh,dl
	pop dx
	cmp eax,0x3ff
	sti				; Habilita interrupções
	ja ereturn		; Retorna erro
	xchg ah,al
	ror al,0x2
	or al,ch
	inc ax
	xchg cx,ax
	mov dh,bh
	sub al,ah
	mov ah,[bp+0x2]
	cmp al,ah
	jb .2
	mov al,0x1
.2:
	mov di,0x5	; 5 tentativas
.3:
	les bx,[bp+0x4]
	push ax
	mov ah,0x2
	int 0x13
	pop bx
	jnc .4	; pula para .4 se OK
	dec di	; Tentar novamente?
	jz .6	; Não -> pula
	xor ah,ah 	; BIO Func 0x0 = Reseta drive
	int 0x13	; Interrupção BIOS
	xchg ax,bx	;
	jmp .3		; Tena novamente
.4:
	movzx ax,bl
	add [bp+0x8],ax
	jnc .5
	inc word [bp+0xa]
.5:
	shl bl,1		; !!!No código do FreeBSD não tem a qtd de bits do shift!!!
	add [bp+0x5],bl
	sub [bp+0x2],al
	ja .1
.6:
	ret

; Imprime caractere armazenado no reg AL
putchr:
	push bx		; Salva o que esta em BX
	mov bx,0x7	; Cor Cinza
	mov ah,0xe	; BIOS: funcao para imprimir na tela
	int 0x10	; BIOS: Interrupcao 10
	pop bx		; Restaura o que estava em BX antes
; Imprime string apontada pelo SI
putstr:
	lodsb		; Carrega o proximo caracter em AL
	cmp al,0	; Ver se AL = 0 ...
	jne putchr	; ... senao, imprime caractere em AL
	ret

; Strings e Constantes
intromsg:		db `-boot1-\r\n`,0
DISK_ERROR_MSG: db "Disk error",0
ERROR:			db `\r\nError\r\n`,0
READ:			db `Read`,0
;PARTADDR:		dw 0x1be
;PART_FREEBSD: 	db 0xa5
MEM_BUF:		dw 0x8c00
MEM_BTX:		dw 0x9000
MEM_USR:  		dw 0xa000
NSECT:			db 0x10
PAGE_SZ:		dw 0x1000
SECT_SZ:		dw 0x200

flags:
	db 0x80

; Preenche espaco com 0 até inicio da tabela de partições

times 494-($-$$) db 90

; Partição real
;FAKEPART: db 0x80,0x1,0x1,0x0,0xa5,0xff,0xff,0xff,0x3f,0x0,0x0,0x0,0xa0,0xff,0x7f,0x1
; Partições falsas
;FAKEPART: db 0x80,0x0,0x2,0x0,0xa5,0x0,0x3,0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x1
FAKEPART:	db 0x80,0x0,0x1,0x0,0xa5,0xfe,0xff,0xff,0x0,0x0,0x0,0x0,0x50,0xc3,0x0,0x0

section .text
times 510-($-$$) db 0
dw 0xaa55
