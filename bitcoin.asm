/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                    C O N S T A N T S                                                    //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


.const BORDER_COLOR = $D020
.const SCREEN_COLOR = $D021
.const NUMBERS_FIRST = $05E5;
.const UP_ARROW_START = $05E5;
.const DOWN_ARROW_START = $0685;
.const SCREEN_RAM = $0400;
.const WELCOME_MESSAGE_START = $05bd;
.const LOGO_START = $0410;
.const ZEROPAGE_0005 = $05;
.const ZEROPAGE_0006 = $06;
.const ZEROPAGE_FA = $FA;
.const ZEROPAGE_FB = $FB;
.const JPORT2 = $DC00
.const UP = %00000001;
.const LEFT = %00000100;
.const FIRE = %00010000;


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                    V A R I A B L E S                                                    //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


BasicUpstart2(start)

*=$1000

// Variables
// Value 1 if we got new data so we need redraw the screen
isRefreshNeeded:
    .byte 1

// Decimal version of the currentNumber
decimalNumber:
    .byte 0,0,0,0,0,0,0,0,0,0 

// The current BTC price represented in 32bit
currentNumber:
    .byte $00, $00, $00, $00

// The 32bit to dec converter convert it to decimalNumber
convertNumber:
    .byte $00, $00, $00, $00

// Previous BTC price. Used for calculation the arrow
lastNumber:
    .byte $00, $00, $00, $00

// Print subrutin "private" variable
charactersInCurrentLine:
    .byte 0

// The arrow's direction
arrow: 
    .byte 0   // 1 - up, 2 - down

// Used characters for filling the up and down arrow
arrowCharacters:
    .byte $20,$20 // up, down
    
// Temporary variable for printing the numbers    
checkDigitForDraw:
    .byte 0    


// How works the datastram working:
//
//           Start signal
//              ^
//   Joy UP     1 1 0 1 0 1 ... x24     > Pulsing
//   Joy LEFT   1 0 1 0 1 0 ... x24     > Pulsing
//   Joy FIRE   0 1 1 0 1 1 ... x24
//   Output:      1 1 0 1 1 ... x24 = 24 bit data
//
//   Joy UP & Joy LEFT = Sync signals
//   Joy Fire = Data
//   Up and left always changing when new bit sent.
//   The new stram started always when up and left signal are there

// TMP byte in datastream
tmpByte:
    .byte 0

// Arrived bit number
bitCountInStream:
    .byte 0    

// Arrived data stream
dataStream:
    .byte $00, $00, $00    

// We store the jport because we dont want follow the changes until we finished
jportValue:
    .byte $00    

lastJoySync:
    .byte 0 // 0 Nothing 1: Up 2: down    

// Welcome message
msg:    .text  "connect the arduino and wait"
   


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                       C O D E                                                           //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


start:
        jsr initScreen
        jsr printWelcomeMessage

logic:
        lda JPORT2
        sta jportValue
        jsr checkJoyInput

checkIsPrintNeeded:
        lda isRefreshNeeded
        cmp #1
        bne logic        
        jsr removeWelcomeMessageFromScreen

fillCurrentNumberData:
                
        lda currentNumber+3
        sta convertNumber+3
        lda currentNumber+2
        sta convertNumber+2
        lda currentNumber+1
        sta convertNumber+1
        lda currentNumber+0
        sta convertNumber+0

        jsr hex2dec

truncateNeedRefresh:
        lda #0
        sta isRefreshNeeded

drawScreen:
        jsr printPetsciiBitcointLogo
        jsr printPetsciiNumbers        
        jsr printPetsciiUpDownArrow

        jmp logic



/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                S U B R U T I N E S                                                      //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////




//*****************************************************************//
// Hex number 2 decimal number
// By: https://codebase64.org/doku.php?id=base:32_bit_hexadecimal_to_decimal_conversion
//*****************************************************************//

hex2dec:

        ldx #0
l1:      
        jsr div10
        sta decimalNumber,x
        inx
        cpx #10
        bne l1
        jmp restoreCurrentNumber
div10:
        ldy #32        
        lda #0
        lda #0
        clc
l2:      
        rol
        cmp #10
        bcc skip
        sbc #10
skip:    
        rol convertNumber+3
        rol convertNumber+2
        rol convertNumber+1
        rol convertNumber
        dey
        bpl l2


