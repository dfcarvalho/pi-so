[org 0x0600]	; Endereço de memória de onde o código será executado
BITS 16			; Modo real 16-bits

section .text	; Inicio do código
start:
	cld				; Lê strings para frente
	xor ax,ax		; Zera registrador AX
	mov es,ax		; Zera endereço base do Segmento Extra (ES)
	mov ds,ax		; Zera endereço base do Segmento de Dados (DS)
	mov ss,ax		; Zera endereço base do Segmento de Stack (SS)
	mov sp,0x7c00	; Aponta Stack Pointer (SP) para endereço 0x7c00
	; copia este código para o endereço 0x600 (de onde continuará a execução)
	mov si,sp		; Fonte
	mov di,start	; Destino
	mov cx,0x200	; Quantidade de bytes a serem copiados (512)
	rep				; Repete até CX = 0
	movsb			; Copia um byte de SI para DI e decrementa CX
	; Zera bits 0x800-0x80F para servir como partição falsa
	; TODO: ver se é necessário!
	mov bp,di		; Salva posição em BP
	mov cl,0x0F		; Quantidade de bytes a serem copiados (16)
	rep				; Repete até CX = 0
	stosb			; Copia um byte de AL para DI e decrementa CX
	inc byte [di-0xe] ; Posição 0x800 = 1
	jmp main-0x7c00+0x600 ; Continua o código a partida da nova posição
main:
	; Imprime cabeçalho
	mov si,intromsg	; Coloca msg de intro no reg de entrada
	call putstr		; Imprime msg de intro
	; Lê partições
	call putn
	call putn
	push dx			; Salva número do disco de boot
	mov bx,[PARTADDR]
	add bx,0x600
	;push bx		; Salva endereco da primeira particao
	add bx,0x4		; Ir para o bit do tipo de partição (+4)
read_entry:
	mov al,[bx]		; Armazena o tipo de partição em AL
	test al,al		; Verifica se está vazio
	jz next_entry	; Pula partição vazia
	mov di,PART_TYPES	; Carrega tabela de tipos de partições suportadas
	mov cl,[TLEN]	; Guarda número de tipos de partições suportadas em CL
	inc cl			; + 1
	repne			; Compara tipo de partição lida com as partições possíveis...
	scasb			; ... Quando encontrar, DI = índice do tipo + 1
	sub di,1		; DI aponta para indice do tipo
	cmp byte [di],0xa5; Ver se é partição FreeBSD
	jne print_part	; Se não for, só imprime
; Seleciona partição
select_part:
	sub bx,0x4		; É partição FreeBSD, seleciona para leitura do boot1
	push bx			; Salva endereço da partição FreeBSD
	add bx,0x4
print_part:
	add di,[TLEN]	; DI aponta para o offset do nome do tipo da partição
	mov cl,[di]		; Armazena o offset do nome do tipo da partição em CL
	add di,cx		; Adiciona o offset ao DI, que passa a apontar para a string do nome
	call putpart	; Imprime a partição no formato: Drive [NUM]: [TIPO]
	call putn
; Próxima partição
next_entry:
	inc dx				; Incrementa dx (próximo drive)
	inc byte [nxtdrv] 	; Altera número da próxima partição na string
	add bl,0x10			; + 16 bits = próxima entrada da tabela de partições
	jnc read_entry		; Se BL < 0x100 continua lendo, senão acabou a tabela de partições
; Lê 1o setor da partição "selecionada" (1a partição)
read_boot1:
	pop si			; Recupera o endereço da primeira partição
	pop dx 			; Recupera o número do disco/partição de boot
	mov bx,0x7c00	; Endereco onde carregar boot1
	call readdsk	; Lê 1 setor para endereço em ES:BX
	jmp 0x7c00		; Executa boot1

; Rotina para passar para a proxima linha na tela
putn:
	push si 		; Salva o que esta em SI
	mov si,newline	; Carrega caracteres de nova linha em SI
	call putstr		; Imprime a nova linha
	pop si			; Restaura o que estava em SI antes
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

; Imprime em Hexadecimal
puthex:
	push ax
	push bx
	push cx
	mov cx,0x1
; primeiro byte
	mov ax,dx	; Copia valor a ser impresso para AX
	mov ah,al	; Copia o primeiro byte em cima do segundo
