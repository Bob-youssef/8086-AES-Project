; =============================================================================
; TITLE: AES-128 ENCRYPTION IMPLEMENTATION IN 8086 ASSEMBLY
; DESCRIPTION: 
;   - Takes 32 Hex characters (16 bytes) as input from the user.
;   - Performs standard AES-128 Encryption (10 Rounds).
;   - Uses a static 128-bit Key defined in .DATA.
;   - Outputs the final encrypted ciphertext.
; =============================================================================

.MODEL SMALL
.STACK 100h

; =============================================================================
; MACRO DEFINITIONS
; =============================================================================

; -----------------------------------------------------------------------------
; MACRO: SubBytes
; PURPOSE: Performs the non-linear substitution step.
; LOGIC: Replaces every byte in the STATE with a corresponding byte from 
;        the S-Box table based on its value.
; -----------------------------------------------------------------------------
SubBytes_MACRO MACRO
    Local loopsSubBytes
    mov cx,16           ; Counter: Process all 16 bytes of the State
    xor si,si           ; SI = Index into STATE array (0 to 15)
    
    loopsSubBytes: 
        xor ax,ax           ; Clear AX. We need AH=0 to use AL as an index.
        mov AL,STATE[si]    ; Load current byte from State
        mov BX,OFFSET SBOX  ; Load address of S-Box table
        ADD BX,Ax           ; Calculate Address: SBOX_Base + Byte_Value
        mov AL,[BX]         ; Retrieve the substituted value
        mov STATE[si],AL    ; Store it back into State
        inc si
        loop loopsSubBytes  
ENDM

; -----------------------------------------------------------------------------
; MACRO: ShiftRows
; PURPOSE: Permutes the rows of the State.
; LOGIC: 
;   Row 0: No shift
;   Row 1: Circular shift left by 1
;   Row 2: Circular shift left by 2
;   Row 3: Circular shift left by 3
; -----------------------------------------------------------------------------
ShiftRows_MACRO MACRO
    ; --- Row 1 (Indices 1,5,9,13) -> Rotate Left 1 ---
    mov al, STATE[1]
    mov bl, STATE[5]
    mov STATE[1], bl
    mov bl, STATE[9]
    mov STATE[5], bl
    mov bl, STATE[13]
    mov STATE[9], bl
    mov STATE[13], al
                
    ; --- Row 2 (Indices 2,6,10,14) -> Rotate Left 2 ---         
    mov al, STATE[2]      
    mov bl, STATE[10]
    mov STATE[2], bl
    mov STATE[10], al 
    
    mov al, STATE[6]
    mov bl, STATE[14]
    mov STATE[6], bl
    mov STATE[14], al 
        
    ; --- Row 3 (Indices 3,7,11,15) -> Rotate Left 3 ---
    mov al, STATE[15]
    mov bl, STATE[11]
    mov STATE[15], bl
    mov bl, STATE[7]
    mov STATE[11], bl
    mov bl, STATE[3]
    mov STATE[7], bl
    mov STATE[3], al
ENDM

