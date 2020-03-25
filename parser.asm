code_seg segment
	assume  cs:code_seg,ds:code_seg,es:code_seg
	org 100h
start:
    jmp begin
	
;----------{ constants }----------
dog			EQU	40h		;@	
dot			EQU	2eh		;.
hyphen		EQU 2dh		;-
underscore 	EQU	5fh		;_
plus		EQU 2bh		;+
apostrophe	EQU 27h		;'
comma		EQU 2ch		;,
semicolon	EQU 3bh		;;
CR		EQU	13
LF 		EQU	10
Space	EQU	20h

;----------{ functions }----------
; 
; В al строчная латинская буква в нижнем регистре? 0 : 1
;
isLetterLC PROC near	
	pushf				
	cmp al, 61h
	jl notLetter
	cmp al, 7ah
	jg notLetter
	mov ah, 0
	jmp exitIsLetterLC
notLetter:
	mov ah, 1
exitIsLetterLC:
	popf
	ret
isLetterLC endp
; 
; В al строчная латинская буква в верхнем регистре? 0 : 1
;
isLetterUC PROC near	
	pushf				
	cmp al, 41h
	jl @@notLetter
	cmp al, 5ah
	jg @@notLetter
	mov ah, 0
	jmp exitIsLetterUC
@@notLetter:
	mov ah, 1
exitIsLetterUC:
	popf
	ret
isLetterUC endp
; 
; В al передана цифра ? 0 : 1
;
isNumeral PROC near
	pushf				
	cmp al, 30h
	jl notNumeral
	cmp al, 39h
	jg notNumeral
	mov ah, 0
	jmp exitIsNumeral
notNumeral:
	mov ah, 1
exitIsNumeral:
	popf
	ret
isNumeral endp
;
; В al символ локальной части (точка проверяется отдельно)? 0 : 1
;
isCharacter PROC near
	pushf
	mov ah, 0
	cmp al, hyphen
	je exitIsCharacter
	cmp al, underscore
	je exitIsCharacter
	cmp al, plus
	je exitIsCharacter
	cmp al, apostrophe
	je exitIsCharacter
notCharacter:
	mov ah, 1
exitIsCharacter:
	popf
	ret
isCharacter endp
;
; Печать переданного символа
;
print_letter	macro letter
	push	AX
	push	DX
	mov	DL,	letter
	mov AH, 02
	int 21h
	pop DX
	pop AX
	endm
;
; Печать переданного сообщения
;
print_mes	macro message
	local	msg, nxt
	push	AX
	push	DX
	mov	DX, offset	msg
	mov	AH, 09h
	int	21h
	pop	DX
	pop AX
	jmp nxt
msg	DB	message,'$'
nxt:
	endm
;
; Процедура очистки Buffer. Сбрасывает BufferIndex.
;
emptyBuffer PROC near
	LOCALS @@
	pushf
	cmp BufferIndex, 0
	je @@exit
	push cx
	push di
	mov cx, BufferIndex
	mov di, 0
@@cycle:
	mov Buffer[di], 0
	inc di
	loop @@cycle
	mov BufferIndex, 0
	pop di
	pop cx
@@exit:	
	popf
	dec BufferIndex		; BufferIndex устанавливается в -1, чтобы избежать
	ret					; заполнения буфера со второго элемента
emptyBuffer endp
;
; Процедура проверки локальной части
;
checkBuffer PROC near
	LOCALS @@
	pushf
	push di
	mov ah, 1
	cmp BufferIndex, 0		; длина локальной части не 0
	jne @@cont_cb1
	jmp @@exit
@@cont_cb1:
	mov di, BufferIndex
	cmp Buffer[di], dot		; последний символ не точка
	jne @@cont_cb2
	jmp @@exit
@@cont_cb2:
	mov di, 0
	cmp Buffer[di], dot		; первый символ не точка
	jne @@cont_cb3
	jmp @@exit
@@cont_cb3:
	push cx
	mov cx, BufferIndex
@@cycle:
	mov al, Buffer[di]
	call isLetterLC			; i-ый символ строчная латинская буква
	cmp ah, 0
	je @@cont_cycle
	call isLetterUC			; i-ый символ заглавная латинская буква
	cmp ah, 0
	je @@cont_cycle
	call isNumeral			; i-ый символ цифра
	cmp ah, 0
	je @@cont_cycle
	call isCharacter		; i-ый символ специальный символ
	cmp ah, 0
	je @@cont_cycle
	cmp al, dot				; i-ый символ точка (реализована отдельная проверка)
	jne @@exit_cycle
	cmp al, Buffer[di+1] 	; Если i-ый символ точка, тогда i+1-ый не точка
	jne @@cont_cycle
