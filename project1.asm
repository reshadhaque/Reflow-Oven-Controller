$NOLIST
$MODN76E003
$include(LCD_4bit.inc)
$LIST

;  N76E003 pinout:
;                               -------
;       PWM2/IC6/T0/AIN4/P0.5 -|1    20|- P0.4/AIN5/STADC/PWM3/IC3
;               TXD/AIN3/P0.6 -|2    19|- P0.3/PWM5/IC5/AIN6
;               RXD/AIN2/P0.7 -|3    18|- P0.2/ICPCK/OCDCK/RXD_1/[SCL]
;                    RST/P2.0 -|4    17|- P0.1/PWM4/IC4/MISO
;        INT0/OSCIN/AIN1/P3.0 -|5    16|- P0.0/PWM3/IC3/MOSI/T1
;              INT1/AIN0/P1.7 -|6    15|- P1.0/PWM2/IC2/SPCLK
;                         GND -|7    14|- P1.1/PWM1/IC1/AIN7/CLO
;[SDA]/TXD_1/ICPDA/OCDDA/P1.6 -|8    13|- P1.2/PWM0/IC0
;                         VDD -|9    12|- P1.3/SCL/[STADC]
;            PWM5/IC7/SS/P1.5 -|10   11|- P1.4/SDA/FB/PWM1
;                               -------
;

ABORT_BUTTON EQU (decide which pin later)
PB6 EQU (decide which pin later)

CLK EQU 16600000 ; Microcontroller system oscillator frequency in Hz
TIMER2_RATE EQU 100 ; 100Hz or 10ms
TIMER2_RELOAD EQU (65536-(CLK/(16*TIMER2_RATE)))

; Output
PWM_OUT EQU P1.0 ; Logic 1=oven on

BSEG
s_flag: dbit 1 ; set to 1 every time a second has passed

DSEG ; Before the state machine!
pwm_counter: ds 1 ; Free running counter 0, 1, 2, ..., 100, 0
pwm: ds 1 ; pwm percentage
seconds: ds 1 ; a seconds counter attached to Timer 2 ISR
FSM1_state: ds 1
temp_soak: ds 1
time_soak: ds 1
temp_state3: ds 1
temp_refl: ds 1
time_refl: ds 1
temp_cooling: ds 1
time_cooling: ds 1

CSEG
; Reset vector
org 0x0000
ljmp main

; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR
	
; These 'equ' must match the hardware wiring
LCD_RS equ P1.3
LCD_E equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3

Init_All:
	; Configure all the pins for biderectional I/O
	mov P3M1, #0x00
	mov P3M2, #0x00
	mov P1M1, #0x00
	mov P1M2, #0x00
	mov P0M1, #0x00
	mov P0M2, #0x00
	; Initialize timer 2 for periodic interrupts
	mov T2CON, #0 ; Stop timer/counter. Autoreload mode.
	mov TH2, #high(TIMER2_RELOAD)
	mov TL2, #low(TIMER2_RELOAD)
	; Set the reload value
	mov T2MOD, #0b1010_0000 ; Enable timer 2 autoreload, and clock divider is 16
	mov RCMP2H, #high(TIMER2_RELOAD)
	mov RCMP2L, #low(TIMER2_RELOAD)
	; Init the free running 10 ms counter to zero
	mov pwm_counter, #0
	; Enable the timer and interrupts
	orl EIE, #0x80 ; Enable timer 2 interrupt ET2=1
	setb TR2 ; Enable timer 2
	setb EA ; Enable global interrupts
	ret

;---------------------------------;
; ISR for timer 2 ;
;---------------------------------;
Timer2_ISR:
	clr TF2 ; Timer 2 doesn't clear TF2 automatically. Do it in the ISR. It is bit addressable.
	push psw
	push acc
	inc pwm_counter
	clr c
	mov a, pwm
	subb a, pwm_counter ; If pwm_counter <= pwm then c=1
	cpl c
	mov PWM_OUT, c
	mov a, pwm_counter
	cjne a, #100, Timer2_ISR_done
	mov pwm_counter, #0
	inc seconds ; It is super easy to keep a seconds count here
	setb s_flag
Timer2_ISR_done:
	pop acc
	pop psw
	reti

FSM1:
	jb ABORT_BUTTON, FSM1_state0
	mov FSM1_state, #0
	mov a, FSM1_state
	
FSM1_state0:
	cjne a, #0, FSM1_state1 		;if we arent in state 0, jump to state 1
	mov pwm, #0 ;pusle with modulation, 	;0% power
	jb PB6, loop ;if startbutton is not pressed, jump to loop (so we can stay in state 0)
	jnb PB6, $ ; Wait for key release	;if startbutton is pressed, wait till it is released and start the FSM
	mov FSM1_state, #1
	
FSM1_state1:
	cjne a, #1, FSM1_state2
	mov pwm, #100 ;set power to 100%
	mov sec, #0 ;set seconds to 0
	mov a, temp_soak
	clr c
	subb a, temp ;check if temperature has been exceeded threshold
	jnc loop
	mov FSM1_state, #2
	
FSM1_state2:
	cjne a, #2, FSM1_state3
	mov pwm, #20 ;set power to 20%
	mov a, time_soak
	clr c
	subb a, sec ;check if time has been exceeded threshold
	jnc loop
	mov FSM1_state, #3
	
FSM1_state3:
	cjne a, #3, FSM1_state4
	mov pwm, #100 ;set power to 100%
	mov sec, #0 ;set seconds to 0
	mov a, temp_3
	clr c
	subb a, temp ;check if temperature has been exceeded threshold
	jnc loop
	mov FSM1_state, #4

FSM1_state4:
	cjne a, #4, FSM1_state5
	mov pwm, #20 ;set power to 20%
	mov a, reflow_time
	clr c
	subb a, sec ;check if time has been exceeded threshold
	jnc loop
	mov FSM1_state, #5

FSM1_state5:
	cjne a, #5, FSM1_state0
	mov pwm, #0 ;set power to 0%
	mov a, cooling_temp
	clr c
	subb a, temp ;check if temperature is below threshold
	jc loop
	mov FSM1_state, #0

loop:
	mov a, FSM1_state
	lcall FSM1
