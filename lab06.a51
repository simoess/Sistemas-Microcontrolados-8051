#include "at89c5131.h"
; endereços de leitura e escrita do RTC
#define RADDR 0xD1
#define WADDR 0xD0

; SSCON
#define SSIE	0x40
#define STA		0x20
#define STO		0x10	
#define SI		0x08
#define AA 		0x04
 
/************
* I2C e RTC        *
************/
#define I2C_SDA P4.1
#define I2C_SCL P4.0
// Deve ser colocado na posição correta do JP5.
#define RTC_SQW P3.4

/*******
* LEDs *
*******/
// Driver interno de corrente. deve ser configurado via LEDCON
#define LED1        P3.6
#define LED2        P3.7
// Transistor externo
#define LED3        P1.4
/****/


;============================================================
; Variáveis RTC
;============================================================
MULT EQU 40h 

; Serão utilizados para setar e pegar a data/hora do RTC
SEC EQU 50h
MIN EQU 51h
HOU EQU 52h
DAY EQU 53h
DAT EQU 54h
MON EQU 55h
YEA EQU 56h
CTR EQU 57h


; serão utilizados para chamar as funções do i2c
B2W	EQU 66h 	; bytes to write
B2R EQU 67h 	; bytes to read
ADDR EQU 68h 	; internal register address
DBASE EQU 69h 	; endereço base dos dados a serem escritos.


;============================================================
; bit endereçáveis
;============================================================
; Uma vez que o HW I2C executa "paralelo" ao 51 e o SW é 
; totalmente composto de interrupções
; devemos evitar que uma comunicação se inicie antes
; de outra terminar
I2C_BUSY EQU 00h ; 0 - I2C livre, 1 - I2C ocupada
;============================================================
; Vetor de interrupção (0x0000 até 0x007A)
;============================================================
	ORG 0x0000 ; reset
	LJMP init
 	ORG 0x000B
	jmp timer_0_ir
	RETI
	ORG 0x0023 ; serial	(Place-holder)
	RETI
	
	ORG	0x0043 ; TWI (I2C)		
	LJMP i2c_int
;============================================================
; Código (0x007B até 0x7FFF)
;============================================================
	ORG 0x007B
;------------------------------------------------------------
; 1 - Inicializar o HW.
;------------------------------------------------------------

init:
	MOV SEC, #0 ; BCD segundos, deve ser iniciado 
				   ; com valor PAR para o relogio funcionar.
	MOV MIN, #0; BCD minutos
	MOV HOU, #0; BCD hora, se o bit mais alto for 1,
				   ; o relógio é 12h, senão BCD 24h
	MOV DAY, #0; Dia da semana
	MOV DAT, #0; Dia
	MOV MON, #0; Mês
	MOV YEA, #0; Ano
	MOV CTR, #0; SQW desativada em nível 0
	
	ACALL setar_relogio
	
;	1.0 - Desabilita as interrupções
	MOV IEN0, #0x00
	MOV IEN1, #0x00

; 	1.1 - Configurar o Timer 0
	MOV TMOD, #0x01 ; T0 no modo timer 16bits

;	1.2 - Configurar o I2C (TWI)
	SETB I2C_SCL
	SETB I2C_SDA ; Coloca os latches em high-Z

	; CR2 = 0, CR1 = 0, CR0 = 1, divisor XX,
	; clock 24MHz, I2C = XXXk

	MOV SSCON, #01000001b
			   ;||||||||_ CR0
		 	   ;|||||||__ CR1
			   ;||||||___ AA 
			   ;|||||____ SI  flag de int
			   ;||||_____ STO to send a stop
			   ;|||______ STA to send a start
			   ;||_______ SSIE Enable TWI
			   ;|________ CR2

;	1-3 Habilita as interrupções
	MOV IPL1, #0x02
	MOV IPH1, #0x02
	MOV IEN1, #0x02	; habilita a int do i2c
	
; 	2.1 - SEG, 24/06/2013 - 22:27:00
	 
	
	
	
	MOV TMOD, #00010110b
	
	;;;timer 0 conta eventos externos em P3.4
		;conta de 8 em 8
	MOV TH0, #255d ; 
	MOV TL0, #255d;    
	MOV IEN1, #0x02	; habilita a int do i2c
	 
	