; -----------------------------------------------------------------------------
; MACRO: MixColumns
; PURPOSE: Mixes data within each column to provide diffusion.
; LOGIC: Performs Matrix Multiplication over Galois Field (2^8).
; NOTE: Uses a 'temp' buffer to store results first, because the calculation
;       for the second byte requires the original value of the first byte.
; -----------------------------------------------------------------------------
MixColumns_MACRO MACRO  
    local Mix_Loop
    
    ; Save registers (Critical: DX holds the Main Loop Counter)
    push dx
    push cx 
    push si
    
    xor si, si          ; SI = Column Pointer (0, 4, 8, 12)
    mov cx, 4           ; Loop 4 times (once per column)
    
    Mix_Loop: 
        ; --- Calculate Row 0: (2*S0) ^ (3*S1) ^ S2 ^ S3 ---
        mul MIX_MATRIX[0], STATE[SI] 
        mov dl, al
        mul MIX_MATRIX[1], STATE[SI+1]
        xor dl, al
        mul MIX_MATRIX[2], STATE[SI+2]
        xor dl, al 
        mul MIX_MATRIX[3], STATE[SI+3]
        xor dl, al 
        mov temp[0], dl     ; Save result to temp
        
        ; --- Calculate Row 1: S0 ^ (2*S1) ^ (3*S2) ^ S3 ---
        mul MIX_MATRIX[4], STATE[SI] 
        mov dl, al
        mul MIX_MATRIX[5], STATE[SI+1]
        xor dl, al
        mul MIX_MATRIX[6], STATE[SI+2]
        xor dl, al 
        mul MIX_MATRIX[7], STATE[SI+3]
        xor dl, al 
        mov temp[1], dl
        
        ; --- Calculate Row 2: S0 ^ S1 ^ (2*S2) ^ (3*S3) ---
        mul MIX_MATRIX[8], STATE[SI] 
        mov dl, al
        mul MIX_MATRIX[9], STATE[SI+1]
        xor dl, al
        mul MIX_MATRIX[10], STATE[SI+2]
        xor dl, al 
        mul MIX_MATRIX[11], STATE[SI+3]
        xor dl, al 
        mov temp[2], dl
        
        ; --- Calculate Row 3: (3*S0) ^ S1 ^ S2 ^ (2*S3) ---
        mul MIX_MATRIX[12], STATE[SI] 
        mov dl, al
        mul MIX_MATRIX[13], STATE[SI+1]
        xor dl, al
        mul MIX_MATRIX[14], STATE[SI+2]
        xor dl, al 
        mul MIX_MATRIX[15], STATE[SI+3]
        xor dl, al 
        mov temp[3], dl
        
        ; --- Write Back: Overwrite original column with new values ---
        mov al, temp[0]
        mov STATE[SI], al
        mov al, temp[1]
        mov STATE[SI+1], al
        mov al, temp[2]
        mov STATE[SI+2], al
        mov al, temp[3]
        mov STATE[SI+3], al
        
        add si, 4       ; Move to next column
        dec cx
        jnz Mix_Loop
        
    ; Restore registers
    pop si 
    pop cx
    pop dx          
ENDM

; -----------------------------------------------------------------------------
; MACRO: AddRoundKey
; PURPOSE: XORs the State with the Round Key.
; -----------------------------------------------------------------------------
AddRoundKey_MACRO MACRO
    local XOR_LOOP
    push cx
    push si
    
    mov cx, 16
    xor si, si
    XOR_LOOP:
        mov al, STATE[si]
        mov bl, ROUND_KEY[si]
        xor al, bl          ; Logic: State = State XOR Key
        mov STATE[si], al
        inc si
        loop XOR_LOOP

    pop si
    pop cx
ENDM

; -----------------------------------------------------------------------------
; HELPER MACROS: Galois Field Multiplication
; mul2: Multiplies AL by 2 (Shift Left + Conditional XOR 1Bh)
; mul:  Multiplies 'num2' by 'num1' (1, 2, or 3)
; -----------------------------------------------------------------------------
mul2 MACRO 
    local done
    shl al,1        ; Multiply by 2
    jnc done        ; If no carry, we are done
    xor al,1Bh      ; If carry (overflow), XOR with AES polynomial
done:
endm

mul MACRO num1, num2 
    local done, cond1, cond2, cond3
    
    mov al, num2    ; Load value
    
    mov bl, num1    ; Load multiplier
    dec bl 
    jz cond1        ; If multiplier is 1
    
    mov bl, num1
    sub bl, 2
    jz cond2        ; If multiplier is 2
    jmp cond3       ; If multiplier is 3
    
    cond1:          ; x * 1 = x
        jmp done 
    cond2:          ; x * 2 = mul2(x)
        mul2 
        jmp done
    cond3:          ; x * 3 = mul2(x) XOR x
        mov ah, num2
        mul2
        xor al, ah
done:
    endm        
    
; =============================================================================
; DATA SEGMENT
; =============================================================================
.DATA

