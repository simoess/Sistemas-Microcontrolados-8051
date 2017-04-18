#include <at89c5131.h> 
;laboratório 02
;Onda PWM gerada com o PCA

;P3.4 -> colocar aqui o sensor opto do motor
;P1.3 -> sinal PWM
BUG_FIX  EQU 0x53 ; armazena a contagem

CONTAGEM_LOW  EQU 0x50 ; armazena a contagem
CONTAGEM_HIGH EQU 0x51 ; armazena a contagem
TIMER_COUNTER EQU 0x52	
RPM_HIGH EQU 0x48;
RPM_LOW  EQU 0x49;
ESTADO_CHAVES EQU 0x40; estado da máquina que aumenta/diminui o PWM
DUTY_ATUAL EQU 0x41 ; 3..10, valor do duty cycle atual

;armazena os digitos do PWM
DIGITO_5 EQU 0x42
DIGITO_4 EQU 0x43
DIGITO_3 EQU 0x44
DIGITO_2 EQU 0x45
DIGITO_1 EQU 0x46
	
UPDATE_LX EQU 0x25


#define SWICTH_1 P2.0
#define SWICTH_2 P2.1
// Driver interno de corrente. deve ser configurado via LEDCON
#define LED1        P3.6
#define LED2        P3.7
// Transistor externo
#define LED3        P1.4
 


ORG 0x000
	jmp main
ORG 0x000B ; counter 0 interruption
	jmp timer_0_ir 
	RETI
ORG 0x001B
	jmp timer_1_ir
	RETI
org 02Bh
	CPL P1.2
	RETI
ORG 0x1000
timer_0_ir:
	PUSH ACC
	MOV A, CONTAGEM_LOW;
	ADD A, #0x01
	MOV CONTAGEM_LOW, A
	MOV A, CONTAGEM_HIGH
	ADDC A, #0x00
	CLR TF0
	CPL LED2
	POP ACC
	RETI
timer_1_ir:
	PUSH Acc
	INC TIMER_COUNTER;
	MOV A, TIMER_COUNTER
	CJNE A, #40d, fim_timer_1_ir
	ACALL Calcula_RPM;
	ACALL inicia_timers;
fim_timer_1_ir:	
	POP Acc
	RETI
;ORG 2000h	
inicia_PWM:
 
	MOV CMOD, #00000111b ; Configura a fonte de clock do PCA
	MOV CCAPM0, #01000010b   ; Configura o registrador 0 em modo PWM
	//MOV CCAP0H, #76d   ; Configura o Duty Cycle
	//MOV CCAP0L, #76d   ; Configura o Duty Cycle
	MOV CCON, #0x40    	 ; inicia o pca
RET


;inicia o timer 0 e o timer 1
inicia_timers:
	;timer 0 em modo auto-reload, contando eventos externos em P3.4
	;timer 1 em modo 16bits, contando a ciclo de clock
	CLR EA
	;GATE1 0  
	;CT1   0
	;M1.1  0  -timer 1 no modo 16-bits
	;M0.1  1- timer 0 modo contador 8-bits auto-reload 
	;GATE0 0
	;CT0   1 - timer 0- é contador
	;M1.0  1 - timer 1 no modo 16-bits
	;M0.0  0 - timer 0 modo contador 8-bits auto-reload
	MOV TMOD, #00010110b
	
	MOV CONTAGEM_LOW, #0x00
	MOV CONTAGEM_HIGH, #0x00
	MOV TIMER_COUNTER, #0x00


	
;	SETB CT0
		;conta de 8 em 8
	MOV TH0, #247d ; 255 - 8
	MOV TL0, #247d;   255- 8[n ranhuras]
	
	MOV TH1, #HIGH(65536 - 50000) ;25ms
	MOV TL1, #LOW (65536 - 50000) ;25ms
	
//	SETB TF0
	//SETB TF1
	SETB TR1; ativa timer 1
	SETB ET1 ;ativa interrupção do timer 1
	SETB TR0; ativa timer 0
	SETB ET0 ;ativa interrupção do timer 0	
	
	
	ANL T2MOD,#0FCh; /* T2OE=0;DCEN=1; */
	ORL T2MOD,#01h;
	 CLR EXF2; /* reset flag */
	 CLR TCLK;
	 CLR RCLK; /* disable baud rate generator */
	CLR EXEN2; /* ignore events on T2EX */
	 MOV TH2,#0xFF; /* Init msb_value */
	 MOV TL2,#0xF0 /* Init lsb_value */
	 MOV RCAP2H,#0xFE;/* reload msb_value */
	 MOV RCAP2L,#0xF0;/* reload lsb_value */
	 CLR C_T2; /* timer mode */
	 
	SETB ET2
	SETB TR2
	
	SETB EA; ativa interrupções
RET


