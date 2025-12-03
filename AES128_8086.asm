.MODEL SMALL
.STACK 100h

; =============================================================================
; MACRO DEFINITIONS
; =============================================================================


SubBytes_MACRO MACRO
    Local loopsSubBytes
    mov cx,16 ; counter (16 bytes in the state)     
    xor si,si ; SI = 0 (byte index into STATE)
    loopsSubBytes: 
                
        xor ax,ax           ; Clear AX so AH=0 (we only want AL as 0..255 index)
        mov AL,STATE[si]    ; AL := STATE[SI] (index into SBox)
        mov BX,OFFSET SBOX  ; BX := offset of SBox table in DS
        ADD BX,Ax           ; BX := BX + AX -> pointer to SBox[index]
        mov AL,[BX]         ; AL := byte at DS:[BX] (SBox[index])
        mov STATE[si],AL    ; store substituted byte back to STATE[SI]
        inc si
        loop loopsSubBytes  ; loop until CX reaches 0
ENDM

ShiftRows_MACRO MACRO
    ; Row 1 (indices 1,5,9,13) rotate left by 1
    mov al, STATE[1]
    mov bl, STATE[5]
    mov STATE[1], bl
    mov bl, STATE[9]
    mov STATE[5], bl
    mov bl, STATE[13]
    mov STATE[9], bl
    mov STATE[13], al
               
    ; Row 2 (indices 2,6,10,14) rotate left by 2           
    mov al, STATE[2]      
    mov bl, STATE[10]
    mov STATE[2], bl
    mov STATE[10], al 
    
    mov al, STATE[6]
    mov bl, STATE[14]
    mov STATE[6], bl
    mov STATE[14], al 
       
    ; Row 3 (indices 3,7,11,15) rotate left by 3 (right by 1)
    mov al, STATE[15]
    mov bl, STATE[11]
    mov STATE[15], bl
    mov bl, STATE[7]
    mov STATE[11], bl
    mov bl, STATE[3]
    mov STATE[7], bl
    mov STATE[3], al
ENDM

MixColumns_MACRO MACRO 
    
    
ENDM

AddRoundKey_MACRO MACRO
ENDM  


; =============================================================================
; DATA SEGMENT
; =============================================================================
.DATA

; --- AES S-Box Table (256 bytes) ---
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

; --- The 128-bit State ---
STATE DB 19h,3dh,0e3h,0beh,0a0h,0f4h,0e2h,02bh,09ah,0c6h,08dh,02ah,0e9h,0f8h,048h,08h

; --- Round Key ---
ROUND_KEY DB 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh

; --- MixColumns Matrix ---
MIX_MATRIX  DB  02h, 03h, 01h, 01h
            DB  01h, 02h, 03h, 01h
            DB  01h, 01h, 02h, 03h                       
            DB  03h, 01h, 01h, 02h
          
; =============================================================================
; MAIN CODE SEGMENT
; =============================================================================
.CODE
START:
    ; Initialize Data Segment
    MOV AX, @DATA 
    MOV DS, AX    
    
        
END START