//	SETB TF0
	//SETB TF1  
	CLR TR0; ativa timer 0
	SETB ET0 ;ativa interrupção do timer 0	
	SETB EA
	;LCALL RTC_SET_TIME
	

	
 	ACALL RTC_SET_TIME
	SETB TR0
	ACALL inicializar_lcd
	ACALL UPDATE_LCD
main:

	JMP main
;------------------------------------------------------------
; Nunca deverá chegar aqui!
	 JMP init
;------------------------------------------------------------

 
runT1:
    MOV TH1,#0FCh 	;fclk CPU = 24MHz
    MOV TL1,#17h 	; ... base de tempo de 0,5ms
    SETB TR1 		;dispara timer

    JNB TF1,$ 		;preso CLR TR0 ;stop timer
    CLR TR1 		;para o timer 0
    CLR TF1 		;zera flag overflow
    DJNZ MULT,runT1
    RET   

	
RTC_SET_TIME:
	MOV ADDR, #0x00		; endereço do reg interno
	MOV B2W, #(8+1) 	; a quantidade de bytes que deverão 
						; ser enviados + 1.
	MOV B2R, #(0+1)		; a quantidade de bytes que serão 
						; lidos + 1.
	MOV DBASE, #SEC		; endereço base dos dados

	; gera o start, daqui pra frente é tudo na interrupção.
	MOV A, SSCON
	ORL A, #STA
	MOV SSCON, A

	; devemos aguardar um tempo "suficiente"
	; para ser gerada a interrupção de START
	MOV MULT, #0xA ; 5ms
	LCALL runT1

	JB I2C_BUSY, $

	RET
	
RTC_GET_TIME:
	MOV ADDR, #0x00		; endereço do reg interno
	MOV B2W, #(0+1) 	; a quantidade de bytes que deverão 
						; ser enviados + 1.
	MOV B2R, #(8+1)		; a quantidade de bytes que serão 
	 					; lidos + 1.
	MOV DBASE, #SEC		; endereço base dos dados (buffer)

	; gera o start, daqui pra frente é tudo na interrupção.
	MOV A, SSCON
	ORL A, #STA
	MOV SSCON, A

	; devemos aguardar um tempo "suficiente"
	; para ser gerada a interrupção de START
	MOV MULT, #0xA
	LCALL runT1

	JB I2C_BUSY, $

	RET

;------------------------------------------------------------
; Nome:	i2c_int
; Descrição: Rotina de atendimento da interrupção do TWI
; Parâmetros:
; Retorna:
; Destrói: A, DPH, DPL (DPTR)
;------------------------------------------------------------
i2c_int:
	CPL LED2 ; "pisca" um led na int somente para debug.
   	
	MOV A, SSCS ; pega o valor do Status
	RR A		; faz 1 shift (divide por 2)

	LCALL decode ; opera o PC, faz cair exatamente no
				 ; local correto abaixo.
								 
	; Como isso funciona? :
	; cada LJMP tem 3 bytes, NOP 1 byte.
	; LJMP + NOP = 4 bytes.
	; os códigos de retorno do SSCS são multiplos de 8, 
	; dividindo por 2 ficam multiplos de 4
	; quando "chamamos" decode com LCALL, o PC de retorno (
	; que é o primeiro LJMP abaixo deste comentário)
	; fica salvo na pilha.
	; capturo o PC de retorno da pilha e somo esse multiplo.
	; quando acontecer o RET, estaremos no LJMP exato
	; para atender a int!
	
	; Erro no Bus (00h)
	LJMP ERRO ; 0
	NOP
	; start	(8h >> 1 = 4)
	LJMP START
	NOP	
	; re-start (10h >> 1 = 8)
	LJMP RESTART
	NOP
	; W ADDR ack (18h >> 1 = 12)
	LJMP W_ADDR_ACK
	NOP
	; W ADDR Nack (20h >> 1 = 16)
	LJMP W_ADDR_NACK
	NOP
	; Data ack W (28h >> 1 = 20)
	LJMP W_DATA_ACK
	NOP
	; Data Nack W (30h >> 1 = 24)
	LJMP W_DATA_NACK
	NOP
	; Arb-Lost (38h >> 1  = 28)
	LJMP ARB_LOST
	NOP
	; R ADDR ack (40h >> 1 = 32)
	LJMP R_ADDR_ACK
	NOP
	; R ADDR Nack (48h >> 1 = 36)
	LJMP R_ADDR_NACK
	NOP
	; Data ack R (50h >> 1 = 40)
	LJMP R_DATA_ACK
	NOP
	; Data Nack R (58h >> 1 = 44)
	LJMP R_DATA_NACK
	NOP

	; slave receive não implementado
	LJMP not_impl
	NOP ; 60
	LJMP not_impl
	NOP ; 68
	LJMP not_impl
	NOP ; 70
	LJMP not_impl
	NOP ; 78
	LJMP not_impl
	NOP ; 80
	LJMP not_impl
	NOP ; 88
	LJMP not_impl
	NOP ; 90
	LJMP not_impl
	NOP ; 98
	LJMP not_impl
	NOP ; A0
	;slave transmit não implementado
	LJMP not_impl
	NOP ; A8
	LJMP not_impl
	NOP ; B0
	LJMP not_impl
	NOP ; B8
	LJMP not_impl
	NOP ; C0
	LJMP not_impl
	NOP ; C8

	; códigos não implementados
	LJMP not_impl
	NOP ; D0
	LJMP not_impl
	NOP ; D8
	LJMP not_impl
	NOP ; E0
	LJMP not_impl
	NOP ; E8
	LJMP not_impl
	NOP ; F0

	; nada a ser feito (apenas "cai" no fim da int)
	LJMP end_i2c_int
	NOP ; F8