restoreCurrentNumber:
 
        rts


//*****************************************************************//
// Screen initialize after startup
//*****************************************************************//
initScreen:
        lda #0
        sta SCREEN_COLOR
        lda #2
        sta BORDER_COLOR

colorizeScreen:
// Load text color informations to ram
// By: http://petscii.krissz.hu/
        lda #$00
        sta $fb
        sta $fd
        sta $f7

        lda #$28
        sta $fc

        lda #$04
        sta $fe

        lda #$00
        sta $f9
        lda #$5c
        sta $fa

        lda #$d8
        sta $f8

        ldx #$00
        ldy #$00
        lda ($fb),y
        sta ($fd),y
        lda ($f9),y
        sta ($f7),y
        iny
        bne *-9

        inc $fc
        inc $fe
        inc $fa
        inc $f8

        inx
        cpx #$04
        bne *-24

        cls($20)
        rts

//*****************************************************************//
// Print welcome message after startup
//*****************************************************************//

printWelcomeMessage:
        ldx #0
welcomeTextLoop:   
        lda msg,x
        sta WELCOME_MESSAGE_START,x
        inx
        cpx #28
        bne welcomeTextLoop
        rts

//*****************************************************************//
// Remove welcome message from screen
//*****************************************************************//

removeWelcomeMessageFromScreen:        
        ldx #0
        lda #$20
clearLine:   
        sta WELCOME_MESSAGE_START,x
        inx
        cpx #28
        bne clearLine
        lda #0
        sta BORDER_COLOR
        rts


//*****************************************************************//
// Print subrutin for petscii
//*****************************************************************//
print:
        ldx #0
        lda #0
        sta charactersInCurrentLine
        
loop:
        lda (ZEROPAGE_FA,x)
        cmp #0
        beq checkNextline
        inc charactersInCurrentLine
        ldy #0
        sta (ZEROPAGE_0005),y
        inc ZEROPAGE_0005
        clc
        inc ZEROPAGE_FA
        bcc loop
        inc ZEROPAGE_FB
        jmp loop

checkNextline: 
        clc
        lda #41
        sbc charactersInCurrentLine
        sta charactersInCurrentLine
        clc
        lda ZEROPAGE_0005
        adc charactersInCurrentLine
        sta ZEROPAGE_0005
        bcc nextLine
        inc ZEROPAGE_0006

nextLine:  
        clc
        inc ZEROPAGE_FA
        bcc nextLineCmp
        inc ZEROPAGE_FB
    
nextLineCmp:    
        lda (ZEROPAGE_FA,x)
        cmp #0
        beq done

        lda #0
        sta charactersInCurrentLine
        jmp loop
done:
        rts


//*****************************************************************//
// Store the datastream if enought bit arrived
//*****************************************************************//
storeDataStreamValuesIfNeeded:

        lda bitCountInStream
        cmp #24
        beq store_datastream_byte_3
        cmp #16
        beq store_datastream_byte_2
        cmp #8
        beq store_datastream_byte_1
        rts

store_datastream_byte_3:
        lda tmpByte
        sta dataStream+2

        lda currentNumber
        sta lastNumber
        lda currentNumber+1
        sta lastNumber+1
        lda currentNumber+2
        sta lastNumber+2   
        lda currentNumber+3
        sta lastNumber+3

        lda dataStream
        sta currentNumber+1

        lda dataStream+1
        sta currentNumber+2

        lda dataStream+2
        sta currentNumber+3

        lda #1
        sta isRefreshNeeded

        rts
        
store_datastream_byte_2:
        lda tmpByte
        sta dataStream+1
        lda #0
        sta tmpByte
        rts
store_datastream_byte_1:
        lda tmpByte
        sta dataStream
        lda #0
        sta tmpByte
        rts
    


//*****************************************************************//
// Parse joystick input
//*****************************************************************//
checkJoyInput:
check_joy_up:
        lda jportValue
        and #UP
        bne check_joy_left
        
        // Now we know up is pressed
        lda jportValue
        and #LEFT
        beq start_new_stream

        lda lastJoySync
        cmp #2
        beq check_joy_fire
        rts

check_joy_left:
        lda jportValue
        and #LEFT
        jmp done_joy_check

        lda lastJoySync
        cmp #1
        beq check_joy_fire
        rts


start_new_stream:
        jsr startNewStream 
        rts