@@exit_cycle:
	pop cx
	jmp @@exit
@@cont_cycle:
	inc di
	loop @@cycle
	pop cx
@@exit:
	pop di
	popf
	ret
checkBuffer endp
;
; Процедура проверки домена
;
checkDomainBuffer PROC near
	LOCALS @@
	pushf
	push di
	push cx
	push bx		; маркер поддомена (пропускает не более однйой точки)
	mov ah, 1
	cmp BufferIndex, 0
	je @@exit
	mov di, BufferIndex
	cmp Buffer[di], hyphen	; последний символ дефис
	je @@exit
	cmp Buffer[di], dot		; последний символ точка
	je @@exit
	mov di, 0
	cmp Buffer[di], hyphen 	; первый символ дефис
	je @@exit
	cmp Buffer[di], dot		; первый символ точка
	je @@exit
	xor bx, bx
	mov cx, BufferIndex
@@cycle:
	mov al, Buffer[di]
	call isLetterLC				; i-ый символ строчная латинская буква
	cmp ah, 0
	je @@cont_cycle
	call isLetterUC				; i-ый символ заглавная латинская буква
	cmp ah, 0
	je @@cont_cycle
	call isNumeral				; i-ый символ цифра
	cmp ah, 0
	je @@cont_cycle
	cmp al, hyphen				; i-ый символ дефис
	je @@cont_cycle
	cmp al, dot					; i-ый символ точка
	jne @@exit
	inc bx
	cmp bx, 1			; встретилась единственная точка
	jne @@exit
	cmp Buffer[di-1], hyphen	; перед точкой дефис
	je @@exit
	cmp Buffer[di+1], hyphen	; после точки дефис
	je @@exit
@@cont_cycle:
	inc di
	loop @@cycle
@@exit:
	pop bx
	pop cx
	pop di
	popf
	ret
checkDomainBuffer endp
;
;процедура записываем локальную часть в файл
;
outputBuffer proc near
	LOCALS @@
	push dx
	push bx
	push ax					
	push cx
	mov bx,handler2
	mov dx,offset Buffer
	mov ah,40h
	mov cx, BufferIndex
	inc cx
	int 21h
	pop cx
	pop ax
	pop bx
	pop dx
	ret
outputBuffer endp

terminator proc	near
	LOCALS @@
	push di
	push bx
	push dx
	mov di, BufferIndex
	cmp buf,dog				;если собака то вызываем проверку и выходим без очистки
	je @@callcheckb			;при других ограничителях выходим и чистим буффер:
	cmp buf,semicolon		;точка с запятой	
	je @@exitcl
	cmp buf,Space			;пробел
	je @@exitcl
	cmp buf,comma			;запятая
	je @@exitcl
	cmp buf,CR				;каретка
	je @@exitcl
	cmp buf,LF				;строка
	je @@exitcl
	jmp @@exit
@@callcheckb:				;если мы встретим собаку то ставим флажок, увеличиваем каунтер майлов
	inc Flag
	inc CountAll
	call outputBuffer		;и сразу выводим локальную часть в файл
	mov di, BufferIndex
	mov Buffer[di],0		;в конце буффера собака, нужно убрать
	dec BufferIndex	
	call checkBuffer
	cmp ah,1	
	je @@exit1
	mov IsLocal,0			;если чекбуфер вернул 0 то сохраним в переменную излокал, иначе оставим единицу
	@@exit1:				
	jmp @@terminator_cont
@@exitcl:
	mov di,Flag				;если флаг не стоит то просто чистим буффер
	cmp di,0				
	je  @@terminator_cont
	mov di,BufferIndex		;если же флаг стоит то в буффере доменная часть
	mov Buffer[di+1],CR
	mov Buffer[di+2],LF
	inc BufferIndex
	inc BufferIndex
	call outputBuffer		;её мы сразу выведем
	dec BufferIndex
	dec BufferIndex
	call checkDomainBuffer
	dec Flag				;уберем флажок локальной части
	mov di, IsLocal
	cmp di,1				;если локальная часть неверная
	je @@terminator_cont	
	cmp ah,1				;или доменная часть неверная
	je @@terminator_cont	;то количество верных не меняем
	inc CountRight			
	mov IsLocal,1			;иначе увеличим количество верных майлов и вернем дефолтное значение излокал
@@terminator_cont:
	call emptyBuffer
@@exit:
	pop dx
	pop bx
	pop di
	ret
terminator endp

writeBuffer proc near
	cmp BufferIndex,64
	jne cont1
	call emptyBuffer
	cont1:
	mov ah,	3fh      ; будем читать из файла
    mov cx,	1        ; 1 байт
	mov di,BufferIndex
    mov dx,offset buf      ; в память buf
    int 21h 
	mov dl,buf
	mov Buffer[di],dl
	ret