; --- AES S-Box Table (Substitution Box) ---
SBox DB 63H, 7CH, 77H, 7BH, 0F2H, 6BH, 6FH, 0C5H, 30H, 01H, 67H, 2BH, 0FEH, 0D7H, 0ABH, 76H
     DB 0CAH, 82H, 0C9H, 7DH, 0FAH, 59H, 47H, 0F0H, 0ADH, 0D4H, 0A2H, 0AFH, 9CH, 0A4H, 72H, 0C0H
     DB 0B7H, 0FDH, 93H, 26H, 36H, 3FH, 0F7H, 0CCH, 34H, 0A5H, 0E5H, 0F1H, 71H, 0D8H, 31H, 15H
     DB 04H, 0C7H, 23H, 0C3H, 18H, 96H, 05H, 09AH, 07H, 12H, 80H, 0E2H, 0EBH, 27H, 0B2H, 75H
     DB 09H, 83H, 2CH, 1AH, 1BH, 6EH, 5AH, 0A0H, 52H, 3BH, 0D6H, 0B3H, 29H, 0E3H, 2FH, 84H
     DB 53H, 0D1H, 00H, 0EDH, 20H, 0FCH, 0B1H, 5BH, 6AH, 0CBH, 0BEH, 39H, 4AH, 4CH, 58H, 0CFH
     DB 0D0H, 0EFH, 0AAH, 0FBH, 43H, 4DH, 33H, 85H, 45H, 0F9H, 02H, 7FH, 50H, 3CH, 9FH, 0A8H
     DB 51H, 0A3H, 40H, 8FH, 92H, 9DH, 38H, 0F5H, 0BCH, 0B6H, 0DAH, 21H, 10H, 0FFH, 0F3H, 0D2H
     DB 0CDH, 0CH, 13H, 0ECH, 5FH, 97H, 44H, 17H, 0C4H, 0A7H, 7EH, 3DH, 64H, 5DH, 19H, 73H
     DB 60H, 81H, 4FH, 0DCH, 22H, 2AH, 90H, 88H, 46H, 0EEH, 0B8H, 14H, 0DEH, 5EH, 0BH, 0DBH
     DB 0E0H, 32H, 3AH, 0AH, 49H, 06H, 24H, 5CH, 0C2H, 0D3H, 0ACH, 62H, 91H, 95H, 0E4H, 79H
     DB 0E7H, 0C8H, 37H, 6DH, 8DH, 0D5H, 4EH, 0A9H, 6CH, 56H, 0F4H, 0EAH, 65H, 7AH, 0AEH, 08H
     DB 0BAH, 78H, 25H, 2EH, 1CH, 0A6H, 0B4H, 0C6H, 0E8H, 0DDH, 74H, 1FH, 4BH, 0BDH, 8BH, 8AH
     DB 70H, 3EH, 0B5H, 66H, 48H, 03H, 0F6H, 0EH, 61H, 35H, 57H, 0B9H, 86H, 0C1H, 1DH, 9EH
     DB 0E1H, 0F8H, 98H, 11H, 69H, 0D9H, 8EH, 94H, 9BH, 1EH, 87H, 0E9H, 0CEH, 55H, 28H, 0DFH
     DB 8CH, 0A1H, 89H, 0DH, 0BFH, 0E6H, 42H, 68H, 41H, 99H, 2DH, 0FH, 0B0H, 54H, 0BBH, 16H

; --- The 128-bit State Matrix ---
STATE DB 19h,3dh,0e3h,0beh,0a0h,0f4h,0e2h,02bh,09ah,0c6h,08dh,02ah,0e9h,0f8h,048h,08h

; --- Round Key (Static for now) ---
ROUND_KEY DB 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh

; --- MixColumns Constant Matrix ---
MIX_MATRIX  DB  02h, 03h, 01h, 01h
            DB  01h, 02h, 03h, 01h
            DB  01h, 01h, 02h, 03h                        
            DB  03h, 01h, 01h, 02h

; --- Buffers ---
temp DB 4 DUP(0)           ; Buffer for MixColumns calculations
TEMP_STATE DB 16 DUP(?)    ; Buffer for Transpose operations
          
; =============================================================================
; PROCEDURES DEFINITIONS
; =============================================================================
.CODE   

; -----------------------------------------------------------------------------
; PROC: ReadInput
; Reads 32 Hex characters (0-9, A-F) and stores them as 16 bytes in STATE.
; -----------------------------------------------------------------------------
ReadInput PROC 
    xor si, si 
    mov cx, 16 
    
    ReadLoop: 
        ; Read High Nibble (First char)
        mov ah, 01h 
        int 21h 
        call AsciiToHex     ; Convert 'A' to 10
        shl al, 4           ; Shift to upper 4 bits
        mov bl, al          ; Save it
        
        ; Read Low Nibble (Second char)
        mov ah, 01h 
        int 21h 
        call AsciiToHex
        
        ; Combine and Store
        add al, bl 
        mov STATE[si], al
        inc si 
        loop ReadLoop
        
        ret
ReadInput ENDP
        
