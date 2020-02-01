// file: delay.s
// created by: Grant Wilk
// date created: 10/5/2019
// description: contains functions for delays

// setup
.syntax unified
.cpu cortex-m4
.thumb
.section .text

// global functions
.global delay_us
.global delay_ms
.global delay_s

// accepts an integer and delays the program for that many microseconds
// @ param R1 - the number of milliseconds to delay for
// @ branch LR
// @ return None
delay_us:

    // R1 - number of microseconds to delay for
    // R2 - number of internal loops

    PUSH {R1, R2}

    1:
    // loop R1 times (~ 1 us / loop)
    MOV R2, #6

    2:
    // loop 3 times using R2 as a counter
    SUBS R2, R2, #1
    BNE 2b

    SUBS R1, R1, #1
    BNE 1b

    // exit subroutine
    POP {R1, R2}
    BX LR


// accepts an integer and delays the program for that many milliseconds
// @ param R1 - the number of milliseconds to delay for
// @ branch LR
// @ return None
delay_ms:

    // R1 - number of milliseconds to delay for
    // R2 - number of internal loops

    PUSH {R1, R2}

    1:
    // loop R1 times (~ 1 ms / loop)
    MOV R2, #5333

    2:
    // loop 5333 times using R1 as a counter
    SUBS R2, R2, #1
    BNE 2b

    SUBS R1, R1, #1
    BNE 1b

    // exit subroutine
    POP {R1, R2}
    BX LR


// accepts and integer and delays the program for that many seconds
// @ param R1 - the number of seconds to delay for
// @ branch LR
// @ return None
delay_s:

    // R1 - temp register for delay_ms parameters
    // R2 - the number of seconds to delay for

    PUSH {R1, R2, LR}

    MOV R2, R1

    1:
    // loop through a 1 second delay (via delay_ms) R1 times
    MOV R1, #1000
    BL delay_ms

    SUBS R2, R2, #1
    BNE 1b

    // exit subroutine
    POP {R1, R2, LR}
    BX LR
