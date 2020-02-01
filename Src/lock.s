// file: lock.s
// created by: Grant Wilk
// date created: 10/26/2019
// date modified: 10/26/2019
// description: contains functions for operating a code lock

// setup
.syntax unified
.cpu cortex-m4
.thumb
.section .text

// constants
.equ GPIOB_BASE, 0x40020400
.equ GPIO_MODER, 0x00

// global functions
.global lock_setup
.global lock_enter_code
.global lock_compare_codes
.global lock_play_code_correct_tone
.global lock_play_code_incorrect_tone
.global lock_unlock


// allows the user to enter a code and stores the code in memory as button numbers (e.g. "1234" would be {0x01, 0x02, 0x03, 0x05} because the 1st, 2nd, 3rd, and 5th buttons were pressed)
// @ param R1 - the address to store the unlock code at
// @ param R2 - the number of bytes allocated to storing the unlock code. the maximum code length is equal to the number of bytes allocated here. This number must be greater than 0 and less than 16.
// @ return None
lock_enter_code:

    // R1 - temp / parameter 1 for subroutines
    // R2 - temp / paramgeter 2 for subroutines
    // R3 - unlock code memory pointer
    // R4 - maximum length of the unlock code
    // R5 - current length of the unlock code
    // R6 - last keypress register

    PUSH {R1-R6, LR}

    // move the unlock code memory pointer to the proper register
    MOV R3, R1

    // initialize the unlock code max length value to equal the number of bytes allocated in memory for the unlock code minus 1
    MOV R4, R2

    // initialize the unlock code length counter
    MOV R5, #0

    // initialize the last keypress register
    MOV R6, #0

    // initialize the bytes the entered code will be written to
    MOV R1, #0
    MOV R2, #0

    3:

    STRB R1, [R3, R2]
    ADD R2, R2, #1

    CMP R2, R4
    BGE 1f

    B 3b

    // key loop
    1:

    // get the keypress
    BL lock_key_get_restricted

    // check to see if current keypress is the last keypress
    // if true, get the keypress again
    CMP R0, R6
    BEQ 1b

    // set last keypress register
    MOV R6, R0

    // check to see if no key was pressed last keypress
    // if true, get the keypress again
    CMP R6, #0
    BEQ 1b

    // check to see if the last keypress is on our terminator key ("#" = key 15)
    // if true, print unlock code set confirmation and exit subroutine
    CMP R6, #15
    BEQ 2f

    // check to see if the current code is greater than or equal to the max unlock code length
    // if true, get the keypress again to prevent the user from entering a longer code
    CMP R5, R4
    BEQ 1b

    // print a star character to the lcd to represent a character in our unlock code
    MOV R1, #'*'
    BL lcd_print_char

    // store the number associated with the keypress in memory at the address specified by our pointer and offset by the current length of our unlock code length counter
    STRB R6, [R3, R5]

    // increment our unlock code length counter
    ADD R5, R5, #1

    // branch back to get the next keypress
    B 1b

    // exit subroutine
    2:
    POP {R1-R6, LR}
    BX LR


// compares two codes and returns
// @ param R1 - address of the first code
// @ param R2 - address of the second code
// @ param R3 - the number of bytes allocated to storing the unlock code. the maximum code length is equal to the number of bytes allocated here. This number must be greater than 0 and less than 16.
// @ return 1 if the codes are equal or 0 if the codes are not equal
lock_compare_codes:

    // R1 - address of the first code
    // R2 - address of the second code
    // R3 - the max length of the unlock code
    // R4 - the byte counter for sampling bytes
    // R5 - entered code byte
    // R6 - unlock code byte

    PUSH {R1-R6}

    // initialize return register
    MOV R0, #0

    // initialize byte counter
    MOV R4, #0

    1:
    // if the max length has been met, the codes are equal
    CMP R4, R3
    BEQ 2f

    // read entered code byte
    LDRB R5, [R1, R4]

    // read unlock code byte
    LDRB R6, [R2, R4]

    // if the bytes are not equal, the codes are not equal
    CMP R5, R6
    BNE 3f

    // increment byte counter
    ADD R4, R4, #1

    B 1b

    // set return register to be 1
    2:
    MOV R0, #1

    // exit subroutine
    3:
    POP {R1-R6}
    BX LR