;------------------------------------------------------------
not_impl:
end_i2c_int:
	RETI
;============================================================
; Está é a função que opera o PC e faz o retorno
; ir para o local correto.
;============================================================
decode:
	POP DPH
	POP DPL			; captura o PC "de retorno"
	ADD A, DPL
	MOV DPL, A		; soma nele o valor de A (A = SSCS/2)
	JNC termina
	MOV A, #1
	ADD A, DPH		; se tiver carry, aumenta a parte alta.
	MOV DPH, A
termina:
	PUSH DPL		; põem o novo pc na pilha 
	PUSH DPH		; e ...
	RET				; pula pra ele!
;============================================================
	
;------------------------------------------------------------
; Aqui se iniciam as "verdadeiras" ISRs
; A implementação dessas ISRs seguiu os modelos 
; propostos no datasheet
; Porém não foram implementadas todas as possibilidades
; para todos os códigos
; foram implementadas apenas as necessárias para garantir
; um fluxo de dados de escrita e leitura como master, 
; contemplando inclusive as possíveis falhas
;------------------------------------------------------------
ERRO:
	MOV A, SSCON
	ANL A, #STO ; gera um stop
	MOV SSCON, A
	CLR	I2C_BUSY ; zera o flag de ocupado
	LJMP end_i2c_int
;------------------------------------------------------------
START:
; um start SEMPRE vai ocasionar uma escrita
; pois para ler, preciso primeiro escrever de onde vou ler!
; SSDAT = SLA + W
; STO = 0 e SI = 0
	SETB I2C_BUSY		; seta o flag de ocupado
	MOV SSDAT, #WADDR
	MOV A, SSCON
	ANL A, #~(STO | SI)	; zera os bits STO e SI
	MOV SSCON, A
	LJMP end_i2c_int
;------------------------------------------------------------
RESTART:
; o Restart será utilizado apenas para leituras,
; onde há a necessidade de fazer um
; start->escrita->restart->leitura->stop
; SSDAT = SLA + R
; STO = 0 e SI = 0
	MOV SSDAT, #RADDR
	MOV A, SSCON
	ANL A, #~(STO | SI)	; zera os bits STO e SI
	MOV SSCON, A
	LJMP end_i2c_int
;------------------------------------------------------------
W_ADDR_ACK:
; após um W_addr_ack temos que escrever o
; registrador interno!
; SSDAT = ADDR
; STA = 0, STO = 0, SI = 0
	MOV SSDAT, ADDR
	MOV A, SSCON
	ANL A, #~(STA | STO | SI)	; zera os bits STA, STO e SI
	MOV SSCON, A
	LJMP end_i2c_int