writeBuffer endp

str_word_to_ascii:
	mov	cx, 4		; в слове 4 ниббла (полубайта)
@@:
	rol	ax, 4		; выдвигаем младшие 4 бита
	push	ax		; сохраним AX
	and	al, 0Fh		; оставляем 4 младших бита AL
	cmp	al, 0Ah		; сравниваем AL со значение 10
	sbb	al, 69h		; целочисленное вычитание с заёмом
	das			; BCD-коррекция после вычитания
	stosb                   ; помещаем получившийся символ в буфер
	pop	ax		; восстановим AX
	loop	@@		; цикл
	ret		

begin:
	mov ax,3d02h
	mov dx,offset OutputName
	int 21h
	mov Handler2,ax
	;----------------{ check string of parameters }-----------------
	mov CL, ES:[80h] ; addr. of length parameter in psp
	; is it 0 in buffer?
	cmp CL, 0
	jne $cont ; yes
	;--------------------------------------------------------------- 
	print_mes	'Input File Name > '
	mov	AH,	0Ah  
	mov	DX,	offset FileName
	int  21h 
	print_letter 13
	print_letter 10
	;===============================================================  
	xor BH, BH  
	mov BL,  FileName[1]  
	mov FileName[BX+2], 0 
	;===============================================================  
	mov AX, 3D02h  ; Open file for read/write
	mov DX, offset FileName+2  
	int 21h  
	jnc openOK
	jmp error1
	;=============================================================== 
$cont:
	xor BH, BH
	mov BL, ES:[80h] ; а вот так -> mov BL, [80h]нельзя!!!!
	mov byte ptr [BX+81h], 0
	;---------------------------------------------------------------
	mov CL, ES:80h ; Длина хвоста в PSP
	xor CH, CH ; CX=CL= длина хвоста
	cld ; DF=0 - флаг направления вперед
	mov DI, 81h ; ES:DI-> начало хвоста в PSP
	mov AL,' ' ; Уберем пробелы из начала хвоста
	repe scasb ; Сканируем хвост пока пробелы
	; AL - (ES:DI) -> флаги процессора
	; повторять пока элементы равны
	dec DI ; DI-> на первый символ после пробелов
	;---------------------------------------------------------------
	xor bx, bx
fn_filler:
    cmp bx, 14
    je exit_filler
	mov al, [di+bx]
	mov FileName[bx+2], al
	inc bx
	jmp fn_filler
exit_filler:
	mov AX, 3D00h ; Open file for read
	mov DX, DI
	int 21h  
	jnc openOK
	jmp error1
;=====================================================
openOK:
	MOV Handler, ax ; Сохранение дескриптора	
	mov bx, Handler       ; копируем в bx указатель файла
    xor cx,	cx
    xor dx,	dx
	
out_str:
	mov di, Flag
	
    call writeBuffer 	;читаем 1 байт в буффер       
    cmp ax,	cx       ; если достигнуть EoF или ошибка чтения
    jnz close       ; то закрываем файл закрываем файл
	call terminator
    
	;mov dl, buf 
    ;mov ah,	2        ; выводим символ в dl
    ;int 21h     ; на стандартное устройство вывода
	
	inc BufferIndex		;увеличим индекс на 1 
    jmp out_str
close:           ; закрываем файл, после чтения
	cld
	mov di,offset Buffer
	mov ax,CountAll
	print_mes "Total emails: "
	call str_word_to_ascii
	mov Buffer[5],'$'
	mov ah,9
	mov dx,offset Buffer
	int 21h
	print_letter CR
	print_letter LF
	
	cld
	mov di,offset Buffer
	mov ax,CountRight
	print_mes "Correct emails: "
	call str_word_to_ascii
	mov Buffer[5],'$'
	mov ah,9
	mov dx,offset Buffer
	int 21h
	print_letter CR
	print_letter LF
	
	mov bx,Handler
    mov ah,	3eh
    int 21h	
	mov bx,Handler2
    mov ah,	3eh
    int 21h	
exit:            ; завершаем программу
    mov ah,4ch
    int 21h
	
;-----------{ errors }------------
error1:
	print_mes "File opening/creation error"
	int 20h
	
;----------{ variables }----------
buf db 0
Buffer DB 41h dup(0)   
DomainBuffer DB 80h dup(0)
Handler DW  ?
Handler2 dw ?  
BufferIndex DW 0
DomainBufferIndex DW 0 
FileName    DB  14, 0, 14 dup (0)
OutputName db 'emails.txt'
Flag dw 0
CountAll dw 0
CountRight dw 0
IsLocal dw 1
;--------------------------------- 

code_seg ends
	end start