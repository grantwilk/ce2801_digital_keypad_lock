// file: led.s
// created by: Grant Wilk
// date created: 10/28/2019
// date modified: 10/28/2019
// description: contains functions for manipulating the onboard led bar

// setup
.syntax unified
.cpu cortex-m4
.thumb
.section .text

// constants
.equ RCC_BASE, 0x40023800
.equ RCC_AHB1ENR, 0x30

.equ GPIOB_BASE, 0x40020400
.equ GPIO_MODER, 0x00
.equ GPIO_ODR, 0x14

// global functions
.global led_init
.global led_set
.global led_enable
.global led_disable

// initializes the led pins as outputs
// @ param None
// @ return None
led_init:

    PUSH {R1-R3}

    // enable GPIOB in RCC
    LDR R1, =RCC_BASE
    LDR R2, [R1, #RCC_AHB1ENR]
    ORR R2, R2, #(1<<1) // GPIOBEN is in bit 1
    STR R2, [R1, #RCC_AHB1ENR]

    // configure pins PB5-PB15 (except PB11) as outputs
    LDR R1, =GPIOB_BASE
    LDR R2, [R1, #GPIO_MODER]

    MOVW R3, #0xFC00
    MOVT R3, #0xFF3F
    BIC R2, R2, R3

    MOVW R3, #0x5400
    MOVT R3, #0x5515
    ORR R2, R2, R3

    STR R2, [R1, #GPIO_MODER]

    // exit subroutine
    POP {R1-R3}
    BX LR


// turns on the specified led
// @ param R1 - the led to turn on, must be between 0 and 9 or the function does nothing
// @ return None
led_enable:

    PUSH {R1-R3}

    // if led is past led #5, add one to account for PB11 offset
    CMP R1, #6
    BLT 1f

    ADD R1, R1, #1

    // shift the bit until it is in the proper position for ORR-ing
    // store the final value in R3
    1:
    MOV R3, #(1<<5)
    LSL R3, R3, R1

    LDR R1, =GPIOB_BASE
    LDR R2, [R1, #GPIO_ODR]
    ORR R2, R2, R3
    STR R2, [R1, #GPIO_ODR]

    // exit subroutine
    POP {R1-R3}
    BX LR


// turns off the specified led
// @ param R1 - the led to turn on, must be between 0 and 9 or the function does nothing
// @ return None
led_disable:

    PUSH {R1-R3}

    // if led is past led #5, add one to account for PB11 offset
    CMP R1, #6
    BLT 1f

    ADD R1, R1, #1

    // shift the bit until it is in the proper position for ORR-ing
    // store the final value in R3
    1:
    MOV R3, #(1<<5)
    LSL R3, R3, R1

    LDR R1, =GPIOB_BASE
    LDR R2, [R1, #GPIO_ODR]
    BIC R2, R2, R3
    STR R2, [R1, #GPIO_ODR]

    // exit subroutine
    POP {R1-R3}
    BX LR
