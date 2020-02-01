// file: piezo.s
// created by: Grant Wilk
// date created: 10/27/2019
// date modified: 10/27/2019
// description: contains functions for operating the onboard piezo speaker

// setup
.syntax unified
.cpu cortex-m4
.thumb
.section .text

// constants
.equ RCC_BASE, 0x40023800
.equ RCC_AHB1ENR, 0x30
.equ RCC_APB1ENR, 0x40

.equ GPIOB_BASE, 0x40020400
.equ GPIO_MODER, 0x00
.equ GPIO_AFRL, 0x20

.equ TIM3_BASE, 0x40000400
.equ TIMx_CR1, 0x00
.equ TIMx_CCMR1, 0x18
.equ TIMx_CCER, 0x20
.equ TIMx_ARR, 0x2C
.equ TIMx_CCR1, 0x34

// global functions
.global piezo_init
.global piezo_play_tone
.global piezo_play_1khz

// initializes the piezo buzzer
// @ param None
// @ return None
piezo_init:

	PUSH {R1, R2}

    // enable TIM3 in RCC
    LDR R1, =RCC_BASE
    LDR R2, [R1, #RCC_APB1ENR]
    ORR R2, R2, #0b10 // TIM3 is bit 1 in APB1ENR
    STR R2, [R1, #RCC_APB1ENR]

    // enable GPIOB in RCC
    LDR R2, [R1, #RCC_AHB1ENR]
    ORR R2, R2, #0b10 //GPIOB is bit 1 in AHB1ENR
    STR R2, [R1, #RCC_AHB1ENR]

    // enable alternate function for PB4
    LDR R1, =GPIOB_BASE
    LDR R2, [R1, #GPIO_MODER]
    BIC R2, R2, #(0b11<<8) // mask
    ORR R2, R2, #(0b10<<8) // 10 => alternate function mode
    STR R2, [R1, #GPIO_MODER]

	// set alternate function for PB4
    LDR R2, [R1, #GPIO_AFRL]
    BIC R2, R2, #(0b1111<<16) // mask for AFRL for GPIOB pin 4
    ORR R2, R2, #(0b0010<<16) // use AF2 (TIM3..5) for GPIOB pin 4
    STR R2, [R1, #GPIO_AFRL]

	// exit subroutine
    POP {R1, R2}
    BX LR


// plays a tone at the specified frequency for the specified amount of time
// @ param R1 - the frequency to emit
// @ param R2 - the number of milliseconds to play the sound for
// @ return None
piezo_play_tone:

    // R1 - the frequency to emit
    // R2 - the length in time to emit the frequency
    // R3 - the number of periods to emit the frequency on a 16MHz clock
    // R4 - the number of toggles to emit the frequency on a 16Mhz clock
    // R5 - address of TIM3_BASE
    // R6 - temp register

	PUSH {R1-R6, LR}

    // number of periods = (16 * 10^6) / frequency
    MOVW R3, #0x2400
    MOVT R3, #0xF4
    UDIV R3, R3, R1

    LDR R4, =TIM3_BASE

    // set TIMx_ARR and TIMx_CCR1
    STR R3, [R4, #TIMx_ARR]
    STR R3, [R4, #TIMx_CCR1]

    MOVW R5, #(0b011 << 4)
    STR R5, [R4, #TIMx_CCMR1]

    MOVW R5, #1
    STR R5, [R4, #TIMx_CCER]

    // enable the timer
    MOVW R5, #1
    STR R5, [R4, #TIMx_CR1]

    // delay
    MOV R1, R2
    BL delay_ms

    // disable the timer
    MOVW R5, #0
    STR R5, [R4, #TIMx_CR1]

	POP {R1-R6, LR}
    BX LR
