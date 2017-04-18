ORG 0x0000
ACALL MAIN;	

ORG 0x007B
;; /****
;;; LIB LCD
#include "at89c5131.h"


/*******
* LEDs *
*******/
// Driver interno de corrente. deve ser configurado via LEDCON
#define LED1        P3.6
#define LED2        P3.7
// Transistor externo
#define LED3        P1.4
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

**/
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
/*

 /$$               /$$              /$$$$$$   /$$                                           /$$                           /$$                        /$$                          /$$                      /$$         
| $$              | $$             /$$$_  $$/$$$$                                          | $$                          | $$                       /$$/                         | $$                     | $$         
| $$       /$$$$$$| $$$$$$$       | $$$$\ $|_  $$                        /$$$$$$ /$$$$$$$ /$$$$$$   /$$$$$$ /$$$$$$  /$$$$$$$ /$$$$$$  /$$$$$$     /$$/$$$$$$$ /$$$$$$ /$$$$$$$ /$$$$$$   /$$$$$$  /$$$$$$| $$ /$$$$$$ 
| $$      |____  $| $$__  $$      | $$ $$ $$ | $$         /$$$$$$       /$$__  $| $$__  $|_  $$_/  /$$__  $|____  $$/$$__  $$|____  $$|____  $$   /$$/$$_____//$$__  $| $$__  $|_  $$_/  /$$__  $$/$$__  $| $$/$$__  $$
| $$       /$$$$$$| $$  \ $$      | $$\ $$$$ | $$        |______/      | $$$$$$$| $$  \ $$ | $$   | $$  \__//$$$$$$| $$  | $$ /$$$$$$$ /$$$$$$$  /$$| $$     | $$  \ $| $$  \ $$ | $$   | $$  \__| $$  \ $| $| $$$$$$$$
| $$      /$$__  $| $$  | $$      | $$ \ $$$ | $$                      | $$_____| $$  | $$ | $$ /$| $$     /$$__  $| $$  | $$/$$__  $$/$$__  $$ /$$/| $$     | $$  | $| $$  | $$ | $$ /$| $$     | $$  | $| $| $$_____/
| $$$$$$$|  $$$$$$| $$$$$$$/      |  $$$$$$//$$$$$$                    |  $$$$$$| $$  | $$ |  $$$$| $$    |  $$$$$$|  $$$$$$|  $$$$$$|  $$$$$$$/$$/ |  $$$$$$|  $$$$$$| $$  | $$ |  $$$$| $$     |  $$$$$$| $|  $$$$$$$
|________/\_______|_______/        \______/|______/                     \_______|__/  |__/  \___/ |__/     \_______/\_______/\_______/\_______|__/   \_______/\______/|__/  |__/  \___/ |__/      \______/|__/\_______/
 */                                                                                                                                                                                                                     

#define SENSOR_1 P2.0
#define SENSOR_2 P2.1
#define SENSOR_3 P2.2
#define SWICTH_1 P2.3
#define SWICTH_2 P2.4

#define LED_GREEN P3.0
#define LED_RED  P3.1

                                                                                                                                                                                                                       
ESTADO_SEN EQU 0x40; armazena o estado da maq. de estados dos opto-sensores
TIPO_P 	   EQU 0x41; armazena o tipo da peca encontrada
Q_GRANDES  EQU 0x42; quantidade de peças grandes
Q_MEDIAS   EQU 0x49; quantidade de peças médias
Q_PEQUENAS EQU 0x44; quantidade de peças pequenas
Q_TOTAL    EQU 0x45; quantidade de peças totais
ESTADO_GER EQU 0x46; estado geral do sistema(0-> tudo permitido, 1-> esperando voltar peça, 2-> só red pra voltar) -> determina estado dos leds	
ULTIMA_PET EQU 0x47; tipo da ultima peça que passou pela esteira
UPDATE_LCD_F EQU 0x50; atualizar LCD?
/* Tipo 1 = pequena, Tipo 2 = média, Tipo 3 = grande*/