check_joy_fire:

        inc lastJoySync
        lda lastJoySync
        cmp #3
        bne do_check_joy_fire
        lda #1
        sta lastJoySync

do_check_joy_fire:    

        inc bitCountInStream
    // A biteket majd szamolgatni kell!


        lda jportValue
        and #FIRE
        beq input_one
        // Input zero
        asl tmpByte
        jsr storeDataStreamValuesIfNeeded
        rts

input_one:
        asl tmpByte
        inc tmpByte

done_joy_check:
        rts

//*****************************************************************//
// Truncate datastream
//*****************************************************************//

startNewStream:
    lda #0
    sta dataStream
    sta dataStream+1
    sta dataStream+2
    sta bitCountInStream
    sta tmpByte
    lda #2
    sta lastJoySync
    rts


//*****************************************************************//
// Load to $fa and $fb the requested number's bytes
//*****************************************************************//
loadNumberLabelForZeroPage:
        lda checkDigitForDraw

digit1:
        cmp #1
        bne digit2
        lda #<num1 
        sta ZEROPAGE_FA 
        lda #>num1
        sta ZEROPAGE_FB
        rts
digit2:
        cmp #2
        bne digit3
        lda #<num2
        sta ZEROPAGE_FA 
        lda #>num2
        sta ZEROPAGE_FB
        rts
digit3:
        cmp #3
        bne digit4
        lda #<num3 
        sta ZEROPAGE_FA 
        lda #>num3
        sta ZEROPAGE_FB
        rts
digit4:
        cmp #4
        bne digit5
        lda #<num4 
        sta ZEROPAGE_FA 
        lda #>num4
        sta ZEROPAGE_FB
        rts       
digit5:
        cmp #5
        bne digit6
        lda #<num5 
        sta ZEROPAGE_FA 
        lda #>num5
        sta ZEROPAGE_FB
        rts
digit6:
        cmp #6
        bne digit7
        lda #<num6 
        sta ZEROPAGE_FA 
        lda #>num6
        sta ZEROPAGE_FB
        rts
digit7:
        cmp #7
        bne digit8
        lda #<num7 
        sta ZEROPAGE_FA 
        lda #>num7
        sta ZEROPAGE_FB
        rts    
digit8:
        cmp #8
        bne digit9
        lda #<num8 
        sta ZEROPAGE_FA 
        lda #>num8
        sta ZEROPAGE_FB
        rts    
digit9:
        cmp #9
        bne digit0
        lda #<num9 
        sta ZEROPAGE_FA 
        lda #>num9
        sta ZEROPAGE_FB
        rts    
digit0:
        lda #<num0 
        sta ZEROPAGE_FA 
        lda #>num0
        sta ZEROPAGE_FB
        rts    
    

//*****************************************************************//
// Load to $fa and $fb the requested number's bytes
//*****************************************************************//

printPetsciiUpDownArrow:
        lda arrow

        cmp #0
        beq checkFirstByteForArrow
        cmp #1
        beq upArrow
        cmp #2 
        beq downArrow
        rts

upArrow:
        lda #$E0
        sta arrowCharacters
        lda #$20
        sta arrowCharacters+1
        jmp drawArrow
downArrow:
        lda #$20
        sta arrowCharacters
        lda #$E0
        sta arrowCharacters+1

drawArrow:
        lda arrowCharacters
        sta UP_ARROW_START+28
        sta UP_ARROW_START+40+27
        sta UP_ARROW_START+40+28
        sta UP_ARROW_START+40+29
        sta UP_ARROW_START+80+26
        sta UP_ARROW_START+80+27
        sta UP_ARROW_START+80+28
        sta UP_ARROW_START+80+29
        sta UP_ARROW_START+80+30
        
        lda arrowCharacters+1
        sta DOWN_ARROW_START+26
        sta DOWN_ARROW_START+27
        sta DOWN_ARROW_START+28
        sta DOWN_ARROW_START+29
        sta DOWN_ARROW_START+30        

        sta DOWN_ARROW_START+40+27
        sta DOWN_ARROW_START+40+28
        sta DOWN_ARROW_START+40+29

        sta DOWN_ARROW_START+80+28   
backToLogic:              
        rts

