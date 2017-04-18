/**
;  Lucas Simões
;	A utilização da interface SPI foi baseada em um exemplo de aplicação 
;	localizado em: http://www.atmel.com/images/doc4348.pdf
;*/
#include <at89c5131.h> 
transmit_completed BIT 20H.1; software flag
serial_data DATA 08H
data_save DATA 09H
high_byte DATA 0AH
low_byte DATA 0BH
serial_received DATA 0CH
amost_num DATA 0DH	
#define SPI_SS                P1.1
#define SPI_MISO        P1.5
#define SPI_SCK                P1.6
#define SPI_MOSI        P1.7
#define LED1        P3.6
#define LED2        P3.7
// Transistor externo
#define LED3        P1.4
org 000h
ljmp main

org 000Bh
ljmp it_timer0

org 4Bh
ljmp it_SPI
 
org 0100h

main:
	MOV amost_num, #0x00
	MOV serial_received, #0x00
	ACALL init_spi_adc;
	ACALL init_timers;
	SETB EA;                         /* enable interrupts */

	ACALL configurarAmostragem;	
	
		
loop:                            
	JNB	RI, loop_cont; testa pra ver se recebeu algum caractere da serial
	CPL LED1
	CLR RI
	MOV serial_received, SBUF  
	ACALL configurarAmostragem ; se recebeu caractere, muda o TH0 e TL0
	loop_cont:
	JNB TF0, loop
	
	MOV TH0,  high_byte;#HIGH(65536d - 100d)
	MOV TL0, low_byte;#LOW(65536d- 100d)
	CLR TF0
	ACALL le_adc
	ACALL escreveSerial
	 
LJMP loop
 


init_timers:
	mov high_byte, #HIGH(65536d - 100d)
	mov low_byte,  #LOW(65536d - 100d)
	MOV LEDCON, #0xA0
	MOV TH0,  HIGH_BYTE;#HIGH(65536d - 100d)
	MOV TL0, LOW_BYTE;#LOW(65536d- 100d)
	CLR TF0			; overflow flag
	CLR    ET0 ; ativa interrupção do timer 0

	MOV     TMOD,#21h                 
	MOV     TH1,#0F3h                    
	MOV     PCON,#80h ; 				 
	MOV     SCON,#50h             
	SETB    TR1
	SETB    TR0

	SETB LED1
	SETB LED2
	SETB LED3
RET

init_spi_adc:
	ORL SPCON,#10h;                  ; Master mode  
	SETB SPI_SS
	ORL SPCON,#80h;                  ; Fclk Periph/32  
	ORL SPCON,#00001000b;            ; CPOL=1 
	ORL SPCON,#04h;                  ; CPHA=1 
	ORL SPCON, #00100000b
	ORL IEN1,#04h;                   ; ativa interrupção SPI
	
	ORL SPCON,#40h;                  ; run spi */
	CLR transmit_completed;          ; limpa a flag de transferencia*/


RET


configurarAmostragem:
	;ACALL receive_byte
 	MOV A, serial_received
	 
	CLR TR0			; stop timer 0
 	AMOSTR_01:
		CJNE A, #'0', AMOSTR_02;	    
		mov high_byte, #HIGH(65536d - 10d)
		mov low_byte,  #LOW(65536d - 10d)
		SJMP FIM_CHANGE_AMOST;
	AMOSTR_02:
		CJNE A, #'1', AMOSTR_03;	    
		mov high_byte, #HIGH(65536d - 2000d)
		mov low_byte,  #LOW(65536d - 2000d)
		SJMP FIM_CHANGE_AMOST;
	AMOSTR_03:
		CJNE A, #'2', AMOSTR_04;  
		mov high_byte, #HIGH(65536d - 10000d)
		mov low_byte,  #LOW(65536d - 10000d)
		SJMP FIM_CHANGE_AMOST;
	AMOSTR_04:
		CJNE A, #'3', AMOSTR_05;	 
		mov high_byte, #HIGH(65536d - 20000d)
		mov low_byte,  #LOW(65536d - 20000d)
		SJMP FIM_CHANGE_AMOST;		 
	AMOSTR_05:	 
		CJNE A, #'4', AMOSTR_06;	 
		mov high_byte, #HIGH(65536d - 30000d)
		mov low_byte,  #LOW(65536d - 30000d)
		SJMP FIM_CHANGE_AMOST;		 
	AMOSTR_06:
	 	CJNE A, #'5' , AMOSTR_07;	 
		mov high_byte, #HIGH(65536d - 40000d)
		mov low_byte,  #LOW(65536d - 40000d)
		SJMP FIM_CHANGE_AMOST;		 
	AMOSTR_07: 
		CJNE A, #'7', AMOSTR_08;	 
		mov high_byte, #HIGH(65536d - 50000d)
		mov low_byte,  #LOW(65536d - 50000d)
		SJMP FIM_CHANGE_AMOST;		 
	AMOSTR_08:
		mov high_byte, #HIGH(65536d - 60000d)
		mov low_byte,  #LOW(65536d - 60000d)
	
	FIM_CHANGE_AMOST:				 
		CLR TF0			; overflow flag 
		SETB TR0; ; inicializa o timer 0 de novo
		
	RET;

RET



le_adc:
   CLR SPI_SS
   MOV SPDAT, #0x0E;       ; canal 1, modo single
   JNB transmit_completed,$;      
   CLR transmit_completed;          

   MOV SPDAT,#0x00;               ;;envia um valor dummy para gerar sinal de clock
   JNB transmit_completed,$;      
   CLR transmit_completed;        
   MOV data_save,serial_data;    ; o dado lido é armazenado em data_save  
	SETB SPI_SS
RET

;/**
; * FUNCTION_PURPOSE:interrupt
; * FUNCTION_INPUTS: void
; * FUNCTION_OUTPUTS: transmit_complete is software transfert flag
; */
it_SPI:;                         /* interrupt address is 0x004B */
	MOV R7,SPSTA;
	MOV ACC,R7
	JNB ACC.7,break1;case 0x80:
		MOV serial_data,SPDAT;       /* read receive data */
		SETB transmit_completed;     /* set software flag */
	break1:
	JNB ACC.4,break2;case 0x10:
	;         /* put here for mode fault tasking */	
	break2:;
	JNB ACC.6,break3;case 0x40:
	;         /* put here for overrun tasking */	
	break3:;
RETI


it_timer0:
	
 RETI


escreveSerial:		
	MOV	SBUF, data_save
	JNB	TI, $
	CLR	TI
	RET
end