/*
 /$$               /$$              /$$$$$$   /$$                       /$$$$$$                      /$$                                          /$$                                        
| $$              | $$             /$$$_  $$/$$$$                      |_  $$_/                     | $$                                         | $$                                        
| $$       /$$$$$$| $$$$$$$       | $$$$\ $|_  $$                        | $$  /$$$$$$/$$$$  /$$$$$$| $$ /$$$$$$ /$$$$$$/$$$$  /$$$$$$ /$$$$$$$ /$$$$$$   /$$$$$$  /$$$$$$$ /$$$$$$  /$$$$$$ 
| $$      |____  $| $$__  $$      | $$ $$ $$ | $$         /$$$$$$        | $$ | $$_  $$_  $$/$$__  $| $$/$$__  $| $$_  $$_  $$/$$__  $| $$__  $|_  $$_/  |____  $$/$$_____/|____  $$/$$__  $$
| $$       /$$$$$$| $$  \ $$      | $$\ $$$$ | $$        |______/        | $$ | $$ \ $$ \ $| $$  \ $| $| $$$$$$$| $$ \ $$ \ $| $$$$$$$| $$  \ $$ | $$     /$$$$$$| $$       /$$$$$$| $$  \ $$
| $$      /$$__  $| $$  | $$      | $$ \ $$$ | $$                        | $$ | $$ | $$ | $| $$  | $| $| $$_____| $$ | $$ | $| $$_____| $$  | $$ | $$ /$$/$$__  $| $$      /$$__  $| $$  | $$
| $$$$$$$|  $$$$$$| $$$$$$$/      |  $$$$$$//$$$$$$                     /$$$$$| $$ | $$ | $| $$$$$$$| $|  $$$$$$| $$ | $$ | $|  $$$$$$| $$  | $$ |  $$$$|  $$$$$$|  $$$$$$|  $$$$$$|  $$$$$$/
|________/\_______|_______/        \______/|______/                    |______|__/ |__/ |__| $$____/|__/\_______|__/ |__/ |__/\_______|__/  |__/  \___/  \_______/\_______/\_______/\______/ 
                                                                                           | $$                                                                                              
                                                                                           | $$                                                                                              
                                                                                           |__/                                                                                              
*/


ler_opto_sensores:
		MOV A, ESTADO_GER
		JZ GOOGO
		RET
	GOOGO:
		MOV A, ESTADO_SEN
		SUBB A, #0x01
		JZ	ESTADO_S1
		
		MOV A, ESTADO_SEN
		SUBB A, #0x02
		JZ	ESTADO_S2
		
		MOV A, ESTADO_SEN
		SUBB A, #0x03
		JZ	ESTADO_S3
		
		MOV A, ESTADO_SEN
		SUBB A, #0x04
		JZ	ESTADO_S4
		
		MOV A, ESTADO_SEN
		SUBB A, #0x05
		JZ	ESTADO_S5
		
		MOV A, ESTADO_SEN
		SUBB A, #0x06
		JZ	ESTADO_S6
		
		MOV A, ESTADO_SEN
		SUBB A, #0x07
		JZ	ESTADO_S7
	ESTADO_S1:
		JB SENSOR_1, fim_ler_sensores;
		MOV ESTADO_SEN, #0x02 ; vai pro estado S2
		
		LJMP  fim_ler_sensores;
	ESTADO_S2:
		JB SENSOR_2, fim_ler_sensores; sensor 2 não ativo -> estado s2
		JB SENSOR_1, TRANS_ESTADO_S3;
		TRANS_ESTADO_S5:	
			MOV ESTADO_SEN, #0x05
			LJMP  fim_ler_sensores;
		TRANS_ESTADO_S3:
			MOV ESTADO_SEN, #0x03
			MOV TIPO_P, #0x01;
			LJMP  fim_ler_sensores;
	
	ESTADO_S3:
		JNB SENSOR_2, fim_ler_sensores;
		JB  SENSOR_3, fim_ler_sensores;
		MOV ESTADO_SEN, #0x04
		LJMP  fim_ler_sensores;
	ESTADO_S4:
		JNB SENSOR_3, fim_ler_sensores;
		ACALL tratar_nova_peca;
		LJMP  fim_ler_sensores;
	ESTADO_S5:
		JB SENSOR_1, TRANSIC_ESTADO_S5_to_S3
		JB SENSOR_3, fim_ler_sensores;
		
		MOV ESTADO_SEN, #0x06
		MOV TIPO_P, #0x03
		LJMP  fim_ler_sensores;
		TRANSIC_ESTADO_S5_to_S3:
			MOV ESTADO_SEN, #0x03	
			MOV TIPO_P, #0x02
			LJMP  fim_ler_sensores;
	ESTADO_S6:
		JNB SENSOR_1, fim_ler_sensores;
		MOV ESTADO_SEN, #0x07
		LJMP  fim_ler_sensores;
	ESTADO_S7:
		JNB SENSOR_2, fim_ler_sensores;
		MOV ESTADO_SEN, #0x04
		
		LJMP  fim_ler_sensores;
