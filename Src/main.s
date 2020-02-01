// file: main.s
// created by: Grant Wilk
// date created: 10/22/2019
// date modified: 10/22/2019
// description: a keypad lock program

// setup
.syntax unified
.cpu cortex-m4
.thumb

.section .data
unlock_code:
    .space 8 // bytes
entered_code:
    .space 8 // bytes

// set code strings
set_code_string:
    .asciz "SET PASSCODE:"
set_code_confirm_string:
    .asciz "PASSCODE SET!"

// enter code strings
enter_code_string:
    .asciz "ENTER PASSCODE:"

// enter code responses
code_correct_string:
    .asciz "UNLOCKING..."

code_incorrect_string:
    .asciz "INVALID PASSCODE"

.section .text

// constants
.equ unlock_code_max_length, 8

// global functions
.global main

main:

    // initialize peripherals
    BL key_init
    BL lcd_init
    BL led_init
	BL piezo_init

    // print set unlock code string
    LDR R1, =set_code_string
    BL lcd_print_string

    // set cursor position to line 2
    MOV R1, #1
    MOV R2, #0
    BL lcd_set_position

    // show cursor
    MOV R1, #0x0D
    BL lcd_write_instruction

    // run lock setup
    LDR R1, =unlock_code
    MOV R2, unlock_code_max_length
    BL lock_enter_code

    // clear the lcd
    BL lcd_clear

    // print code confirmation string
    LDR R1, =set_code_confirm_string
    BL lcd_print_string

    // hide the cursor
    MOV R1, #0x0C
    BL lcd_write_instruction

    // play code correct tone
    BL lock_play_code_correct_tone

    // delay 1000 ms
    MOV R1, #1000
    BL delay_ms

	enter_code:

    // clear the lcd
    BL lcd_clear

    // print enter code string
    LDR R1, =enter_code_string
    BL lcd_print_string

    // set cursor position to line 2
    MOV R1, #1
    MOV R2, #0
    BL lcd_set_position

    // show cursor
    MOV R1, #0x0D
    BL lcd_write_instruction

    // let the user enter a code
    LDR R1, =entered_code
    MOV R2, unlock_code_max_length
    BL lock_enter_code

    // clear the lcd
    BL lcd_clear

    // compare the codes
    LDR R1, =unlock_code
    LDR R2, =entered_code
    LDR R3, =unlock_code_max_length
    BL lock_compare_codes

    CMP R0, #0
    BEQ incorrect

    // if the codes are equal (correct)
    correct:
    // print code correct string
    LDR R1, =code_correct_string
    BL lcd_print_string

    // hide the cursor
    MOV R1, #0x0C
    BL lcd_write_instruction

    // play code correct tone
    BL lock_play_code_correct_tone

    // actually unlock the lock
    BL lock_unlock

    // delay an additional 500ms
    MOV R1, #500
    BL delay_ms

    B enter_code

    // if the codes are not equal (incorrect)
    incorrect:
    // print code incorrect string
    LDR R1, =code_incorrect_string
    BL lcd_print_string

    // hide the cursor
    MOV R1, #0x0C
    BL lcd_write_instruction

	// play incorrect tone
    BL lock_play_code_incorrect_tone

	// delay an additional second
    MOV R1, #1000
    BL delay_ms

    B enter_code

s:  B s