// Skip first byte because we dont have enought room in the screen :)
checkFirstByteForArrow:
        lda currentNumber+1
        cmp lastNumber+1
        beq checkSecondByteForArrow
        bmi currentArrowDown    // ha az A kisebb vagyis a current kisebb mint a last
        jmp currentArrowUp

checkSecondByteForArrow:
        lda currentNumber+2
        cmp lastNumber+2
        beq checkThirdByteForArrow
        bmi currentArrowDown    // ha az A kisebb vagyis a current kisebb mint a last
        jmp currentArrowUp

checkThirdByteForArrow:
        lda currentNumber+3
        cmp lastNumber+3
        beq backToLogic
        bmi currentArrowDown    // ha az A kisebb vagyis a current kisebb mint a last
        jmp currentArrowUp


currentArrowUp:
        lda #1
        sta arrow
        jmp printPetsciiUpDownArrow

currentArrowDown:
        lda #2
        sta arrow
        jmp printPetsciiUpDownArrow





//*****************************************************************//
// Print petscii bitcoin logo
//*****************************************************************//

printPetsciiBitcointLogo:
        lda #<LOGO_START 
        sta ZEROPAGE_0005 
        lda #>LOGO_START
        sta ZEROPAGE_0006
        lda #0

        lda #<logo 
        sta ZEROPAGE_FA
        lda #>logo
        sta ZEROPAGE_FB
        lda #0

        jsr print


//*****************************************************************//
// Print petscii bitcoin logo
//*****************************************************************//

printPetsciiNumbers:        
        // 5.
        lda #<NUMBERS_FIRST+20 
        sta ZEROPAGE_0005 
        lda #>NUMBERS_FIRST+20
        sta ZEROPAGE_0006
        
        lda decimalNumber+4
        sta checkDigitForDraw
        jsr loadNumberLabelForZeroPage
        jsr print

        // 4.
        lda #<NUMBERS_FIRST+15
        sta ZEROPAGE_0005 
        lda #>NUMBERS_FIRST+15
        sta ZEROPAGE_0006
        
        lda decimalNumber+3
        sta checkDigitForDraw
        jsr loadNumberLabelForZeroPage
        jsr print

        // 3th
        lda #<NUMBERS_FIRST+10 
        sta ZEROPAGE_0005 
        lda #>NUMBERS_FIRST+10
        sta ZEROPAGE_0006
        
        lda decimalNumber+2
        sta checkDigitForDraw
        jsr loadNumberLabelForZeroPage
        jsr print

        // 2th
        lda #<NUMBERS_FIRST+5 
        sta ZEROPAGE_0005 
        lda #>NUMBERS_FIRST+5
        sta ZEROPAGE_0006
        
        lda decimalNumber+1
        sta checkDigitForDraw
        jsr loadNumberLabelForZeroPage
        jsr print

        // 1
        lda #<NUMBERS_FIRST
        sta ZEROPAGE_0005 
        lda #>NUMBERS_FIRST
        sta ZEROPAGE_0006
        
        lda decimalNumber
        sta checkDigitForDraw
        jsr loadNumberLabelForZeroPage
        jsr print

        rts

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                       M A C R O S                                                       //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