;; multiplica a contagem por 6000 para dar o valor em RPM
;destroi R3 e R2
Calcula_RPM:
	CLR EA; desativa interrupções durante o cálculo
 
	PUSH B
	MOV A, #60d
	MOV B, CONTAGEM_LOW
	MUL AB
	MOV R2, B ; high
	MOV R3, A ; low
	MOV A, #60d
	MOV B, CONTAGEM_HIGH
	MUL AB
	
	ADD A, R3
	MOV R3, A ;low finish
	MOV A, B
	ADDC A, R2
	MOV R2, A  ; high finish
	POP B
	MOV RPM_HIGH, R2
	MOV RPM_LOW,  R3;
//	bug_fix:
;	MOV RPM_HIGH, CONTAGEM_HIGH
	;MOV RPM_LOW,  CONTAGEM_LOW
	;MOV CONTAGEM, #0x00 ;limpa a contagem
	SETB UPDATE_LX

	RET;

frase_linha_1_30: 
DB 'V. Ajust=1134: '
DB 0x00
frase_linha_1_40: 
DB 'V. Ajust=1512: '
DB 0x00
frase_linha_1_50: 
DB 'V. Ajust=1890: '
DB 0x00
frase_linha_1_60: 
DB 'V. Ajust=2268: '
DB 0x00
frase_linha_1_70: 
DB 'V. Ajust=2646: '
DB 0x00
frase_linha_1_80: 
DB 'V. Ajust=3024: '
DB 0x00	
frase_linha_1_90: 
DB 'V. Ajust=3402: '
DB 0x00
frase_linha_1_100: 
DB 'V. Ajust=3780: '
DB 0x00	
	
frase_linha_2: 
DB 'V. Atual= '
DB 0x00
	
	

update_lcd:
	ACALL lcd_change_to_line_1;
	
		MOV A, DUTY_ATUAL
		CJNE A, #0x0A, COMP_90_lcd
		MOV DPTR, #frase_linha_1_100 
		JMP l_1_update_lcd;
	COMP_90_lcd:
		CJNE A, #0x09, COMP_80_lcd 
		MOV DPTR, #frase_linha_1_90 
		JMP l_1_update_lcd;
	COMP_80_lcd:
		CJNE A, #0x08, COMP_70_lcd 
		MOV DPTR, #frase_linha_1_80
		JMP l_1_update_lcd;
	COMP_70_lcd:
		CJNE A, #0x07, COMP_60_lcd
		MOV DPTR, #frase_linha_1_70 
		JMP l_1_update_lcd;
	COMP_60_lcd:
		CJNE A, #0x06, COMP_50_lcd
		MOV DPTR, #frase_linha_1_60 
		JMP l_1_update_lcd;
	COMP_50_lcd:
		CJNE A, #0x05, COMP_40_lcd
		MOV DPTR, #frase_linha_1_50 
		JMP l_1_update_lcd;
	COMP_40_lcd:
		CJNE A, #0x04, COMP_30_lcd 
		MOV DPTR, #frase_linha_1_40
		JMP l_1_update_lcd;
	COMP_30_lcd:
 		MOV DPTR, #frase_linha_1_30 
		JMP l_1_update_lcd;
	
	l_1_update_lcd:
    CALL lcd_string
	MOV A, DUTY_ATUAL
	ADD A, #0x30
	CALL lcd_env_dados
	
	ACALL lcd_change_to_line_2;
	MOV DPTR, #frase_linha_2
	ACALL lcd_string;
	
	MOV A, DIGITO_5;
	ADD A, #0x30
	ACALL lcd_env_dados;
	
	MOV A, DIGITO_4;
	ADD A, #0x30
	ACALL lcd_env_dados;
	
	MOV A, DIGITO_3;
	ADD A, #0x30
	ACALL lcd_env_dados;
	
	MOV A, DIGITO_2;
	ADD A, #0x30
	ACALL lcd_env_dados;
	
	MOV A, DIGITO_1;
	ADD A, #0x30
	ACALL lcd_env_dados;
	
	 
RET

read_keys:
	SETB SWICTH_1
	JNB  SWICTH_1, SWITCH_2_CHK
	MOV ESTADO_CHAVES, #0x01 
	SJMP FIM_READ_KEYS;
	
	SWITCH_2_CHK:
	SETB SWICTH_2
	JNB  SWICTH_2, CHK_CHANGE_STATE
	MOV ESTADO_CHAVES, #0x02 
	SJMP FIM_READ_KEYS;
CHK_CHANGE_STATE: ;nenhuma tecla pressionada, checa o estado atual, para inc ou dec duty_cycle
	MOV A, ESTADO_CHAVES
	CLR C
	SUBB A, #0x01
	JZ	INC_DUTY_CYCLE
	
	MOV A, ESTADO_CHAVES
	CLR C
	SUBB A, #0x02
	JZ	DEC_DUTY_CYCLE
	
	SJMP FIM_READ_KEYS
	INC_DUTY_CYCLE:
		INC DUTY_ATUAL
		MOV A, DUTY_ATUAL
		CJNE A, #0x0B, CONT_INC_DUTY
		MOV DUTY_ATUAL, #0x0A
		CONT_INC_DUTY:
		MOV ESTADO_CHAVES, #0x00
		ACALL config_duty_cycle
		SJMP FIM_READ_KEYS;
	DEC_DUTY_CYCLE:
		MOV A, DUTY_ATUAL
		DEC DUTY_ATUAL
		MOV A, DUTY_ATUAL
		CJNE A, #0x02, CONT_DEC_DUTY
		INC DUTY_ATUAL
		CONT_DEC_DUTY:
		ACALL config_duty_cycle
		MOV ESTADO_CHAVES, #0x00
		SJMP FIM_READ_KEYS;
	