;------------------------------------------------------------
W_ADDR_NACK:
; em caso de nack, ou o end ta errado ou o slave
; não está conectado. não vamos fazer retry,
; encerramos a comunicação.
; STA = 0, SI = 0
; STO = 1
	MOV A, SSCON
	ANL A, #~(STA | SI)	; zera os bits STA e SI
	ORL A, #STO					; seta STO
	MOV SSCON, A
	LJMP end_i2c_int
;------------------------------------------------------------
W_DATA_ACK:
; após o primeiro data ack (registrador interno)
; temos 2 opções:
; 1 - escrever um novo byte
; 2 - gerar um restart para leitura
	DJNZ B2W, wda1		; enquanto tiver bytes para
						; escrever, pula para wda1

	; se não tiver mais bytes para escrever, começe a ler
	DJNZ B2R, wda2		;se tiver algum byte pra ler,
						; pula para wd
	MOV A, SSCON 
	ANL A, #~(STA | SI)	; senão..
	ORL A, #STO			; gera um STOP
	MOV SSCON, A
	CLR	I2C_BUSY ; zera o flag de ocupado
	LJMP end_i2c_int
wda2:
	MOV A, SSCON 
	ANL A, #~(STO | SI)
	ORL A, #STA			; ..gera um restart!
	MOV SSCON, A
	LJMP end_i2c_int
wda1:
	MOV R0, DBASE
	MOV SSDAT, @R0	; ...escreve o proximo!
	MOV A, SSCON
	ANL A, #~(STA | STO | SI) ; zera STA, STO e SI
	MOV SSCON, A
	INC DBASE		; incrementa o indice do buffer
	LJMP end_i2c_int
;------------------------------------------------------------
W_DATA_NACK:
; após um data_nack, podemos repetir ou encerrar
; vamos encerrar
	MOV A, SSCON 
	ANL A, #~(STA | SI)
	ORL A, #STO			; gera um STOP
	MOV SSCON, A
	CLR	I2C_BUSY ; zera o flag de ocupado
	LJMP end_i2c_int	
;------------------------------------------------------------
ARB_LOST:
; após um arb-lost podemos acabar sendo
; endereçados como slave
; o arb-lost costuma ocorrer em 2 situações:
; 1 - problemas físicos no bus
; 2 - ambiente multi-master (não é o caso)
; em ambos os casos, não vamos fazer nada!
; pois não estamos implementando a comunicação em modo slave.
	LJMP end_i2c_int	
;------------------------------------------------------------
R_ADDR_ACK:
; depois de um R ADDR ACK, recebemos os bytes!
	MOV A, SSCON
	ANL A, #~(STA | STO | SI) ; receberemos o proximo byte
	
	DJNZ B2R, raa1 ; decrementa a quantidade de
				   ; bytes a receber!
	; se der 0, é o ultimo byte a ser recebido
	ANL A, #~AA	; retorne NACK
	SJMP raa2
	; se não...
raa1:
	ORL A, #AA	; retorne ACK para o slave!
raa2:	
	MOV SSCON, A
	LJMP end_i2c_int	
;------------------------------------------------------------
R_ADDR_NACK:
; idem ao w_addr_nack
	MOV A, SSCON 
	ANL A, #~(STA | SI)
	ORL A, #STO			; gera um STOP
	MOV SSCON, A
	CLR	I2C_BUSY ; zera o flag de ocupado
	LJMP end_i2c_int	
;------------------------------------------------------------
R_DATA_ACK:
; se tiver mais bytes pra ler, de um ack, senão de um nack

	MOV R0, DBASE
	MOV	@R0, SSDAT ; le o byte que já chegou

	MOV A, SSCON
	ANL A, #~(STA | STO | SI) ; receberemos o proximo byte
	
	DJNZ B2R, rda1  ; decrementa a quantidade de 
					; bytes a receber!
	; se der 0, é o ultimo byte a ser recebido
	ANL A, #~AA	; retorne NACK
	SJMP rda2
	; se não...
rda1:
	ORL A, #AA	; retorne ACK para o slave!
rda2:	
	MOV SSCON, A
	INC DBASE ; incrementa o buffer
	LJMP end_i2c_int