; Imprime byte atual
puthexp:
	lea bx,[TABLE]	; Armazena em BX o endereco da TABLE
	shr ah,4		; AH passa a conter os 4 primeiros bits (valor = 0-F)
	and al,0x0F		; AL passa a conter os 4 últimos bits (valor = 0-F)
	xlat			; Copia o valor da TABLE no índice AL para AL
	xchg ah,al		; Inverte AH e AL
	xlat			; Copia o valor da TABLE no índice AL para AL
	lea bx,[STRING]	; Armazena em BX o endereco do buffer para a string
	;xchg ah,al
	mov [bx],ax		; Copia a string para o buffer
	mov si,STRING	; Copia endereco do buffer para SI
	call putstr		; Imprime string apontada por SI
	cmp cx,0x2		; Ver se já é 2o byte
	je puthexe		; Já é o 2o, ir para final
; segundo byte
	mov cx,0x2		; Indica que é o 2o byte
	mov ax,dx		; Copia o valor a ser impresso para AX novamente
	mov al,ah		; Copia o segundo byte em cima do primeiro
	jmp puthexp
; Finaliza função puthex
puthexe:
	pop cx
	pop bx
	pop ax
	ret

putpart:
	; Imprime número do drive
	mov si,drive
	call putstr
	mov si,di
	call putstr
	ret

; Lê 1o setor da partição descrita em SI e carrega-o para a posicao de memoria ES:BX
readdsk:
	push ax
	push cx
	push dx
	mov ah,0x2		; BIOS: funcao para ler setor
	mov dh,[si+1]	; Head (2o byte dos dados da partição)
	mov cx,[si+2]	; Cylinder+Sector (3o byte dos dados da partição)
	mov al,1		; Número de setores para ler = 1 setor
	push ax 		; Salvar qtd de setores que deve ler para verificar se leu tudo depois
	int 0x13		; Lê
	jc disk_error 	; Erro?
	pop dx			; Restaura qnt de setores que devia ler
	cmp dl,al		; Verifica se leu todos os setores
	jne disk_error	; Erro?
	pop dx
	pop cx
	pop ax
	ret
disk_error:
	call putn
	mov si,DISK_ERROR_MSG
	call putstr
	ret

; Strings e Constantes
intromsg:		db `PI V - Sistemas Operacionais\r\nDanilo Carvalho, Carlos Romeu, Nicolas Alexandre\r\nProf: Flavia`,0
newline:		db `\r\n`,0	; Caracteres de nova linha
drive:			db "Particao "	; Para impressão ... de partições
nxtdrv: 		db "1: ",0		; ...
DISK_ERROR_MSG: db "Erro de leitura de disco!",0
TABLE: 			db "0123456789ABCDEF",0	; Para impressão de Hexadecimal
PARTADDR:		dw 0x1be	; Endereço onde começa a tabela de partições
PART_TYPES: 	db 0x83,0xa5,0x07	; Tipos de partições suportadas
PART_OFFSETS:
OFFSET_LINUX: 	db PART_LINUX-$			; Offset para a string "Linux"
OFFSET_FREEBSD: db PART_FREEBSD-$	; Offset para a string "FreeBSD"
OFFSET_WIN: 	db PART_WIN-$					; Offset para a string "Windows"
PART_LINUX: 	db "Linux",0
PART_FREEBSD: 	db "FreeBSD",0
PART_WIN: 		db "Windows",0
TLEN:			db PART_OFFSETS - PART_TYPES	; Número de tipos de partições suportadas

; Buffer para impressão de Hexadecimal
section .bss
STRING:			resb 50

; Preenche espaco com 0 até inicio da tabela de partições
section .text
times 446-($-$$) db 0

; Partição real
;FAKEPART: 	db 0x80,0x1,0x1,0x0,0xa5,0xff,0xff,0xff,0x3f,0x0,0x0,0x0,0xa0,0xff,0x7f,0x1
; Partições falsas (para testes)
FAKEPART: 	db 0x80,0x0,0x2,0x0,0xa5,0x0,0x3,0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x1
FAKEPART2: db 0x80,0x0,0x2,0x0,0x07,0x0,0x3,0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x1
FAKEPART3: db 0x80,0x0,0x2,0x0,0x83,0x0,0x3,0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x1

 ; Preenche espaco com 0 até número mágico
times 510-($-$$) db 0
MAGIC: dw 0xaa55
