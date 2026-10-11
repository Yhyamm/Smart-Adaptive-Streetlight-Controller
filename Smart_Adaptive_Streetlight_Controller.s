; Smart Street_light Project
    
    AREA STREET_LIGHT, CODE, READONLY
	export SystemInit
SystemInit

    EXPORT __main
        
    ; --- 1. Initializing Registers ---
FIO2DIR  EQU 0x2009C040
FIO2SET  EQU 0x2009C058
FIO2CLR  EQU 0x2009C05C
        
PCONP    EQU 0x400FC0C4
PCLKSEL0 EQU 0x400FC1A8
PINSEL3  EQU 0x4002C00C
AD0CR    EQU 0x40034000
AD0DR4   EQU 0x40034020    ; NEW: Data Register for Channel 4 (AD0.4)
        
THRESHOLD EQU 0x0800       ; NEW: Midpoint threshold (2048 out of 4095)
		
__main

    ; --- 2. LED Configuration ---
    LDR R0, =FIO2DIR
    LDR R1, [R0]
    ORR R2, R1, #0x3C          ; Set bits 2, 3, 4, 5
    STR R2, [R0]
    
    ; Switching LEDs ON initially (just to test they work)
    LDR R0, =FIO2SET                
    MOV R1, #0x3C                  
    STR R1, [R0]
     
    ; Switching LEDs OFF 
    LDR R0, =FIO2CLR                
    MOV R1, #0x3C
    STR R1, [R0]
    
    ; --- 3. ADC Configuration ---
    ; 1. Enable Power in PCONP
    LDR R0, =PCONP                
    LDR R1, [R0]
    ORR R2, R1, #0x1000
    STR R2, [R0]
    
    ; 2. Set PDN bit (bit-21) to make operational
    LDR R0, =AD0CR                
    LDR R1, [R0]
    ORR R2, R1, #0x200000
    STR R2, [R0]
    
    ; 3. Configure PCLK_ADC bits [25:24]
    LDR R0, =PCLKSEL0                
    LDR R1, [R0]
    ORR R2, R1, #0x03000000         
    STR R2, [R0]
    
    ; 4. Set PINSEL3 to function as AnalogIn
    LDR R0, =PINSEL3                
    LDR R1, [R0]
    ORR R2, R1, #0x30000000         
    STR R2, [R0]
    
    ; 5. Set SEL bits in AD0CR for AD0.4
    LDR R0, =AD0CR                
    LDR R1, [R0]
    ORR R2, R1, #0x10              
    STR R2, [R0]
    
    
    ; --- 4. Main Execution Loop ---
loop
    ; Step 1: Start the Conversion 
    ; Write 001 to bits [26:24] in AD0CR to trigger a read
    LDR R0, =AD0CR
    LDR R1, [R0]
    ORR R2, R1, #0x01000000    ; Set Bit 24 (START)
    STR R2, [R0]

WAIT_ADC
    ; Step 2: Wait for Conversion to Finish (Polling)
    ; Check the DONE bit (Bit 31) in the AD0DR4 register
    LDR R3, =AD0DR4
    LDR R4, [R3]
    TST R4, #0x80000000        ; Test bit 31 (0x80000000)
    BEQ WAIT_ADC               ; If 0, it is not done yet. Loop back and check again.

    ; Step 3: Extract the Result
    ; The 12-bit data is sitting in bits [15:4]
    LSR R4, R4, #4             ; Shift right by 4 spaces so the data starts at bit 0
    LDR R5, =0x0FFF            ; Load a 12-bit mask (binary 1111 1111 1111)
    AND R4, R4, R5             ; Apply the mask to clear out any leftover garbage bits
                               ; R4 now holds our clean analog value (0 to 4095)

    ; Step 4: Compare against the Threshold
    LDR R5, =THRESHOLD
    CMP R4, R5
    BLO TURN_ON_LEDS           ; If Lower than threshold (Dark), branch to ON
    BHS TURN_OFF_LEDS          ; If Higher or Same (Bright), branch to OFF

TURN_ON_LEDS
    ; Step 5a: Trigger Output HIGH
    LDR R0, =FIO2SET
    MOV R1, #0x3C
    STR R1, [R0]
    B END_LOOP

TURN_OFF_LEDS
    ; Step 5b: Trigger Output LOW
    LDR R0, =FIO2CLR
    MOV R1, #0x3C
    STR R1, [R0]
    B END_LOOP

END_LOOP
    ; Jump back to the top and take a new reading
    B loop
    
    END