;------------------------------------------------------------
R_DATA_NACK:
; salva o ultimo byte e termina

	MOV R0, DBASE
	MOV	@R0, SSDAT ; le o byte que já chegou

	MOV A, SSCON 
	ANL A, #~(STA | SI)
	ORL A, #STO			; gera um STOP
	MOV SSCON, A

	INC DBASE ; inc o buffer

	CLR	I2C_BUSY ; zera o flag de ocupado
	LJMP end_i2c_int	


/****

 /$$        /$$$$$$  /$$$$$$$        /$$$$$$ /$$   /$$ /$$$$$$  /$$$$$$  /$$$$$$  /$$$$$$ 
| $$       /$$__  $$| $$__  $$      |_  $$_/| $$$ | $$|_  $$_/ /$$__  $$|_  $$_/ /$$__  $$
| $$      | $$  \__/| $$  \ $$        | $$  | $$$$| $$  | $$  | $$  \__/  | $$  | $$  \ $$
| $$      | $$      | $$  | $$        | $$  | $$ $$ $$  | $$  | $$        | $$  | $$  | $$
| $$      | $$      | $$  | $$        | $$  | $$  $$$$  | $$  | $$        | $$  | $$  | $$
| $$      | $$    $$| $$  | $$        | $$  | $$\  $$$  | $$  | $$    $$  | $$  | $$  | $$
| $$$$$$$$|  $$$$$$/| $$$$$$$/       /$$$$$$| $$ \  $$ /$$$$$$|  $$$$$$/ /$$$$$$|  $$$$$$/
|________/ \______/ |_______/       |______/|__/  \__/|______/ \______/ |______/ \______/ 
            
*/


;"biblioteca" com funções para escrever no LCD
;@author Lucas Simões

#define  LCD_RS    P2.5
#define  LCD_RW    P2.6
#define  LCD_EN    P2.7
#define  LCD_DADO  P0
#define  LCD_BUSY  P0.7 // bit mais alto do dado pode ser lido como busy flag.

/**
 MINI LCD

-**/
lcd_wait_while_busy:
	;modo leitura
	CLR LCD_RS
    SETB LCD_RW
	SETB P0.7 
	loop_busy:
		;verifica o bit de busy e da um clock
		SETB LCD_EN
		JNB P0.7, fim_busy 
		CLR LCD_EN
		JMP loop_busy
	fim_busy:
		CLR LCD_RW
	RET

;
; @A => comando a ser enviado para o lcd
;
lcd_env_instrucao:
	ACALL lcd_wait_while_busy;
	CLR  LCD_RS;
	ACALL envia_lcd;
RET;

;
; @A => dado a ser enviado para o lcd
 
lcd_env_dados:
	ACALL lcd_wait_while_busy;
	;seta lcd para receber dados
	SETB LCD_RS; 
	ACALL envia_lcd;
RET

envia_lcd:
	;envia o dado e um pulso de clock
	SETB LCD_EN;
	MOV LCD_DADO, A
	CLR LCD_EN;
	
RET

inicializar_lcd:
    MOV A, #0x30
    ACALL lcd_env_instrucao
    ACALL lcd_env_instrucao
    ACALL lcd_env_instrucao
    
    ; definições do usuário
    ; 8bits, 2 linhas, 5x8
    MOV A, #0x38 
    ACALL lcd_env_instrucao
    
    ; liga o display, mostra o cursor, não pisca.
    MOV A, #0x0D 
    ACALL lcd_env_instrucao
    
    ; Não desloca a frase, cursor vai para direita.
    MOV A, #0x06 
    ACALL lcd_env_instrucao
    
    ; Return home.
    MOV A, #0x02 
    ACALL lcd_env_instrucao
    
    ; Clear display
    MOV A, #0x01 
    ACALL lcd_env_instrucao
RET
 	
;------------------------------------------------------------
; Escreve uma string
; Parâmetros: DPTR (ponteiro para o string)
; Destroi: A, DPTR
;------------------------------------------------------------
lcd_string:
    MOV A, #0x00
    MOVC A, @A+DPTR      ; carrega o caracter em A
    JZ fim_lcd_string    ; Se for zero, acabou
    CALL lcd_env_dados        ; escreve no display
    INC DPTR             ; incrementa DPTR
    JMP lcd_string       ; e vai pro próximo