.macro cls(clearByte) {
        lda #clearByte
        ldx #0
clsLoop:
        sta SCREEN_RAM,x
        sta SCREEN_RAM+$100,x
        sta SCREEN_RAM+$200,x
        sta SCREEN_RAM+$300,x
        inx
        bne clsLoop
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                         D A T A                                                         //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


// Petscii graphics
*=$7000
graphics:
logo:   .byte $20, $59, $59, $20, $20, $00
	    .byte $E0, $E0, $E0, $E0, $7B, $00
	    .byte $E0, $59, $59, $7C, $E0, $00
	    .byte $E0, $59, $59, $6C, $EC, $00
	    .byte $E0, $E0, $E0, $E0, $20, $00
	    .byte $E0, $59, $59, $7C, $FC, $00
        .byte $E0, $59, $59, $6C, $E0, $00
	    .byte $E0, $E0, $E0, $E0, $7E, $00
	    .byte $20, $59, $47, $20, $20, $00
        .byte $00

num1:   .byte $20, $E0, $E0, $20, $00
        .byte $20, $20, $E0, $20, $00
        .byte $20, $20, $E0, $20, $00
        .byte $20, $20, $E0, $20, $00
        .byte $20, $20, $E0, $20, $00
        .byte $20, $20, $E0, $20, $00  
        .byte $20, $20, $E0, $20, $00
        .byte $00

num2:   .byte $E0, $E0, $E0, $E0, $00
        .byte $20, $20, $20, $E0, $00
        .byte $20, $20, $20, $E0, $00
        .byte $E0, $E0, $E0, $E0, $00
        .byte $E0, $20, $20, $20, $00
        .byte $E0, $20, $20, $20, $00  
        .byte $E0, $E0, $E0, $E0, $00
        .byte $00

num3:   .byte $E0, $E0, $E0, $E0, $00
        .byte $20, $20, $20, $E0, $00
        .byte $20, $20, $20, $E0, $00
        .byte $20, $E0, $E0, $E0, $00
        .byte $20, $20, $20, $E0, $00
        .byte $20, $20, $20, $E0, $00  
        .byte $E0, $E0, $E0, $E0, $00
        .byte $00

num4:   .byte $E0, $20, $20, $E0, $00
        .byte $E0, $20, $20, $E0, $00
        .byte $E0, $20, $20, $E0, $00
        .byte $E0, $E0, $E0, $E0, $00
        .byte $20, $20, $20, $E0, $00
        .byte $20, $20, $20, $E0, $00  
        .byte $20, $20, $20, $E0, $00
        .byte $00

num5:   .byte $E0, $E0, $E0, $E0, $00
        .byte $E0, $20, $20, $20, $00
        .byte $E0, $20, $20, $20, $00
        .byte $E0, $E0, $E0, $E0, $00
        .byte $20, $20, $20, $E0, $00
        .byte $20, $20, $20, $E0, $00  
        .byte $E0, $E0, $E0, $E0, $00
        .byte $00

num6:   .byte $E0, $E0, $E0, $E0, $00
        .byte $E0, $20, $20, $20, $00
        .byte $E0, $20, $20, $20, $00
        .byte $E0, $E0, $E0, $E0, $00
        .byte $E0, $20, $20, $E0, $00
        .byte $E0, $20, $20, $E0, $00  
        .byte $E0, $E0, $E0, $E0, $00
        .byte $00

num7:   .byte $E0, $E0, $E0, $20, $00
        .byte $20, $20, $E0, $20, $00
        .byte $20, $20, $E0, $20, $00
        .byte $20, $20, $E0, $20, $00
        .byte $20, $20, $E0, $20, $00
        .byte $20, $20, $E0, $20, $00  
        .byte $20, $20, $E0, $20, $00
        .byte $00

num8:   .byte $E0, $E0, $E0, $E0, $00
        .byte $E0, $20, $20, $E0, $00
        .byte $E0, $20, $20, $E0, $00
        .byte $E0, $E0, $E0, $E0, $00
        .byte $E0, $20, $20, $E0, $00
        .byte $E0, $20, $20, $E0, $00  
        .byte $E0, $E0, $E0, $E0, $00
        .byte $00

num9:   .byte $E0, $E0, $E0, $E0, $00
        .byte $E0, $20, $20, $E0, $00
        .byte $E0, $20, $20, $E0, $00
        .byte $E0, $E0, $E0, $E0, $00
        .byte $20, $20, $20, $E0, $00
        .byte $20, $20, $20, $E0, $00  
        .byte $20, $20, $20, $E0, $00
        .byte $00

num0:   .byte $E0, $E0, $E0, $E0, $00
        .byte $E0, $20, $20, $E0, $00
        .byte $E0, $20, $20, $E0, $00
        .byte $E0, $20, $20, $E0, $00
        .byte $E0, $20, $20, $E0, $00
        .byte $E0, $20, $20, $E0, $00  
        .byte $E0, $E0, $E0, $E0, $00
        .byte $00


// Colors
*=$5c00
	.byte	$07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07
	.byte	$07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07
	.byte	$07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07
	.byte	$07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07
	.byte	$07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $0E, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07
	.byte	$07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07
	.byte	$07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07
	.byte	$07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07
	.byte	$07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07
	.byte	$07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07
    .byte	$01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
	.byte	$01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
	.byte	$01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05
	.byte	$01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05
	.byte	$01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05
	.byte	$01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
	.byte	$01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02
	.byte	$01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02
	.byte	$01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02
	.byte	$01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
	.byte	$01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
	.byte	$01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
	.byte	$01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
	.byte	$01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
	.byte	$01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01

