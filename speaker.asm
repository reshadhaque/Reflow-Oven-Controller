
NOTE_C EQU 262   ; Frequency for note C

Play_Note:
	clr TR0
    mov TH0, #high(NOTE_C)
    mov TL0, #low(NOTE_C)
    setb SOUND_OUT  ; Turn on the sound output
	cpl TR0
    Wait_Milli_Seconds(#200) ; Note duration
    clr SOUND_OUT  ; Turn off the sound output
    ;Wait_Milli_Seconds(#200)
    ret
