// file: keypad.s
// created by: Grant Wilk
// date created: 10/15/2019
// description: contains functions for interacting with the onboard keypad

// setup
.syntax unified
.cpu cortex-m4
.thumb
.section .text

// RCC constants
.equ RCC_BASE, 0x40023800 // base
.equ RCC_AHB1ENR, 0x0030 // offset
.equ RCC_GPIOCEN, 0x04 // bit

//GPIO constants
.equ GPIOC_BASE, 0x40020800 // base
.equ GPIO_MODER, 0x00 // offset
.equ GPIO_PUPDR, 0x0C // offset
.equ GPIO_IDR, 0x10 // offset
.equ GPIO_ODR, 0x14 // offset

// global functions
.global key_init
.global key_get
.global key_get_block
.global key_get_char
.global key_get_char_block


// initializes the keypad GPIO ports
// @ param None
// @ return None
key_init:

    // R1 - base addresses
    // R2 - loaded data or masks

    PUSH {R1, R2}

    // enable clock for GPIO C
    LDR R1, =RCC_BASE
    LDR R2, [R1, #RCC_AHB1ENR]
    ORR R2, R2, #RCC_GPIOCEN
    STR R2, [R1, #RCC_AHB1ENR]

    // confgure keypad pins as pull-down
    LDR R1, =GPIOC_BASE
    MOV R2, #0xAAAA
    STRH R2, [R1, #GPIO_PUPDR]

    // exit subroutine
    POP {R1, R2}
    BX LR


// returns the key that is pressed without blocking the program
// @ param None
// @ return R0 - the number of the key that was pressed (1-16), or 0 if no key is pressed
key_get:

    // R1 - temp register
    // R2 - value of columns
    // R3 - value of rows

    PUSH {R1-R3, LR}

    // get keys
    BL key_get_input

    // if no key pressed, skip processing
    CMP R0, #0x00
    BEQ 1f

    // split keypad values into two registers
    UBFX R2, R0, #0, #4 // columns
    UBFX R3, R0, #4, #4 // rows

    // convert columns from one-hot to binary
    MOV R1, R2
    BL one_hot_to_binary
    MOV R2, R0

    // convert rows from one-hot to binary
    MOV R1, R3
    BL one_hot_to_binary
    MOV R3, R0

    // calculate button (4 * row + column) and store in R0
    MOV R1, #4
    MLA R0, R1, R3, R2

    // add one to button so it fits in the 1-16 range instead of 0-15
    ADD R0, R0, #1
    B 2f

    1:
    // set return register equal to zero
    MOV R0, #0

    // exit subroutine
    2:
    POP {R1-R3, LR}
    BX LR


// blocks the program and waits until a key is pressed, then returns that key
// @ param None
// @ return R0 - the number of the key that was pressed (1-16), or 0 if no key is pressed
key_get_block:

    PUSH {LR}

    1:
    BL key_get

    CMP R0, #0
    BEQ 1b

    POP {LR}
    BX LR


// returns the ascii character associated with the character on the pressed key
// @ param None
// @ return R0 - the ascii characeter associated with the character on the pressed key, if no key is pressed, return a null terminator
key_get_char:

    PUSH {R1, R2, LR}

    // get the number of the key being pressed and move it to R1
    BL key_get
    MOV R1, R0

    // if no key is pressed, return a null terminator instead of an ascii char
    CMP R1, #0
    BEQ 1f

    // offset the gotten key by -1 to account for the shift from 0-15 to 1-16 previously
    SUB R1, R1, #1

    // get the address of the ascii values string
    LDR R2, =ascii_values

    // read the character at the base address using the key pressed number as an offset
    // store in R0 for return
    LDRB R0, [R2, R1]
    B 2f

    // return null terminator
    1:
    MOV R0, #0

    // exit subroutine
    2:
    POP {R1, R2, LR}
    BX LR


// blocks the program and waits until a key is pressed, then it returns the ascii character associated with the character on the pressed key
// @ param None
// @ return R0 - the ascii character associated with the character on the pressed key
key_get_char_block:

    PUSH {LR}

    1:
    BL key_get_char

    CMP R0, #0
    BEQ 1b

    POP {LR}
    BX LR


// reads from the keypad and handles the toggling between input/output behavior between rows and columns
// @ param None
// @ return R0 - a byte containing the one-hot column output in the first nibble and the one-hot row output in the second nibble (e.g. 0bCCCCRRRR, where C is a column bit and R is a row bit)
key_get_input:

    // R2 - GPIO C base address
    // R3 - temp register
    // R4 - read value of columns before they're moved to R0
    // R5 - debounce flag

    PUSH {R1-R5, LR}

    // get GPIO C base address
    LDR R2, =GPIOC_BASE

    // drive ODR output values high for all keypad pins
    MOV R3, #0xFF
    STRB R3, [R2, #GPIO_ODR]

    // set debounce flag as low
    MOV R5, #0

    1:
    // set the columns as inputs and the rows as outputs
    MOV R3, #0x5500
    STRH R3, [R2, #GPIO_MODER]

    MOV R1, #10
    BL delay_us

    // read the value of the columns
    // stored in the bottom half of the nibble
    LDRB R4, [R2, #GPIO_IDR]

    // set the rows as inputs and the columns as outputs
    MOV R3, #0x0055
    STRH R3, [R2, #GPIO_MODER]

    MOV R1, #10
    BL delay_us

    // read the value of the rows and mask off column bits and store in R0
    // stored in the top half of the nibble
    LDRB R0, [R2, #GPIO_IDR]

    // move the columns to the bottom half of the return register (R0)
    BFI R0, R4, #0, #4

    // debounce the switch
    // check to see if the debounce flag has been set
    // if it has, just return the value
    CMP R5, #0
    BNE 2f

    // check to see if the value read is not just 0
    // if it is, set the debounce flag, delay 50ms, and run again
    // otherwise, return the value
    CMP R0, #0
    BEQ 2f

    // set the debounce flag high
    MOV R5, #1

    // delay 50 ms
    MOV R1, #1
    BL delay_ms

    // run again
    B 1b

    // prevent double key presses
    2:

    LDR R1, =last_value
    LDRB R2, [R1]

    // if current value is not zero
    CMP R0, #0
    BEQ 3f

    // if last value is not zero
    CMP R2, #0
    BEQ 3f

    // if last value is not current value
    CMP R0, R2
    BEQ 3f

    // set current value to last value
    MOV R0, R2

    // exit subroutine
    3:
    STRB R0, [R1]
    POP {R1-R5, LR}
    BX LR


// encodes a one-hot number in binary
// @ param R1 - a one-hot number
// @ return R0 - the number encoded in binary
one_hot_to_binary:

    PUSH {R1}

    // binary equivalent = word length - leading zeros
    CLZ R1, R1
    RSB R0, R1, #31

    // exit subroutine
    POP {R1}
    BX LR


.section .data
last_value:
    .byte 0
ascii_values:
    .asciz "123A456B789C*0#D"