fim_ler_sensores:
RET

tratar_nova_peca:
	  MOV ESTADO_SEN, #0x00
 
	  MOV A, TIPO_P 

	  SUBB A, #0x03
	  JZ INC_PECA_GRANDE;
	  
	  CLR C
	  MOV A, TIPO_P
	  SUBB A, #0x02
	  JZ INC_PECA_MEDIA;
	  
	  CLR C
	  MOV A, TIPO_P
	  SUBB A, #0x01
	  JZ INC_PECA_PEQUENA;
	  RET
		 			
		INC_PECA_GRANDE:
			INC Q_GRANDES
			MOV R3, #0x03
			SJMP FIM_TRATAR_NOVA_PECA;
		INC_PECA_MEDIA:
			INC Q_MEDIAS
			MOV R3, #0x02
			SJMP FIM_TRATAR_NOVA_PECA;
		INC_PECA_PEQUENA:
			INC Q_PEQUENAS
			MOV R3, #0x01
			SJMP FIM_TRATAR_NOVA_PECA;
	FIM_TRATAR_NOVA_PECA:
		MOV UPDATE_LCD_F, #0x01
		INC Q_TOTAL;
		MOV A, TIPO_P
		MOV ULTIMA_PET, A
		MOV TIPO_P, #0x00

		MOV A, Q_TOTAL;
		SUBB A, #0x09
		JZ LIMITE_PECAS_ATINGIDO;
		RET
LIMITE_PECAS_ATINGIDO:
	MOV ESTADO_GER, #0x01
RET



inicializar_sistema:
	ACALL inicializar_lcd;
	
	MOV LEDCON, #0xA0
	
	MOV UPDATE_LCD_F, #0x01
	MOV ESTADO_SEN, #0x01
	MOV TIPO_P, #0x00
	MOV Q_GRANDES, #0x00
	MOV Q_MEDIAS, #0x00
	MOV R3, #0x00
	MOV Q_PEQUENAS, #0x00
	MOV Q_TOTAL, #0x00
	MOV ESTADO_GER, #0x00 
	MOV ULTIMA_PET, #0x00
RET

ler_switchs:
	SETB SWICTH_2
	JNB  SWICTH_2, SWITCH_1_CHK
	ACALL inicializar_sistema    
	RET
    SWITCH_1_CHK:
	SETB SWICTH_1
	JNB  SWICTH_1, fim_ler_switchs
	MOV ESTADO_GER, #0x02
			  MOV A, R3
			  JZ fim_ler_switchs
			  CLR C
			  SUBB A, #0x03
			  JZ DEC_PECA_GRANDE;
			  
			  CLR C
			  MOV A, R3
			  SUBB A, #0x02
			  JZ DEC_PECA_MEDIA;
			  
			
			  CLR C
			  MOV A, R3
			  SUBB A, #0x01
			  JZ DEC_PECA_PEQUENA;
			  
			  SJMP FIM_TRATAR_REMOV_PECA
							
				DEC_PECA_GRANDE:
					DEC Q_GRANDES
					SJMP FIM_TRATAR_REMOV_PECA;
				DEC_PECA_MEDIA:
					DEC Q_MEDIAS
					SJMP FIM_TRATAR_REMOV_PECA;
				DEC_PECA_PEQUENA:
					DEC Q_PEQUENAS
					SJMP FIM_TRATAR_REMOV_PECA;
			FIM_TRATAR_REMOV_PECA:
				DEC Q_TOTAL;
				MOV UPDATE_LCD_F, #0x01
				MOV ULTIMA_PET, #0x00
				MOV R3, #0x00
	fim_ler_switchs:
	RET