; -----------------------------------------------------------------------------
; PROC: PrintState
; Displays the current 16-byte STATE to the console as Hex.
; -----------------------------------------------------------------------------
PrintState PROC
    ; Print Newline
    mov ah, 02h
    mov dl, 0Dh 
    int 21h
    mov dl, 0Ah 
    int 21h
    
    xor si, si
    mov cx, 16

    PrintLoop:
        mov al, STATE[si]
        
        ; Print High Nibble
        mov dl, al
        shr dl, 4       
        call PrintHexDigit
        
        ; Print Low Nibble
        mov dl, al
        and dl, 0Fh     
        call PrintHexDigit
        
        ; Print Space
        mov ah, 02h
        mov dl, ' '
        int 21h
    
        inc si
        loop PrintLoop
    
        ; Final Newline
        mov ah, 02h
        mov dl, 0Dh
        int 21h
        mov dl, 0Ah
        int 21h
    
        ret
PrintState ENDP  

; -----------------------------------------------------------------------------
; PROC: PrintHexDigit
; Converts a numeric value (0-15) to ASCII ('0'-'9', 'A'-'F') and prints it.
; -----------------------------------------------------------------------------
PrintHexDigit PROC
    push ax
    mov al, dl
    
    cmp al, 9
    ja IsLetter 

    add al, '0'     ; 0-9
    jmp PrintNow

    IsLetter:
        add al, 'A' - 10 ; A-F
    
    PrintNow:
        mov dl, al
        mov ah, 02h
        int 21h
        pop ax
        ret
PrintHexDigit ENDP

; -----------------------------------------------------------------------------
; PROC: AsciiToHex
; Converts an ASCII character ('0'-'9', 'A'-'F') to its numeric value.
; -----------------------------------------------------------------------------
AsciiToHex PROC      
    cmp al, '0'
    jl invalid
    cmp al, '9'
    jbe is_digit

    cmp al, 'A'
    jl check_lower
    cmp al, 'F'
    jbe is_upper

    check_lower:
        cmp al, 'a'
        jl invalid
        cmp al, 'f'
        ja invalid
        sub al, 'a' - 10
        ret
    
    is_upper:
        sub al, 'A' - 10
        ret
        
    is_digit:
        sub al, '0'
        ret
        
    invalid:
        mov al, 0
        ret
AsciiToHex ENDP

; -----------------------------------------------------------------------------
; PROC: Transpose
; Converts the State between Row-Major (Input format) and Column-Major (AES format).
;   Input:  1, 2, 3, 4 ...
;   Output: 1, 5, 9, 13 ...
; -----------------------------------------------------------------------------
Transpose PROC
    ; Step 1: Copy current STATE to TEMP_STATE
    mov cx, 16
    xor si, si
copy_loop:
    mov al, STATE[si]
    mov TEMP_STATE[si], al
    inc si
    loop copy_loop

    ; Step 2: Rebuild STATE in column-major order
    xor si, si          ; si = destination index in STATE
    mov di, 0           ; di = column index
outer_loop:
    mov bp, 0           ; bp = row index
inner_loop:
    ; Calculate Source index: row*4 + col
    mov ax, bp
    shl ax, 2           ; * 4
    add ax, di          ; + col
    mov bx, ax
    
    mov al, TEMP_STATE[bx]
    mov STATE[si], al
    inc si              
    
    inc bp
    cmp bp, 4
    jl inner_loop
    
    inc di
    cmp di, 4
    jl outer_loop
    ret
Transpose ENDP

; =============================================================================
; MAIN CODE SEGMENT
; =============================================================================
START:
    ; 1. Initialize Data Segment
    MOV AX, @DATA 
    MOV DS, AX
    
    ; 2. Get User Input
    call ReadInput       
    
    ; 3. Convert Input (Row-Major) to AES Format (Column-Major)
    call Transpose       
    
    ; ==========================================================
    ; ROUND 0: Initial Key Addition (Whitening)
    ; ==========================================================
    AddRoundKey_MACRO

    ; ==========================================================
    ; ROUNDS 1 to 9: Main Transformation Loop
    ; ==========================================================
    MOV DX, 9           ; Loop 9 times

    AES_LOOP:
        SubBytes_MACRO      ; Non-linear substitution
        ShiftRows_MACRO     ; Row Permutation
        MixColumns_MACRO    ; Column Mixing
        AddRoundKey_MACRO   ; Key Mixing
        
        DEC DX              
        JNZ AES_LOOP        

    ; ==========================================================
    ; ROUND 10: Final Round (No MixColumns)
    ; ==========================================================
    SubBytes_MACRO
    ShiftRows_MACRO
    
    AddRoundKey_MACRO 
    
    ; 4. Convert Back to Row-Major for Printing
    call Transpose 
    
    ; 5. Display Result
    call PrintState 
    
    ; 6. Exit
    MOV AH, 4Ch
    INT 21h

END START