// gets the current keypress and return it if it is a number key or the "#" key, otherwise return 0 for no keypress
// @ param None
// @ return R0 - the current keypress if it is a number key or the "#" key, otherwise return 0
lock_key_get_restricted:

    PUSH {LR}

    // get the key
    BL key_get

    // if key is "A", return 0
    CMP R0, #4
    BEQ 1f

    // if key is "B", return 0
    CMP R0, #8
    BEQ 1f

    // if key is "C", return 0
    CMP R0, #12
    BEQ 1f

    // if key is "*", return 0
    CMP R0, #13
    BEQ 1f

    // if key is "D", return 0
    CMP R0, #16
    BEQ 1f

    // else, just return the actual keypress value
    B 2f

    // set return value to 0
    1:
    MOV R0, #0

    // exit subroutine
    2:
    POP {LR}
    BX LR


// unlocks the lock
// @ param None
// @ return None
lock_unlock:

    PUSH {R1-R2, LR}

    // enable lights from left to right with a 30ms delay between
    MOV R2, #10

    1:
    SUB R1, R2, #1
    BL led_enable

    MOV R1, #30
    BL delay_ms

    SUBS R2, R2, #1
    BNE 1b

    // wait for 150ms
    MOV R1, #150
    BL delay_ms

    // disable lights from left to right with a 30ms delay between
    MOV R2, #10

    2:
    SUB R1, R2, #1
    BL led_disable

    MOV R1, #30
    BL delay_ms

    SUBS R2, R2, #1
    BNE 2b

    // exit subroutine
    POP {R1-R2, LR}
    BX LR


// plays the locks correct code tone
// @ param None
// @ return None
lock_play_code_correct_tone:

	PUSH {R1, R2, LR}

	// B6 - Eigth
	MOV R1, #1976
    MOV R2, #100
    BL piezo_play_tone

	// E7 - Three Quarter
    MOV R1, #2637
    MOV R2, #500
    BL piezo_play_tone

    POP {R1, R2, LR}
    BX LR


// plays the locks incorrect code tone
// @ param None
// @ return None
lock_play_code_incorrect_tone:

	PUSH {R1, R2, LR}

	// B4 - Quarter
	MOV R1, #493
    MOV R2, #200
    BL piezo_play_tone

	// F5 - Quarter
    MOV R1, #698
    MOV R2, #200
    BL piezo_play_tone

    // Rest - Eigth
    MOV R1, #100
    BL delay_ms

	// F5 - Quarter (gap)
    MOV R1, #698
    MOV R2, #175
    BL piezo_play_tone

    MOV R1, #25
    BL delay_ms

	// F5 - Eigth
    MOV R1, #698
    MOV R2, #100
    BL piezo_play_tone

    // Rest - Eigth
    MOV R1, #100
    BL delay_ms

    // E5 - Eigth
    MOV R1, #659
    MOV R2, #100
    BL piezo_play_tone

    // Rest - Eigth
    MOV R1, #100
    BL delay_ms

    // D5 - Eigth
    MOV R1, #587
    MOV R2, #100
    BL piezo_play_tone

    // Rest - Eigth
    MOV R1, #100
    BL delay_ms

    // C5 - Quarter
    MOV R1, #523
    MOV R2, #200
    BL piezo_play_tone

    // E4 - Quarter
    MOV R1, #330
    MOV R2, #200
    BL piezo_play_tone

    // Rest - Eigth
    MOV R1, #100
    BL delay_ms

    // E4 - Quarter
    MOV R1, #330
    MOV R2, #200
    BL piezo_play_tone

    // C4 - Quarter + Eigth
    MOV R1, #262
    MOV R2, #500
    BL piezo_play_tone

    POP {R1, R2, LR}
    BX LR