saida_leds:
    MOV A, ESTADO_GER
	JNZ VERMELHO;
	VERDE:
		CLR  LED_GREEN;
		SETB  LED_RED;
		RET
	VERMELHO:
		SETB LED_GREEN;
		CLR  LED_RED;
		RET

update_lcd: 
    ; Clear display
	MOV A, UPDATE_LCD_F
	JZ fim_update_lcd
	MOV UPDATE_LCD_F, #0x00
	
	ACALL lcd_change_to_line_1;
	
	MOV DPTR, #frase_linha_1_p1 
    CALL lcd_string
	
	MOV A, Q_PEQUENAS
	ADD A, #0x30;;
	ACALL lcd_env_dados;
	
	MOV DPTR, #frase_linha_1_p2 
    CALL lcd_string
	
	MOV A, Q_MEDIAS;
	ADD A, #0x30;
	ACALL lcd_env_dados;
	
	MOV DPTR, #frase_linha_1_p3 
    CALL lcd_string
	
	MOV A, Q_GRANDES;
	ADD A, #0x30;
	ACALL lcd_env_dados;
	
	ACALL lcd_change_to_line_2
	
	MOV DPTR, #frase_linha_2
    CALL lcd_string
	
	MOV A, #0x30;
	ADD A, Q_TOTAL;
	ACALL lcd_env_dados;

fim_update_lcd:
	
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
; rotina faz um delay proporcional ao valor em P1
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


SHOW_STATE_OPTO:
		MOV A, ESTADO_SEN
		SUBB A, #0x01
		JZ	SHOW_ESTADO_S1
		
		MOV A, ESTADO_SEN
		SUBB A, #0x02
		JZ	SHOW_ESTADO_S2
		
		MOV A, ESTADO_SEN
		SUBB A, #0x03
		JZ	SHOW_ESTADO_S3
		
		MOV A, ESTADO_SEN
		SUBB A, #0x04
		JZ	SHOW_ESTADO_S4
		
		MOV A, ESTADO_SEN
		SUBB A, #0x05
		JZ	SHOW_ESTADO_S5
		
		MOV A, ESTADO_SEN
		SUBB A, #0x06
		JZ	SHOW_ESTADO_S6
		
		MOV A, ESTADO_SEN
		SUBB A, #0x07
		JZ	SHOW_ESTADO_S7
		
		SHOW_ESTADO_S1:
			SETB LED1;
			SETB LED2;
			CLR LED3;
			RET;
		SHOW_ESTADO_S2:
			SETB LED1;
			CLR LED2;
			SETB LED3;
			RET;
		SHOW_ESTADO_S3:
			SETB LED1;
			CLR LED2;
			CLR LED3;
			RET;
		SHOW_ESTADO_S4:
			CLR LED1;
			SETB LED2;
			SETB LED3;
			RET;
		SHOW_ESTADO_S5:
			CLR LED1;
			SETB LED2;
			CLR LED3;
			RET;
		SHOW_ESTADO_S6:
			CLR LED1;
			CLR LED2;
			SETB LED3;
			RET;
		SHOW_ESTADO_S7:
			CLR LED1;
			CLR LED2;
			CLR LED3;
			RET;
			 

MAIN:	
	
    ACALL inicializar_sistema;
	
loop:	
	ACALL SHOW_STATE_OPTO
	
	ACALL ler_switchs;
	ACALL ler_opto_sensores
	ACALL saida_leds;
	ACALL update_lcd;	
	MOV R2, #0xFF
	ACALL delay_proporcional
	SJMP loop; 

;============================================================
; Constantes definidas na memória de código.
;============================================================
frase_linha_1_p1: 
DB 'P=0'
DB 0x00
frase_linha_1_p2: 
DB ' M=0'
DB 0x00
frase_linha_1_p3: 
DB ' G=0'
DB 0x00
frase_linha_2: 
DB '   TOTAL=0'
DB 0x00
END
	

 