// file: lcd.s
// created by: Grant Wilk
// date created: 10/8/2019
// description: contains functions that pertain to the lcd

// setup
.syntax unified
.cpu cortex-m4
.thumb
.section .text

// RCC constants
.equ RCC_BASE, 0x40023800 // base
.equ RCC_AHB1ENR, 0x0030 // offset
.equ RCC_GPIOAEN, 0x0 // bit
.equ RCC_GPIOCEN, 0x2 // bit

// GPIO constants
.equ GPIOA_BASE, 0x40020000 // base
.equ GPIOC_BASE, 0x40020800 // base
.equ GPIO_MODER, 0x00 // offset
.equ GPIO_ODR, 0x14 // offset
.equ GPIO_BSRR, 0x18 // offset

// global functions
// initialization functions
.global lcd_init

// built-in instructions
.global lcd_clear
.global lcd_home
.global lcd_set_position

// print functions
.global lcd_print_string
.global lcd_print_num
.global lcd_print_char

// write functions
.global lcd_write_data
.global lcd_write_instruction


// Initializes the LCD, should only be run once at startup
// @ param None
// @ return None
lcd_init:

    PUSH {R1, LR}

    // setup board ports
    BL lcd_port_setup

    // delay for 40ms
    MOV R1, #40
    BL delay_ms

    // function set
    MOV R1, #0x38 // 8-bit interface, 2-line display, 5x8 character font
    BL lcd_write_instruction

    // function set
    MOV R1, #0x38 // 8-bit interface, 2-line display, 5x8 character font
    BL lcd_write_instruction

    // display on/off control
    MOV R1, #0x0F // entire display on, cursor on, cursor position on
    BL lcd_write_instruction

    // display clear
    BL lcd_clear

    // entry mode set
    MOV R1, #0x06 // increment by 1, no shift
    BL lcd_write_instruction

    // exit subroutine
    POP {R1, LR}
    BX LR


// clears the lcd display
// @ param None
// @ return None
lcd_clear:

    PUSH {R1, LR}

    // clear LCD instruction
    MOV R1, #0x01
    BL lcd_write_instruction

    // delay for 1520us
    MOV R1, #1520
    BL delay_us

    // exit subroutine
    POP {R1, LR}
    BX LR


// moves the cursor to the hom position
// @ param None
// @ return None
lcd_home:

    PUSH {R1, LR}

    // return home LCD instruction
    MOV R1, #0x02
    BL lcd_write_instruction

    // delay for 1520us
    MOV R1, #1520
    BL delay_us

    POP {R1, LR}
    BX LR


// moves the lcd cursor to the indicated position
// @ param R1 - the zero-based row, must be 0 or 1, otherwise the function does nothing
// @ param R2 - the zero-based column, must be between 0 and 39, otherwise the function does nothing
// @ return None
lcd_set_position:

    // R1 - row
    // R2 - column

    PUSH {R1-R3, LR}

    // verify parameters are within constraints, exit it not
    CMP R1, #1
    BGT 2f

    CMP R2, #39
    BGT 2f

    // send the cursor to its home position
    BL lcd_home

    // calculate the number of shifts necessary => (40 * row) + column
    MOV R3, #40
    MUL R3, R3, R1 // shifts = 40 * row
    ADD R3, R3, R2 // shifts = shifts + columns

    // R1 - number of shifts
    // R2 - LCD instruction

    // cursor shift right until R1 times
    1:
    MOV R1, #0x14 // cursor shift right instruction
    BL lcd_write_instruction

    SUBS R3, R3, #1
    BNE 1b

    2:
    POP {R1-R3, LR}
    BX LR


// prints a null terminated string to the display
// @ param R1 - the address of the null terminated string
// @ return R0 - the number of characters written to display from R0
lcd_print_string:

    // R1 - byte/character value
    // R2 - string address
    // R3 - byte/character offset

    PUSH {R1-R3, LR}

    MOV R2, R1

    // reset byte counter
    MOV R3, #0

    1:
    // load character at address + offset
    LDRB R1, [R2, R3]

    // check to see if character is null terminator
    // if true, exit, otherwise, continue
    CMP R1, #0
    BEQ 2f

    // write character
    BL lcd_write_data

    // increment character offset
    ADD R3, R3, #1

    B 1b

    // exit subroutine
    2:
    POP {R1-R3, LR}
    BX LR