fim_lcd_string:        
    RET
	
lcd_change_to_line_1:
	MOV A, #0x80
	CALL lcd_env_instrucao;
RET

lcd_change_to_line_2:
	MOV A, #0xC0
	CALL lcd_env_instrucao
RET


; colocar o valor em @A
print_bcd_decimal:
	MOV B, A
	SWAP A
	ANL A, #0x0F;
	ADD A, #0x30
	ACALL lcd_env_dados
	
	MOV A, B
	ANL A, #0x0F
	ADD A, #0x30
	ACALL lcd_env_dados	   
RET


; Cria 1ms de atraso
; Usa R7
; a rotina usa aproximadamente 500 * 2uS(por instruçao, com um cristal de 24MHz)
loop_1_ms:
DELAY:
	MOV R7,#250D
LOOP_1:
	DJNZ R7, LOOP_1; 2 ciclos  2us
LOOP_2:
	MOV R7, #249D
	DJNZ R4, LOOP_2 ; 2 ciclos 2us
RET

; Usa R7, R6
; rotina faz um delay proporcional ao valor em R6
delay_proporcional:
	MOV A, R2
	MOV R6, A;
	MOV A, R6
	JZ  FIM_DELAY_PROPORCIONAL
LOOP_DELAY_PROPORCIONAL:
	CALL loop_1_ms;
	DJNZ R6, LOOP_DELAY_PROPORCIONAL;
FIM_DELAY_PROPORCIONAL:
RET

/**
 /$$        /$$$$$$  /$$$$$$$        /$$$$$$$$ /$$$$$$ /$$      /$$
| $$       /$$__  $$| $$__  $$      | $$_____/|_  $$_/| $$$    /$$$
| $$      | $$  \__/| $$  \ $$      | $$        | $$  | $$$$  /$$$$
| $$      | $$      | $$  | $$      | $$$$$     | $$  | $$ $$/$$ $$
| $$      | $$      | $$  | $$      | $$__/     | $$  | $$  $$$| $$
| $$      | $$    $$| $$  | $$      | $$        | $$  | $$\  $ | $$
| $$$$$$$$|  $$$$$$/| $$$$$$$/      | $$       /$$$$$$| $$ \/  | $$
|________/ \______/ |_______/       |__/      |______/|__/     |__/
	
	
*/ 






update_lcd:
	ACALL lcd_change_to_line_1;
	
	MOV A, DAT; Dia do mes
	ACALL print_bcd_decimal
	MOV A, #'-';
	ACALL lcd_env_dados;
	
	MOV A, MON;mes
	ACALL print_bcd_decimal;
	MOV A, #'-';
	ACALL lcd_env_dados;
	
	MOV A, YEA;ano
	ACALL print_bcd_decimal;
	MOV A, #' ';
	ACALL lcd_env_dados;
	ACALL lcd_change_to_line_2;

	MOV A, HOU
	ANL A, #00111111b 
	ACALL print_bcd_decimal;
	MOV A, #':';
	ACALL lcd_env_dados;
	
	MOV A, MIN
	ACALL print_bcd_decimal;
	MOV A, #':';
	ACALL lcd_env_dados;
	
	MOV A, SEC
	ACALL print_bcd_decimal;
	MOV A, #' ';
	ACALL lcd_env_dados;
	
	
	MOV A, DAY
	ADD A, #0x30
	ACALL lcd_env_dados;
	
	 
RET 

timer_0_ir:
	CPL LED3;
 
	LCALL RTC_GET_TIME
	LCALL update_lcd
RETI



receive_byte:
	JNB		RI, $	;espera receber
	CLR		RI
	MOV		A, SBUF
	RET

escreveSerial:		
	MOV	SBUF, A
	JNB	TI, $
	CLR	TI
RET