FIM_READ_KEYS:
	RET
	 

main:
	MOV LEDCON, #0xA0
	MOV DUTY_ATUAL, #0x03
	CLR UPDATE_LX
    ACALL inicializar_lcd;
	ACALL update_lcd;
	ACALL config_duty_cycle
 	ACALL inicia_PWM;
	ACALL inicia_timers; 
	MOV ESTADO_CHAVES, #0x00
	
	loop: 
		ACALL read_keys;

		JNB UPDATE_LX, loop;
		
		CLR UPDATE_LX
		CPL LED2
		CLR EA; primeiro manda o valor pro LCD, depois continua a contar
		ACALL binary_to_decimal
	 	ACALL update_lcd;
		ACALL inicia_timers
		  
	 
		SJMP loop;
	
	
	
	
; Configura de acordo com o valor em R7, de 3 à 10
;poderia fazer com menas instruções, mas não afetaria o desempenho geral do sistema
;e tem memória sobrando
config_duty_cycle:
		PUSH Acc
		ANL CCON, #10111111b    	 ; desativa o pca

		MOV A, DUTY_ATUAL
		CJNE A, #0x0A, COMP_9
		MOV CCAP0H,  #1d
		JMP CHANGE_REG_PCA;
	COMP_9:
		MOV A, DUTY_ATUAL
		CJNE A, #0x09, COMP_8 
		MOV CCAP0H,  #25d
		JMP CHANGE_REG_PCA;
	COMP_8:
		MOV A, DUTY_ATUAL
		CJNE A, #0x08, COMP_7 
		MOV CCAP0H,  #51d
		JMP CHANGE_REG_PCA;
	COMP_7:
		MOV A, DUTY_ATUAL
		CJNE A, #0x07, COMP_6
		MOV CCAP0H,  #76d
		JMP CHANGE_REG_PCA;
	COMP_6:
		MOV A, DUTY_ATUAL
		CJNE A, #0x06, COMP_5
		MOV CCAP0H,  #102d
		JMP CHANGE_REG_PCA;
	COMP_5:
		MOV A, DUTY_ATUAL
		CJNE A, #0x05, COMP_4
		MOV CCAP0H,  #127d
		JMP CHANGE_REG_PCA;
	COMP_4:
		MOV A, DUTY_ATUAL
		CJNE A, #0x04, COMP_3 
		MOV CCAP0H,   #153d
		JMP CHANGE_REG_PCA;
	COMP_3:
		MOV A, DUTY_ATUAL
		CJNE A, #0x03, COMP_X 
		MOV CCAP0H,  #178d
		JMP CHANGE_REG_PCA;
	COMP_X:
		MOV A, DUTY_ATUAL
		MOV CCAP0H,  #255d
		JMP CHANGE_REG_PCA;
CHANGE_REG_PCA:
	CPL LED1
	POP Acc
	
	MOV CCON, #0x40; ativa o pca

	RET	



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

binary_to_decimal:
	MOV DIGITO_5, #00h
	MOV DIGITO_4, #00h
	MOV DIGITO_3, #00h
	MOV DIGITO_2, #00h
	MOV DIGITO_1, #00h
	
	MOV B, #0x0A
	MOV A, RPM_LOW
	DIV AB
	MOV DIGITO_1, B
	
	MOV B, #0x0A
	DIV AB
	MOV DIGITO_2, B
	MOV DIGITO_3, A
	
	MOV A, RPM_HIGH
	CJNE A, #0x00, high_parte
	RET ; terminou conversão
high_parte:
	MOV A, #0x06
	ADD A, DIGITO_1
	MOV B, #0x0A
	DIV AB
	MOV DIGITO_1, B
	
	ADD A, 0x05
	ADD A, DIGITO_2
	MOV B, #0x0A
	DIV AB
	MOV DIGITO_2, B
	
	ADD A, #0x02
	ADD A, DIGITO_3
	MOV B, #0x0A
	DIV AB
	MOV DIGITO_3, B
	
	MOV R0, DIGITO_4
	CJNE R0, #0x00, INC_DIGITO_4
	SJMP high_comp
INC_DIGITO_4:
	ADD A, DIGITO_4
high_comp:
	MOV DIGITO_4, A
	DJNZ RPM_HIGH, high_parte
	
	MOV B, #0x0A
	MOV A, DIGITO_4
	DIV AB
	MOV DIGITO_4, B
	MOV DIGITO_5, A
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
END