// prints a decimal integer to the display
// @ param R1 - the integer to be displayed, must be between 0 and 9999
// @ return None
lcd_print_num:

    // R1 - current character
    // R2 - ascii converted number
    // R3 - byte counter
    // R4 - non-zero character found flag

    PUSH {R1-R4, LR}

    // convert the number to ascii and store it in R2
    BL num_to_ascii
    MOV R2, R0

    // reset the byte counter
    MOV R3, #4

    // reset the non-zero character flag
    MOV R4, #0

    // if value is all zero, skip processing and write a 0
    MOVW R1, #0x3030
    MOVT R1, #0x3030
    CMP R2, R1
    BEQ 4f

    1:
    // extract lowest bit
    UBFX R1, R2, #0, #8

    // if character is 0 in ascii, and ...
    CMP R1, #0x30
    BNE 2f

    // if no non-zero character has been found, skip writing to LCD
    CMP R4, #0
    BEQ 3f

    2:
    // otherwise, set non-zero character flag
    MOV R4, #1

    // write data
    BL lcd_write_data

    3:
    // shift out used bits
    LSR R2, R2, #8

    // decrement byte counter
    // if byte counter != zero, loop again
    SUBS R3, R3, #1
    BNE 1b
    B 5f

    // write zero to the lcd
    4:
    MOV R1, #0x30
    BL lcd_write_data

    // exit subroutine
    5:
    POP {R1-R4, LR}
    BX LR

// prints a single character to the lcd
// @ param R1 - the ascii character to write
// @ return None
lcd_print_char:

    PUSH {LR}

    // write data
    BL lcd_write_data

    // exit subroutine
    POP {LR}
    BX LR