setar_relogio:
	CPL LED1
	MOV TMOD, #00100000b ; Timer 1 no modo 2
	MOV TH1, #243  ; seta timer1 para baud rate 9600 
	SETB TR1
	MOV PCON,#10000000b ;serial modo 1
	MOV SCON,#01010000b ;habilita SM1 (coloca o serial para seguir o timer1) 
	
	
	t_ini:
	ACALL receive_byte;
	ACALL escreveSerial
	t_dia_mes:
	CJNE A, #'D', t_mes
	ACALL tratar_dia_mes
	SJMP t_ini
	t_mes:
	CJNE A, #'M', t_ano
	ACALL tratar_mes
	SJMP t_ini
	t_ano:
	CJNE A, #'A', t_hora
	ACALL tratar_ano
	SJMP t_ini
	t_hora:
	CJNE A, #'h', t_minuto
	ACALL tratar_hora
	SJMP t_ini
	t_minuto:
	CJNE A, #'m', t_segundo
	ACALL tratar_minuto
	SJMP t_ini
	t_segundo:
	CJNE A, #'s', t_dia_semana
	ACALL tratar_segundo
	SJMP t_ini
	t_dia_semana:
	CJNE A, #'d', t_modo_am_24
	ACALL tratar_dia_semana
	SJMP t_ini
	t_modo_am_24:
	CJNE A, #'T', t_fim
	ACALL tratar_AM_24
	SJMP t_ini

	t_fim:
	CJNE A, #'F', t_ini
	fim_setar_relogio:
	CPL LED1
	MOV CTR, #00010000b ; SQW  
RET

tratar_AM_24:
	MOV Acc, HOU
	CPL Acc.6
	MOV HOU, Acc
RET

tratar_dia_semana:
	ACALL receive_byte;
	CLR C;
	SUBB A, #0x30
	
	MOV R4, #7d
	MOV R5, A
	ACALL VerificarValor
	MOV DAY, A
RET

tratar_dia_mes:
	ACALL receive_byte;
	CLR C;
	SUBB A, #0x30
	SWAP A;
	MOV B, A;
	
	ACALL receive_byte;
	CLR C;
	SUBB A, #0x30
	ADD A, B
	
	MOV R4, #00110001b
	MOV R5, A
	ACALL VerificarValor	
	MOV DAT, A 
RET


tratar_mes:
	ACALL receive_byte;
	CLR C;
	SUBB A, #0x30
	SWAP A;
	MOV B, A;
	
	ACALL receive_byte;
	CLR C;
	SUBB A, #0x30
	ADD A, B
	
	MOV R4, #00010010b
	MOV R5, A
	ACALL VerificarValor	
	MOV MON, A 
RET


tratar_ano:
	ACALL receive_byte;
	CLR C;
	SUBB A, #0x30
	SWAP A;
	MOV B, A;
	
	ACALL receive_byte;
	CLR C;
	SUBB A, #0x30

	ADD A, B
	MOV R4, #255d
	MOV R5, A
	ACALL VerificarValor	
	MOV YEA, A 
RET

tratar_minuto:
	ACALL receive_byte;
	CLR C;
	SUBB A, #0x30
	SWAP A;
	MOV B, A;
	
	ACALL receive_byte;
	CLR C;
	SUBB A, #0x30
	ADD A, B
	
	MOV R4, #01100000b
	MOV R5, A
	ACALL VerificarValor	
	MOV MIN, A 
RET


tratar_segundo:
	ACALL receive_byte;
	CLR C;
	SUBB A, #0x30
	SWAP A;
	MOV B, A;
	
	ACALL receive_byte;
	CLR C;
	SUBB A, #0x30
	ADD A, B

	MOV R4, #01100000b
	MOV R5, A
	ACALL VerificarValor	
	MOV SEC, A 
RET
 
 
tratar_hora:
	ACALL receive_byte;
	CLR C;
	SUBB A, #0x30
	SWAP A;
	MOV B, A;
	
	ACALL receive_byte;
	CLR C;
	SUBB A, #0x30
	ADD A, B
	
	MOV R4, #00100100b
	MOV R5, A
	ACALL VerificarValor

	MOV HOU, A 
RET


;; R4 = max value
;; R5 = value 
VerificarValor:
	CLR C;
	MOV A, R4
	SUBB A, R5
	jz fim_valido;
	JC fim_invalido;
	fim_valido:
		MOV A,#'O'
		ACALL escreveSerial
		MOV A,#'K'
		ACALL escreveSerial

		MOV A, R5
		RET
	fim_invalido:
		MOV A,#'N'
		ACALL escreveSerial

		MOV A, #0x00
		RET
RET


END