// sets up LCD ports in RCC and GPIO MODER
// @ param None
// @ return None
lcd_port_setup:

    // R1 - RCC_BASE address
    // R2 - RCC_AHB1ENR values

    PUSH {R1, R2}

    // turn on GPIO ports in RCC
    LDR R1, =RCC_BASE
    LDR R2, [R1, #RCC_AHB1ENR]
    ORR R2, R2, #0x5
    STR R2, [R1, #RCC_AHB1ENR]

    // R1 - GPIOA_BASE address
    // R2 - GPIOA_MODER values

    // set lcd databus pins to be outputs
    LDR R1, =GPIOA_BASE
    LDR R2, [R1, #GPIO_MODER]

    MOVW R3, #0x5500 // mask for databus pins (GPIO_A4 - GPIO_A11)
    MOVT R3, #0x0055 // they will be configured as outputs

    ORR R2, R2, R3 // apply mask
    STR R2, [R1, #GPIO_MODER]

    // R1 - GPIOC_BASE address
    // R2 - GPIOC_MODER values

    // set RS, RW, and E pins to be outputs
    LDR R1, =GPIOC_BASE
    LDR R2, [R1, #GPIO_MODER]

    MOVW R3, #0x0000 // mask for pins RS, RW, and E
    MOVT R3, #0x0015 // they will be configured as outputs

    ORR R2, R2, R3 // apply mask
    STR R2, [R1, #GPIO_MODER]

    // exit subroutine
    POP {R1, R2}
    BX LR


// writes an instruction to the LCD
// @ param R1 - an 8-bit right-aligned instruction to be written to the LCD
// @ return None
lcd_write_instruction:

    // R1 - 8-bit instruction
    // R2 - GPIOC_BASE
    // R3 - GPIOC_ODR values
    // R4 - GPIOA_BASE
    // R5 - GPIOA_ODR values

    PUSH {R1-R5, LR}

    // set RS = 0, RW = 0, and E = 1 (skip a step)
    LDR R2, =GPIOC_BASE
    LDR R3, [R2, #GPIO_ODR]
    BIC R3, R3, #0x0700 // reset RS, RW, and E bits
    ORR R3, R3, #0x0400 // set E bit
    STR R3, [R2, #GPIO_ODR]

    // set R1[databus] = instruction data
    LDR R4, =GPIOA_BASE
    LDR R5, [R4, #GPIO_ODR]
    BFI R5, R1, #4, #8 // insert the instruction into the databus pins (GPIO_A4 - GPIO_A11)
    STR R5, [R4, #GPIO_ODR]

    // set E = 0 (trigger instruction)
    BIC R3, R3, #0x0400
    STR R3, [R2, #GPIO_ODR]

    // check if instruction is clear display or return home
    // if true, perform a long delay, otherwise exit
    CMP R1, 0x01
    BEQ long_delay

    CMP R1, 0x02
    BEQ long_delay

    CMP R1, 0x03
    BEQ long_delay

    // delay for 37us
    short_delay:
    MOV R1, #37
    BL delay_us
    B exit

    // delay for 1520us
    long_delay:
    MOV R1, #1520
    BL delay_us

    // exit subroutine
    exit:
    POP {R1-R5, LR}
    BX LR


// writes data to the LCD
// @ param R1 - the data to be written to the LCD
// @ return None
lcd_write_data:

    // R1 - 8-bit instruction
    // R2 - GPIOC_BASE
    // R3 - GPIOC_ODR values
    // R4 - GPIOA_BASE
    // R5 - GPIOA_ODR values

    PUSH {R1-R5, LR}

    // set RS = 1, RW = 0, E = 0
    LDR R2, =GPIOC_BASE
    LDR R3, [R2, #GPIO_ODR]
    BIC R3, R3, #0x0700 // reset RS, RW, and E bits
    ORR R3, R3, #0x0500 // set RS and E
    STR R3, [R2, #GPIO_ODR]

    // set R1[databus] = data
    LDR R4, =GPIOA_BASE
    LDR R5, [R4, #GPIO_ODR]
    BFI R5, R1, #4, #8 // insert the data into the databus pins (GPIO_A4 - GPIO_A11)
    STR R5, [R4, #GPIO_ODR]

    // set E = 0
    BIC R3, R3, #0x0400
    STR R3, [R2, #GPIO_ODR]

    // wait for 37us
    MOV R1, #37
    BL delay_us

    // exit subroutine
    POP {R1-R5, LR}
    BX LR


// accepts an integer between 0 and 9999 and returns the integer as a sequence of 4 characters in a word
// @ param R1 - the integer to convert
// @ branch LR
// @ return R0 - the sequence of characters
num_to_ascii:

    // R0 - return
    // R1 - the integer to convert
    // R2 - ascii number base (constant)
    // R3 - iteration counter

    PUSH {R1-R3, LR}

	// temporarily use R3 for comparison
	MOV R3, #9999

    CMP R1, R3
    BGT 2f

    // @ param R1 - the integer to convert to BCD
    BL binary_to_bcd
    MOV R1, R0

    MOV R2, #0x30 // ascii number base => 0
    MOV R3, #4 // iteration counter

    1:
    LSL R0, #8 // shift over the filled out bytes/characters of R0

    UBFX R4, R1, #0, #4 // get the least significant nibble of R1
    ADD R4, R2, R4 // add the number to the ascii number base and store in R4
    BFI R0, R4, #0, #8 // add the new bytes to the return value in R0

    LSR R1, #4 // shift out the used nibbles of R1

    SUBS R3, R3, #1
    BNE 1b

	// exit the subroutine
    B 3f

    2:
    // populate return register with ascii "Err."
    MOVW R0, #0x4572
    MOVT R0, #0x722E

    3:
    // exit subroutine
    POP {R1-R3, LR}
    BX LR


// accepts an integer between 0 and 9999 and returns the BCD encoded integer by nibbles in a word
// @ param R1 - an integer to be converted to BCD
// @ branch LR
// @ return R0 - the BCD encoded integer by nibbles in a word
binary_to_bcd:

    // R1 - the number being shifted
    // R2 - nibble counter
    // R3 - value of current nibble in the nibble counter
    // R4 - shift counter
    // R5 - shift max

    PUSH {R1-R5, LR}

    // clear shift counter
    MOV R4, #0

    // calculate shift max = word length - leading zeros
    CLZ R5, R1
    RSB R5, R5, #32 // word length - leading zeros

    1:
    // if shift counter == shift max, exit subroutine
    CMP R4, R5
    BEQ 4f

    // check if any BCD nibble is greater than or equal to 5
    MOV R2, R5 // starting bit in the units place

    2:
    // VUBFX - variable unsigned bit-field extract the nibble from bits R2-R2+4, and store in R3
    // @ param R1 - number to extract from
    // @ param R2 - least significant bit
    // @ param R3 - width of extraction
    MOV R3, #4 // width => 1 nibble
    BL variable_ubfx
    MOV R3, R0 // move the returned value of the extracted nibble to R3

    // if R3 >= 5
    CMP R3, #5
    BLT 3f

    // add 3 to R2 and reinsert to R0
    ADD R3, R3, #3

    // VBFI - variable bit-field insert the nibble from R3 into R1, and store result in R1
    // @ param R1 - number to insert to
    // @ param R2 - number to be inserted (should be right aligned)
    // @ param R3 - least significant bit to insert from
    // @ param R4 - width of insertion
    PUSH {R2-R4}
    // swap R2 and R3
    MOV R0, R3
    MOV R3, R2 // lsb => R2
    MOV R2, R0 // insert => R3

    MOV R4, #4 // width => 4
    BL variable_bfi
    MOV R1, R0
    POP {R2-R4}

    3:
    // increment nibble counter by 4
    ADD R2, R2, #4

    // if R1 not on last nibble, branch back
    CMP R2, #28
    BLT 2b

    // shift
    LSL R1, R1, #1
    // increment shift counter
    ADD R4, R4, #1
    B 1b

    4:
    LSR R1, R1, R5 // shift out extra bits
    MOV R0, R1

    POP {R1-R5, LR}
    BX LR

// variable unsigned bit-field extract: takes a binary number and extracts a portion of bits from it
// @ param R1 - number to extract from
// @ param R2 - least significant bit to start extracting from
// @ param R3 - width of extraction
// @ branch LR
// @ return R0 - extracted bits shifted to the least significant position
variable_ubfx:

    // R0 - return the extracted number
    // R1 - the number to extract from
    // R2 - least significant bit
    // R3 - width of extraction

    PUSH {R1-R4}

    // shift off irrelevant bits
    LSR R1, R1, R2

    // generate a mask of 1's
    MOVW R4, #0xFFFF
    MOVT R4, #0xFFFF

    // shift mask left by the width of the extraction
    LSL R4, R4, R3

    // clear masked bits, leaving the extraction in R0 for return
    BIC R0, R1, R4

    // exit subroutine
    POP {R1-R4}
    BX LR


// variable bit-field insert: takes a binary number and inserts it into another number -- other bits remain uneffected
// @ param R1 - number to insert to
// @ param R2 - number to be inserted (should be right aligned)
// @ param R3 - least significant bit to insert from
// @ param R4 - width of insertion
// @ branch LR
// @ return R0 - inserted number
variable_bfi:

    // R1 - number
    // R2 - insert
    // R3 - lsb
    // R4 - width
    // R5 - insert mask or number mask
    // R6 - temporary sum
    // word length => 32 bits

    PUSH {R1-R6}

    // shift insert left by lsb bits
    LSL R2, R2, R3

    // generate insert mask
    MOVW R5, 0xFFFF
    MOVT R5, 0xFFFF

    // shift mask left by (lsb + width)
    // R6 temporarily used to store (lsb + width)
    ADD R6, R3, R4
    LSL R5, R6

    // BIC insert by insert mask
    BIC R2, R5

    // generate number mask
    MOVW R5, 0xFFFF
    MOVT R5, 0xFFFF

    // shift number mask left by (word length - width)
    RSB R6, R4, #32 // reverse subtract => word length - width
    LSL R5, R5, R6

    // shift number mask right by (word length - (lsb + width))
    ADD R6, R3, R4 // lsb + width
    RSB R6, R6, #32 // reverse subtract => (word length - (lsb + width))
    LSR R5, R5, R6

    // BIC number by number mask
    BIC R1, R1, R5

    // ORR number and insert and store in R0 for return
    ORR R0, R1, R2

    // exit subroutine
    POP {R1-R6}
    BX LR
