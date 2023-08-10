; Author: Alfredo Rodríguez Sanfrutos, "alfre"
; Based on the code from '3D Monster Maze', developed by Malcolm Evans
; 	Code disassembly can be found in: http://www.fruitcake.plus.com/Sinclair/ZX81/Disassemblies/MonsterMaze.htm

.nolist
#include "ti83plus.inc"
#include "app.inc"

.list
.defpage 0,"3DMM    "

; ;====== Header ===========================================================
; .org   4000h
;    ; Master Field
;    .DB   $80, $0F, 0, 0, 0, 0
;    ; Name
;    .DB   $80, $48, "3DMM    "
;    ; Disable TI splash screen.
;    .DB   $80, $90
;    ; Pages
;    .DB   80h, 81h, 1
;    ; Signing Key ID
;    .DB   80h, 12h, 1, 4
;    ; Date stamp.  Nothing ever checks this, so you can put nothing in it.
;    .DB   03h, 22h, 09h, 00h
;    ; Date stamp signature.  Since nothing ever checks this, there's no
;    ; reason ever to update it.  Or even have data in it.
;    .DB   02h, 00
;    ; Final field
;    .DB   80h, 70h
;====== Code Starts Here ==================================================


; ----------------------------------------------
; MACROS/EQU
; ----------------------------------------------
#define B_CALL(xxxx)	PUSH AF \ PUSH BC \ PUSH DE \ PUSH HL \ RST 28h \ .DW xxxx \ POP HL \ POP DE \ POP BC \ POP AF
#define SETPEN(xx,yy)	PUSH AF \ PUSH BC \ PUSH DE \ PUSH HL \ .DB 21h \ .DB xx \ .DB yy \ LD (PenCol),HL \ POP HL \ POP DE \ POP BC \ POP AF
#define _inittimer  $526c
#define _killtimer  $526f
#define _starttimer $5272
#define _restarttimer   $5275
#define _stoptimer  $5278
#define _waittimer  $527b
#define _checktimer $527e
#define _checktimerrestart  $5281

; DEFINES for game logic
#DEFINE GAME_STARTX 	14
#DEFINE GAME_STARTX_RC	7424
#DEFINE GAME_STARTY		16
#DEFINE GAME_STARTY_RC 	8448

; RAM assigned for screen buffer in TI-OS
SCREEN 		.EQU 	plotsscreen  ; Could be saveSScreen, plotSScreen,appBackUpScreen...

; SCREEN SIZE
SCREEN_W 	.EQU 96
SCREEN_H	.EQU 64

; GAME GUI SIZE
GAME_W 		.EQU 64
GAME_H		.EQU 55
FRAME_W 	.EQU 3
SIZE_S0		.EQU 2 ;2 or 6?
SIZE_S1		.EQU 8
SIZE_S2		.EQU 6
SIZE_S3		.EQU 4
SIZE_S4		.EQU 2
SIZE_S5		.EQU 2
SIZE_S6		.EQU 2

; Maze constants: The code for the wall must have bit 7 set whereas the other codes must have bit 7 reset.
_MW     .EQU  'W'	; Wall.
_MP     .EQU  ' '	; Passageway.
_MR     .EQU  'M' 	; Rex.
_ME     .EQU  'H'	; Exit.
MAZE_W	.EQU  16
MAZE_H	.EQU  18
; FOV		.EQU  90 	; Field of view in degrees


; MEMORY MAP
; ----------
; 
; plotsscreen (768 B): Screen buffer
;
; savesscreen (768 B): //IMAGES - Dinamically moved to RAM for displaying them
;
; appBackUpScreen (768 B): //GAME LOGIC:
MAZE		.EQU	appBackUpScreen	;MAZE		288
SEENMAZE	.EQU	MAZE+288		;SEENMAZE	21
PX			.EQU	SEENMAZE+21		;PX			1
PY			.EQU	PX+1			;PY			1
PD			.EQU	PY+1			;PD			1
PWD			.EQU	PD+1			;PWD		1
RX			.EQU	PWD+1			;RX			1
RY			.EQU	RX+1			;RY			1
SCORE		.EQU	RY+1			;SCORE		2
GAMESTATE	.EQU	SCORE+2			;GAMESTATE	1
GAMECOUNTER	.EQU	GAMESTATE+1		;GAMECOUNTER	1
GAMEFLAGS	.EQU	GAMECOUNTER+1	;GAMEFLAGS	2
STATUSTIMER	.EQU	GAMEFLAGS+2		;STATUSTIMER	2
TEMPDISTREX	.EQU	STATUSTIMER+2	;TEMPDISTREX	2
DISTANCETOREX	.EQU	TEMPDISTREX+2	;DISTTOREX 	2
RANDDATA	.EQU	DISTANCETOREX+2		;RANDDATA	1
KEYPRESS	.EQU	RANDDATA+1		;KEYPRESS	2
TEXTBUFFER	.EQU	KEYPRESS+2		;TEXTBUFFER 144
MAZEDEBUG	.EQU	TEXTBUFFER+144		;MAZEDEBUG 	38
; RAYCAST VARIABLES:
RENDERFLAGS	.EQU 	MAZEDEBUG+38	; RENDERFLAGS	1 ; Bits: 7bit[0|0|0|0|0|0|0|RAYCAST1/ORIGINAL0]0bit
PDD			.EQU	RENDERFLAGS+1	; PDD 			2
PDX			.EQU	PDD+2			; PDX			2
PDY			.EQU	PDX+2			; PDY			2
CASTINGANGLE .EQU	PDY+2			; CASTINAGNGLE	2
SCREENCOLUMN .EQU	CASTINGANGLE+2 	; SCREENCOLUMN 	1
RAYX		.EQU	SCREENCOLUMN+1 	; RAYX			2
RAYY		.EQU 	RAYX+2			; RAYY			2
COS			.EQU	RAYY+2			; COS			2
SIN			.EQU	COS+2			; SIN			2
TEMPPDX			.EQU	SIN+2			; TEMPPDX			1
TEMPPDY			.EQU	TEMPPDX+1		; TEMPPDY			1
RAYLENGTH		.EQU	TEMPPDY+1		; RAYLENGTH			1
INCANGLEDIV		.EQU	RAYLENGTH+1		; INCANGLEDIV		1
MAINGAMELOOPCOUNT .EQU INCANGLEDIV+1	; MAINGAMELOOPCOUNT	1


; ----------------------------------------------
; CODE
; ----------------------------------------------
;START;START;START;START;START;START;START;START;START;START;START;START;START;START;START;START;START;START;START;START;START
.list
; .ORG userMem - 2 ; $9D95 - 2 = $9D93
; .DB t2ByteTok,tasmCmp ;$BB,$6d			; HEADER for 8xp programs

; ----------------------------------------------
; DEVICE SETUP
; ----------------------------------------------
	RES	5,(IY+0) ; makes the calculator not say 'Done.' when finishing executing the program (reset (i.e. clear) bit 5 of a memory location pointed to by the Index Register IY.)
	BCALL(_RunIndicOff)	; Disable Run (Busy) Indicator
	BCALL(_clrlcdfull)		; Clear screen
	BCALL(_ForceFullScreen)
	BCALL(_DisableApd)
	; Init random data randdata with Refresh register and adding the content of B register (assumming that's random):
	LD A,R
	ADD A,B
	LD (RANDDATA),A


;----------------------------
; Initialization of variables in safeRAM (appBackUpScreen)
;----------------------------
	; CALLOC(appBackUpScreen) - basically to empty flags and buffers like TEXTBUFFER
	LD HL,appBackUpScreen
	BCALL(_BufClr)

; ;DEBUG;DEBUG;DEBUG;DEBUG;DEBUG;DEBUG;DEBUG;DEBUG;DEBUG;DEBUG;DEBUG;DEBUG
	; ; Initialize maze to debug maze from maze_init
	; LD HL,MAZE_INIT
	; LD DE,MAZE
	; LD BC,288
	; LDIR
; ;END;DEBUG;DEBUG;DEBUG;DEBUG;DEBUG;DEBUG;DEBUG;DEBUG;DEBUG;DEBUG;DEBUG;DEBUG

	CALL CLEARTEXTBUFFER

	; ; REX position
	LD A,1;4
	LD (RX),A
	LD A,1;14
	LD (RY),A

	; MAZEDEBUG size ;DEBUG
	LD A,18
	LD (MAZEDEBUG),A
	LD A,16
	LD (MAZEDEBUG+1),A

	; ; ; PLAYER position to southeast
	;PX=1
	LD A,GAME_STARTX
	LD (PX),A
	;PY=16
	LD A,GAME_STARTY
	LD (PY),A

	;Player direction (N,S,W,E):
	;($00=North, $01=West, $02=South, $03=East)
	; Needed for drawing the 3d view
	; ;      N0
	; ;      |
	; ; W1 --+-- E3
	; ;      |
	; ;      S2
	LD A,0
	LD (PD),A
	
	; INIT RAYCASTING DATA
	; LD      BC,GAME_STARTX_RC ; theoretically southeast should be 7424
	; LD      (PDX), BC
	; LD      BC,GAME_STARTY_RC ; theoretically southeast should be 8448
	; LD      (PDY), BC
	; LD      BC,0;HALF;QUARTER+QUARTER;CIRCLE+QUARTER
	; LD      (PDD), BC

	; PWD: ;L4085 - PassageWay Direction for generating maze
	LD A,1
	LD (PWD),A

	; ; REX position
	; LD A,4
	; LD (RX),A
	; LD A,14
	; LD (RY),A

	; SCORE: ; max value is FF (65.535), first byte is low part, second is high ($01,$00 is 1)
	LD A,0
	LD (SCORE),A
	LD (SCORE+1),A

	; GAMESTATE: ; 0=PLAYING, 1=GAMEOVER
	LD A,0
	LD (GAMESTATE),A

	; GAMECOUNTER: ; Increments in each iteration, used for rex position messages
	LD A,0
	LD (GAMECOUNTER),A

	; GAMEFLAGS:  
	; Flags:
	;   Bit 7: 1=The player has been caught.
	;   Bit 6: 1=The player has moved forwards.
	;   Bit 5: 1=The player has not moved and so there is no need to redraw the view of the maze.
	;   Bit 4: 1=The Exit is visible.
	;   Bit 3: 1=Rex has moved.
	;   Bit 2: 1=Rex has moved into a new location.
	;   Bit 1: 1=Rex has his left foot forward, 0=Rex has his right foot forward.
	;   Bit 0: Controls the movement speed of Rex. It combines with bits 1 and 2 to form a 3 bit counter. Bit 0 will be forced to 1
	;          when the played is moving thereby forcing Rex to take quicker steps.
	LD A,2
	LD (GAMEFLAGS),A

	; STATUSTIMER:;L408B ; Holds a timeout used to determine when to clear the status message area (maximum value=$08, $00 means countdown expired so clear the status message).
	LD A,8
	LD (STATUSTIMER),A

	; TEMPDISTREX: ;L408C ; Temporary store used when the view is being drawn to determine the distance to Rex ($00=Rex is at the same location as the player).
	LD A,1
	LD (TEMPDISTREX),A

	; KEYPRESS: ;L408A ; Holds the key press INKEY$ code, used by the game loop
	LD A,2
	LD (KEYPRESS),A

	; DISTANCETOREX: ;L408D ; Holds the distance Rex is away from the player when in direct line of site. It is used to determine the sprite to display for Rex ($00=Rex at the same location as the player, $06=Rex is beyond visible range).
	LD A,7
	LD (DISTANCETOREX),A

	; RANDDATA:
	LD A,%11010100
	LD (RANDDATA),A

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Select original rendering or raycasting rendering
SELECT_MODE:
	BCALL(_ClrLCD)
	SETPEN(0,16)
    LD  HL,CHOOSERENDER
	CALL VPutS
	
	SETPEN(16,32)
    LD  HL,ORIGINAL
	CALL VPutS

	SETPEN(16,48)
    LD  HL,RAYCAST
	CALL VPutS

GET_MODE:
	BCALL(_GetKey)
	CP kMode
    JR Z,SET_ORIGINAL
    CP kDel
    JR Z,SET_RAYCAST
    JR GET_MODE    ; If any other key was pressed, redo _GetKey.

SET_ORIGINAL:
	LD HL,RENDERFLAGS
	RES 0,(HL)
	JP STARTINTRO
SET_RAYCAST:
	LD HL,RENDERFLAGS
	SET 0,(HL)
	JP STARTINTRO
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;INTRO START
STARTINTRO:
	BCALL(_ClrLCD)
	;PRINT INTRO TEXTS
    LD  E,10
    LD  D,56
    LD  HL,COPYRIGHT
    CALL DisplayImage ;B_CALL(_DisplayImage)
    SETPEN(19,57)
    LD  HL,TXT_COPYRIGHT
	CALL VPutS
    SETPEN((SCREEN_W/2)-26, (SCREEN_H/2)-8)
    LD  HL,txt_intro1
    CALL VPutS

; Wait 3s if no key is pressed
	LD E,6
INTRO_WAIT:
	LD B,255
    CALL WAIT_HALFSEC
	BCALL(_GetCSC)
	CP 0
	JR NZ,INTRO_START
	DEC E
	JR Z,INTRO_WAITEND
	JP INTRO_WAIT

INTRO_WAITEND:
    SETPEN((SCREEN_W/2)-48, (SCREEN_H/2))
    LD  HL,txt_intro2
    CALL VPutS
    ; WAIT USER INPUT (Blocking)
    B_CALL(_GetKey)

INTRO_START:
;     ; CLS AND DISPLAY RINGMASTER
    BCALL(_clrlcdfull)
	LD  E,0
    LD  D,0
	LD HL,RINGMASTER
	CALL DisplayImage ;B_CALL(_DisplayImage)

    ; DISPLAY SCROLLING INTRO TEXT 'ROLL UP, ROLL UP...'
    LD A,0
    LD HL,txt_ringmaster1
    LD BC,18
INTRO_DISPLAY:
    PUSH HL
    LD E,0
    LD D,0
    CP A,38
    JP Z,INTRO_RMHAT
    JP INTROCONT
INTRO_RMHAT:
    LD HL,Ringmasterhat
	PUSH AF
	CALL DisplayImage ;B_CALL(_DisplayImage)
	POP AF
INTROCONT:
    POP HL
	PUSH HL
	PUSH BC
	PUSH AF
	CALL WRITESCREENTEXT
	POP AF
	POP BC
	POP HL

    ADD HL,BC
    
    ; PUSH BC
    ; LD BC,255
    ; CALL WAIT_HALFSEC
    ; ;CALL WAIT_HALFSEC
    ; POP BC
    INC A
    CP A,39        ; number of lines of text
    JP NZ,INTRO_DISPLAY

INTRO_END:
	BCALL(_GetKey)
	CP     kMode
    JR     Z, INSTRUCTIONS
    CP     kDel
    JR     Z, INTRO_QUIT
    CP     kClear
    JR     Z, START_GAME ; start game
    JR     INTRO_END    ; If any other key was pressed, redo _GetKey.

INTRO_QUIT:
	JP END

;;;;;;;;;INTRO END

INSTRUCTIONS:
	LD  E,0
    LD  D,0
	LD HL,Ringmaster
	CALL DisplayImage ;B_CALL(_DisplayImage)
	; Clear old text
	CALL CLRTEXTZONE
	; Display instructions
	LD HL,CONTROLS
	LD A,38
CONTROLSLOOP:
	DEC A
	PUSH AF
	PUSH HL
	CALL WRITESCREENTEXT
	POP HL
	LD BC,18
	ADD HL,BC
	POP AF
	CP A,0
	JP NZ,CONTROLSLOOP

START_GAME:
	; Text: The mists of time will pass over you...
	; Clear old text
	CALL CLRTEXTZONE
RESTART_GAME:
	BCALL(_ClrLCD)
	LD  E,0
    LD  D,0
	LD HL,Ringmaster
	CALL DisplayImage ;B_CALL(_DisplayImage)

	LD HL,txt_ringmaster2
	LD A,7
MISTSOFTIMELOOP:
	DEC A
	PUSH AF
	PUSH HL
	CALL WRITESCREENTEXT
	POP HL
	LD BC,18
	ADD HL,BC
	POP AF
	CP A,0
	JP NZ,MISTSOFTIMELOOP

	PUSH HL

	LD  E,0
    LD  D,0
	LD HL,Ringmasterhat
	CALL DisplayImage ;B_CALL(_DisplayImage)

	; Print last line of 'mists of time' text
	; This is to avoid the DisplayImage print empty pixels next to ringmasterhat image
	; since it's actually 27pixels wide but it doesnt allow widths which aren't 2^WIDTH
	POP HL
	CALL WRITESCREENTEXT


	LD BC,$FFFF
	CALL WAIT_HALFSEC
	CALL WAIT_HALFSEC
	; CALL WAIT_HALFSEC
	; CALL WAIT_HALFSEC

;;;;;;;;;FULL INTRO END

	; ; Generate the maze
	CALL GENERATEMAZE

; -------------------------
; Display Initial Viewpoint
; -------------------------
DISPINITIALVIEW:
	; Clear screen
	CALL CLEAR3DVIEW
	; Print SCORE text ...
	; 235 CLS
	; 240 SLOW                                              ; Exit from the 'mists of time'.
	; 250 PRINT AT 9,27;"SCORE"

	; Restart player variables
	; 260 POKE 16514,255                                    ; Set the low byte of the player's start position, which is at the far south-east of the maze.
	; 270 POKE 16515,70                                     ; Set the high byte of the player's start position, which is at the far south-east of the maze.
	LD A,GAME_STARTX
	LD (PX),A
	LD A,GAME_STARTY
	LD (PY),A
	; Set the player facing west.
	LD A,0
	LD (PD),A
	LD BC,GAME_STARTX_RC
	LD (PDX), BC
	LD BC,GAME_STARTY_RC ;DEBUG
	LD (PDY), BC
	LD BC,0
	LD (PDD), BC

	; 280 POKE 16519,0                                      ; Clear all program flags.
	LD A,0
	LD (GAMEFLAGS),A
	; 290 POKE 16523,8                                      ; Set the countdown to when the message status area will be cleared (which will initially be showing "REX LIES IN WAIT").
	LD A,8
	LD (STATUSTIMER),A

	; 310 LET A=USR 18288                                   ; Display 3D view of the maze from the player's position.
	CALL DRAW3DVIEW
	CALL DISPSCREEN
	; 320 IF INKEY$="" THEN GOTO 320                        ; Wait for a key to be pressed.
	BCALL(_GetKey)

; ---------------
; Game Loop Cycle 
; ---------------
GAMELOOP:
	; Check if 2nd+MODE(=QUIT) has been pressed. If yes, QUIT game
	CALL GETKD
	BIT 5,B	; Bit 5 = MODE
	JP NZ,DONTQUIT
	BIT 4,B ; Bit 4 = 2ND
	JR NZ, DONTQUIT
	JP ACCEPTREQ
DONTQUIT:
	; 330 POKE 17901,INT (RND*128)				; Set the next character to display in the Exit pattern. -> NOT APPLICABLE
	; 340 POKE 16522,CODE INKEY$				; Store the current key press code, which will be checked by the game loop routine.
	; CALL GETKD
	LD A,B
	LD (KEYPRESS),A
	
	; 350 LET A=USR 18224						; Run a cycle of the game loop routine, which will process the current key press and will redraw the view.
	CALL GAMELOOPACTIONS

	; 360 IF PEEK 16519>=128 THEN GOTO 5000		; Jump if the player has been caught.
	LD A,(GAMEFLAGS)
	CP A,%10000000;128
	JP NC,GAMEOVER

	; 370 FOR N=0 TO 5							; Perform a delay that dictates the speed of the game.
	; 380 NEXT N
; 	LD B,255
; DELAYLOOP:
; 	DJNZ DELAYLOOP	;DEBUG
	LD B,120
	CALL WAIT_HALFSEC

	; 390 IF PEEK (PEEK 16514+17920)<>45 THEN GOTO 330      ; Loop back if the player is not at the Exit.
	LD A,(PX)
	LD D,A
	LD A,(PY)
	LD E,A
	CALL GET_POS
	LD A,_ME
	CP A,L
	JP NZ,GAMELOOP

; -----------------------
; Player Reached the Exit
; -----------------------
PLAYER_EXIT:
	;Print escape text
	; SETPEN(10,10)
	LD H,0
	LD L,55
	LD (PenCol),HL

	LD B,10
	LD C,0
	LD HL,TXT_ESCAPE
ESCAPETEXT_LOOP:
	PUSH AF
	PUSH BC
	PUSH HL
    CALL VPutS
	POP HL
	POP BC
	POP AF
	LD D,0
	LD E,12
	ADD HL,DE

	LD A,C
	LD E,6
	ADD A,E
	LD C,A

	PUSH HL
	LD H,C
	LD L,55
	LD (PenCol),HL
	POP HL

	DJNZ ESCAPETEXT_LOOP

	SETPEN(55,18)
	LD HL,(SCORE)
	CALL vDispHL

	LD B,255
	CALL WAIT_HALFSEC
	CALL WAIT_HALFSEC
	CALL WAIT_HALFSEC
	CALL WAIT_HALFSEC
	CALL WAIT_HALFSEC
	CALL WAIT_HALFSEC
	CALL WAIT_HALFSEC
	CALL WAIT_HALFSEC

	; 400 FOR N=0 TO 30                                     ; The Exit pattern shifts through 30 characters.
	; 405 POKE 17901,INT (128*RND)                          ; Select the next random character to display in the Exit pattern.
	; 410 LET A=USR 18224                                   ; Run a cycle of the game loop routine, which will display the next Exit pattern.
	;CALL GAMELOOPACTIONS
	LD DE,200 ; DEBUG
	CALL SCOREADD
	; 420 FOR M=0 TO 3                                      ; Perform a delay that dictates the speed of the Exit pattern.
	; 425 NEXT M
	; 430 NEXT N                                            ; Repeat for all characters of the Exit pattern.

	; 440 CLS
	; 450 GOTO 2520 ; MISTS OF TIME OPENING TEXT
	CALL CLEARTEXTBUFFER
	JP RESTART_GAME

; ----------------------
; Player Has Been Caught
; ----------------------
GAMEOVER:
	;BCALL(_ClrLCD) ;DEBUG
	; 5000 LET A=PEEK 16520                                 ; Fetch the offset within the maze of Rex.
	; 5010 IF A>176 AND (A-16*INT (A/16))>9 THEN            ; If Rex is within the 5 locations in an west-east or north-south direction of the player's
	;      LET A=USR 17683                                  ; start location then move Rex to the first free location within the north of the maze.
	CALL INSERTREX
	
	; 5020 IF INKEY$="A" THEN GOTO 5050                     ; Jump if 'STOP' pressed to request to end the game.
	; 5030 IF INKEY$="C" THEN GOTO 5150                     ; Jump if 'CONT' pressed to restart the current maze.
	; 5040 GOTO 5020                                        ; Loop back until a key has been pressed.
	BCALL(_GetKey)
	CP kClear ;CONT - RESTART CURRENT MAZE
	JP Z,RESETSCORE
	CP kMode ;STOP - REQUESTEND
	JP Z,REQUESTEND
	JP GAMEOVER

; -----------------------
; Request to End the Game
; -----------------------
REQUESTEND:
	; 5050 CLS
	BCALL(_ClrLCD)
	; 5060 PRINT AT 10,10;"APPEAL"
	SETPEN(10,10)
    LD  HL,TXT_APPEAL
    CALL VPutS
	LD B,255
	CALL WAIT_HALFSEC

; 	;DEBUG: Prevent crash when in raycast mode - probably mem overflow. crashes when req is accepted and game exits
; 	LD A,(RENDERFLAGS)
; 	BIT 0,A
; 	JP Z,CONTINUECHECKREQ
; 	JP REJECTEDREQ
; CONTINUECHECKREQ:
; 	;ENDDEBUG

	; 5070 IF RND>.5 THEN GOTO 5120                         ; Jump if the request has been rejected.
	LD B,10
	CALL RANDOMAR
	CP A,5				; Probably should modify it to be 60% reject and 40% accept >:)
	JP NC,REJECTEDREQ

	; The request to end the game has been accepted.
	; 5080 PRINT AT 12,10;"ACCEPTED"
ACCEPTREQ:
	SETPEN(10,20)
    LD  HL,TXT_ACCEPTED
    CALL VPutS
	; 5090 FOR N=0 TO 40                                    ; Perform a short delay.
	; 5100 NEXT N
	LD B,250
	CALL WAIT_HALFSEC
	LD B,250
	CALL WAIT_HALFSEC
	; 5110 NEW                                              ; Reset the computer.
	JP END

	; The request to end the game has been rejected.
REJECTEDREQ:
	; 5120 PRINT AT 12,10;"REJECTED"
	SETPEN(10,20)
    LD  HL,TXT_REJECTED
    CALL VPutS
	; 5130 FOR N=0 TO 30                                    ; Perform a short delay.
	; 5140 NEXT N
	LD B,250
	CALL WAIT_HALFSEC
	CALL WAIT_HALFSEC


	; Restart the current maze.                                   
	; ---------------
	; Reset the Score ; Reset the score to "0000".
	; ---------------
RESETSCORE:
	; 6000 POKE 17718,28                                    ; '0'.
	; 6010 POKE 17719,28                                    ; '0'.
	; 6020 POKE 17720,28                                    ; '0'.
	; 6030 POKE 17721,28                                    ; '0'.
	LD A,0
	LD (SCORE+0),A
	LD (SCORE+1),A
	; 6040 RETURN

	; 5160 GOTO 235                                         ; Jump to display the initial 3D viewpoint and re-enter the game loop.
	JP DISPINITIALVIEW

;;;;;;;;;;;;;;;;;;;;;

END:
	BCALL(_clrlcdfull)

	LD HL,savesscreen
	BCALL(_BufClr)
	LD HL,plotsscreen
	BCALL(_BufClr)
	LD HL,appBackUpScreen
	BCALL(_BufClr)

	BCALL(_EnableApd)

	; Following TI Documentation, exit app:
	BCALL(_ReloadAppEntryVecs) ; load the monitor vectors to App loader
	BCALL(_JForceCmdNoChar) ; exit the app and initiate home screen
	; END PROGRAM
	RET
	
.end
;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END
;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END;END

; ----------------------------------------------
; AUXILIARY SUBROUTINES
; ----------------------------------------------

; ---------------
; Game Loop Cycle Actions ; line 1111 of the disassembly
; ---------------
GAMELOOPACTIONS:
	CALL CLEAR3DVIEW ;DEBUG

;L4D6C: Animate Exit Pattern and Draw 3D View
	LD   A,(DISTANCETOREX);L408D)		; Fetch the frame display index for Rex, i.e. the distance from the player.
	CP   $00							; Has Rex caught the player?
	JP   Z,ATMPTMOVREX;L4770			; Jump if so to attempt to move Rex and draw the 3D view.
	BIT  4,(HL)							; Is the Exit visible?
	CALL NZ,INEXIT;L4B2F				; If so then draw the Exit pattern, causing it to be drawn twice as fast as the player can move.
	;JP   ATMPTMOVREX;L4770				; Jump to attempt to move Rex and draw the 3D view.

	LD A,(RENDERFLAGS)
	BIT 0,A
	JP Z,NORMALLOOP
	; Raycast extra actions
	; ---- Main gameloop only executes once every X iterations of the raycast move loop
	LD A,(MAINGAMELOOPCOUNT)
	INC A
	LD (MAINGAMELOOPCOUNT),A
	LD A,(KEYPRESS)
	LD B,A
	CALL MOVEPLAYER_RC

	LD A,(MAINGAMELOOPCOUNT)
	CP A,5
	JP NZ,GAMELOOP

	JP RAYCASTMOVED
NORMALLOOP:	
	; Move player based on key pressed (or not)
	LD A,(KEYPRESS)
	CALL MOVEPLAYER ; Moves the player and sets bits of flags
	JP ATMPTMOVREX
	
RAYCASTMOVED:
	LD A,0
	LD (MAINGAMELOOPCOUNT),A
	; -------------------
	; Attempt to Move Rex L4770
	; -------------------
	; The following actions are performed:
	; - If the player is at the Exit then
	;   - Draw the Exit pattern
	; - Else
	;   - Attempt to move Rex towards the player
	;   - If Rex has caught the player then
	;     - Draw screen showing Rex has caught the player
	;   - Else
	;     - If the player moved forwards but there was a wall ahead then
	;       - Attempt to draw Rex on top of the existing 3D view
	;     - Else
	;       - Draw the 3D view
ATMPTMOVREX:
	LD A,(PX)		; Fetch the location of the player.
	LD D,A
	LD A,(PY)
	LD E,A

	CALL GET_POS ; Fetch the contents of the player's location. -> L
	LD A,L ; Copy return value to A, for comparing it to _ME
	CP A,_ME
	JP Z,INEXIT;L4B2F	; Jump if player at exit

	LD A,0
	LD (TEMPDISTREX),A 	; Assume Rex is at the same location as the player. (L408C)

	LD A,7
    LD (DISTANCETOREX),A		; Set the frame display index for Rex such that Rex is beyond the visible range.

	CALL TRYMOVEREX;L4A52		; Attempt to move Rex.
    CALL CHECKREX;L4A34		; Has Rex caught the player? This call only returns if not.

	; Joins here to check whether to move the player and hence redraw the view of the maze.
CHECKMOVEPLAYER:;L47B9:
	LD A,(PX)			; Fetch the location of the player.
	LD H,A
	LD A,(PY)
	LD L,A

	PUSH HL
	LD HL,GAMEFLAGS		; Point at the flags byte.
	BIT 5,(HL)			; Did the player move and so the view of the maze needs to be redrawn?
	POP HL 				; Extract location of player
	JP NZ,GETDISTANCETOREX;L4ADF		; Jump if not to determine the distance to Rex and to display him (on top of the current view).
	; JP GETDISTANCETOREX ;DEBUG para que REX se intente mostrar siempre

	CALL DRAWREX;L4AF4

	; The wall face has been drawn.
	; LD   A,(L4087)                          ; Fetch the flags byte.
	; BIT  4,A                                ; Is the Exit visible?
	; CALL NZ,L4B2F                           ; If so then draw the Exit pattern.
	; JP   L4987                              ; Jump to draw any visible left and right passageway wall faces.

	RET

; When player is at the exit, display Exit pattern ; NOT USED
INEXIT:;L4B2F
	RET

; -------------------------------------------
; Determine Whether Rex Has Caught the Player
; -------------------------------------------
; Destroys: HL,BC,AF
CHECKREX:;L4A34
	; Fetch the location of the player. H=X,L=Y
	LD 	A,(PX)
	LD 	H,A
	LD 	A,(PY)
	LD 	L,A
	
    ; Is Rex at the same location as the player?
	LD 	A,(RX)
	CP 	A,H ; Check if X same in P and R
	RET NZ  ; Return if not.

	LD 	A,(RY)
	CP 	A,L ; Check if Y same in P and R
	RET NZ  ; Return if not.

	; Rex is at the same location as the player but must have taken a step forward in order to catch the player.
	POP  AF 				; Discard the return address - for not displaying the score again on top of final screen
	LD 	A,$00				; Select to show frame 0 for Rex, i.e. the player has been caught frame.
	LD 	(DISTANCETOREX),A

	LD 	A,(GAMEFLAGS)		; Fetch the flags byte.
	BIT 1,A					; Has Rex taken a right step?
	JP 	Z,DRAWREX;L4AF4			; Jump ahead if not to draw Rex.

	; Rex has taken a right step within this location and so has caught the player.
	SET  7,A                                ; Signal the player has been caught.
	LD   (GAMEFLAGS),A
	
	JP   DRAWREX;L4AF4                              ; Jump ahead to draw Rex.


; -------------------
; Attempt to Move Rex
; -------------------
; This routine attempts to move Rex towards the player. The difference between the player's location and Rex's
; location is computed in both the north-south axis and the west-east axis. An attempt is made to move Rex along the
; axis with the largest delta, but if this is not possible then an attempt is made to move him along the other axis.
;
; Rex takes two steps per location - first he moves his left foot forward and then he moves his right foot forward.
; Rex moves at two speeds:
; - It takes 4 cycles for Rex to move through a location when the player has not moved.
; - It takes 2 cycles for Rex to move through a location when the player has just moved.
;
; Flags ($4087):
;
; Bit: 2 1 0
;      -----
;      0 0 0  Right foot forward
;      0 0 1  Right foot forward
;      0 1 0  Left  foot forward
;      0 1 1  Left  foot forward
;      1 0 0  Right foot forward   Rex moved to a new location. The 3 bits are reset to 000.
;
; Bit 1 is used to determine whether to draw Rex with his left or right foot forward.
; The player is caught when Rex moves into the same location and has his left foot forward.
TRYMOVEREX:;L4A52
	LD   HL,GAMEFLAGS;L4087                           ; Point at the flags byte.
	LD   A,(HL)
	BIT  5,A                                ; Did the player move?
	JR   NZ,PNOTMOVED;L4A5C                           ; Jump if not.

	; The player moved. Set Rex on his right step so that the move will place him on his left step, which will
	; either be half way through the current location or a move to a new location.
	SET  0,A                                ; Set Rex to be on his right step.

PNOTMOVED:;L4A5C:
	INC  A                                  ; Increment the step count for Rex.

	BIT  2,A                                ; Has Rex moved into a new location?
	JR   NZ,REXMOVED;L4A63                           ; Jump if so.

	; Res is still within the same location.
	LD   (HL),A                             ; Store the new flags.
	RET

	; Rex has moved to a new location.
REXMOVED:;L4A63:
	AND  $F0                                ; Mask off the previous Rex movement bits.
	LD   (HL),A                             ; Store the new flags.

; Attempt to move Rex towards the player
; --------------------------------------
; Extract the player's and Rex's north-south and west-east positions.
	; B = P X
	; C = R X
	; D = P Y
	; E = R Y
	LD A,(PX)
	LD B,A
	LD A,(RX)
	LD C,A
	LD A,(PY)
	LD D,A
	LD A,(RY)
	LD E,A
	PUSH BC
	PUSH DE

; Compute the west-east delta.
	LD   A,B						; Fetch the player's west-east position. PX
	CP   C							; Compare to Rex's west-east position. RX
	JR   NC,PEASTOFREX;L4A88		; Jump if the player is east of Rex.

; The player is west of Rex.
	LD   A,C                                ; Fetch the Rex's west-east position.
	SUB  B                                  ; Determine how the west-east delta.
	JR   SAVEXDELTA;L4A89                   ; Jump ahead to continue.

; The player is east of Rex.
PEASTOFREX:;L4A88:  
	SUB  C                                  ; Determine the west-east delta.

SAVEXDELTA;L4A89:  
	LD   C,A                                ; Save the west-east delta.

; Compute the north-south delta.
	LD   A,D						; Fetch the player's north-south position.
	CP   E							; Compare to Rex's north-south position.
	JR   NC,PSOUTHOFREX;L4A92		; Jump if the player is south of Rex.

; The player is north of Rex.
	LD   A,E                                ; Fetch the Rex's north-south position.
	SUB  D                                  ; Determine the north-south delta.
	JR   SAVEYDELTA;L4A93                              ; Jump ahead to continue.

; The player is south of Rex.
PSOUTHOFREX:;L4A92:  
	SUB  E                                  ; Determine the north-south delta.

; Attempt to move Rex towards the player. The axis with the largest delta is attempted first.
; If Rex cannot move along one axis then a check is made along the other.

SAVEYDELTA:;L4A93:  
	CP   C                                  ; Is the north-south delta is the same or larger then the west-east delta?

	POP  DE                                 ; Retrieve the player's (D) and Rex's (E) north-south positions.
	POP  BC                                 ; Retrieve the player's (B) and Rex's (C) west-east positions.

	CALL NC,YDELTA_HE_XDELTA;L4AA0			; If the north-south delta is the same or larger then the west-east delta then attempt to move Rex in the north-south direction.

; The carry flag will be set if either:
; - The north-south delta was smaller than the west-east delta.
; - Rex is in line north-south with the player and so did not move.
; - Rex could not move north-south due to a wall.

	CALL C,YDELTA_L_XDELTA;L4ABE                            ; If Rex has not been moved then attempt to move Rex west or east.

; The carry flag will be set if either:
; - Rex is in line west-east with the player and so did not move.
; - Rex could not move west-east due to a wall.

	CALL C,YDELTA_HE_XDELTA;L4AA0			; If Rex has not been moved then attempt to move Rex north or south.
	RET

; --------------------------------------------------
; North-South Delta Same/Larger Than West-East Delta YDELTA_HE_XDELTA
; --------------------------------------------------
; The north-south delta between the player's position and Rex's position is the same or larger than the west-east delta.
; If Rex can be moved then the return address is dropped causing the return to by-pass further attempts to move Rex.
; Entry: D=Player's north-south position.
;        E=Rex's north-south position.
; Exit : Carry set if a move was not possible (a wall was in the way) or was not required (Rex already in line with the player).
YDELTA_HE_XDELTA:;L4AA0:  
	; LD   HL,(L4088)		; Fetch Rex's location.
	LD A,(RX) 	;H=RX
	LD H,A
	LD A,(RY)	;L=RY
	LD L,A

	LD   A,D				; Fetch the player's north-south position.

	PUSH BC					; Save the player's (B) and Rex's (C) west-east positions.

	; LD   BC,$0010			; Offset used to move north or south.

	CP   E					; Is Rex in line or to the south of the player?
	JR   NC,R_INLINE_ORSOUTH;L4AB0			; Jump if a>=e, PY>=RY

; Rex to the north of the player.
	AND  A					; Signal a move could occur.
	; SBC  HL,BC			; Move Rex to the north.
	DEC L
	JR YDELTA_HE_XDELTACONT;L4AB3                              ; Jump ahead to continue.

; Rex is in line with the player or to the south of the player.
R_INLINE_ORSOUTH:;L4AB0:  
	JR   Z,R_INLINEY;L4ABB			; Jump if Rex is in line north-south with the player.

; Rex is south of the player.
	; ADD  HL,BC			; Move Rex to the south.
	INC L

YDELTA_HE_XDELTACONT;L4AB3:  
	POP  BC					; Retrieve the player's (B) and Rex's (C) west-east positions.

	; BIT  7,(HL)			; Does the new location contain a wall?
	PUSH BC
	PUSH HL
	PUSH AF
	PUSH DE
	LD D,H
	LD E,L
	CALL GET_POS
	POP DE
	POP AF
	LD A,L
	CP A,_MW	; Check if rex can actually make that move (inverted original game logic)
	POP HL
	POP BC
	
	SCF                                     ; Signal a move could not occur (set carry flag).
	RET  Z                                 ; Return if the new location contains a wall.

	AND  A                                  ; Signal a move could occur.
	JR   REXMOVEDX;L4AD3                              ; Jump ahead to continue.

; Rex is in line north-south with the player.
R_INLINEY:;L4ABB:  
	POP  BC                                 ; Retrieve the player's (B) and Rex's (C) west-east positions.

	SCF                                     ; Signal a move west or east is not required.
	RET

; -------------------------------------------
; North-South Delta Less Than West-East Delta YDELTA_L_XDELTA
; -------------------------------------------
; The north-south delta between the player's position and Rex's position is the less than the west-east delta.
; If Rex can be moved then the return address is dropped causing the return to by-pass further attempts to move Rex.
; Entry: B=Player's west-east position.
;        C=Rex's west-east position.
; Exit : Carry set if a move was not possible (a wall was in the way) or was not required (Rex already in line with the player).
YDELTA_L_XDELTA:;L4ABE:  
	; LD   HL,(L4088)		; Fetch Rex's location.
	LD A,(RX) 	;H=RX
	LD H,A
	LD A,(RY)	;L=RY
	LD L,A

	LD   A,B                                ; Fetch the player's west-east position.
	CP   C                                  ; Is Rex in line or to the west of the player?
	JR   NC,R_INLINE_ORWEST;L4AC8                           ; Jump if so.

; Rex is to the east of the player.
	; DEC  HL                                 ; Move Rex to the west.
	DEC H
	JR   YDELTA_L_XDELTACONT;L4ACB

; Rex is in line or to the west of the player.

R_INLINE_ORWEST:;L4AC8:  
	JR   Z,R_INLINEX;L4AD1                            ; Jump if Rex is in line west-east with the player.

; Rex is east of the player.
	INC  H                                 ; Move Rex to the east.

YDELTA_L_XDELTACONT;L4ACB:  
	; BIT  7,(HL)				; Does the new location contain a wall?
	PUSH BC
	PUSH HL
	PUSH AF
	PUSH DE
	LD D,H
	LD E,L
	CALL GET_POS
	POP DE
	POP AF
	LD A,L
	CP A,_MW	; Check if rex can actually make that move
	POP HL
	POP BC

	SCF                                     ; Signal a move could not occur.
	RET  Z                                 ; Return if the new location contains a wall.

	JR   REXMOVEDX;L4AD3                              ; Jump ahead to continue.

; Rex is in line west-east with the player.
R_INLINEX;L4AD1:  
	SCF                                     ; Signal a move north or south is not required.
	RET

; Rex has moved.
REXMOVEDX:;L4AD3:  
	; LD   (L4088),HL                         ; Store the new location for Rex.
	;SET  3,(HL)                             ; Enter a trail character into the maze at Rex's new location.

	LD A,H
	LD (RX),A
	LD A,L
	LD (RY),A

	LD   HL,GAMEFLAGS;L4087			; Point at the flags byte.
	SET  3,(HL)                             ; Signal that Rex has moved.

	POP  DE                                 ; Discard the return address so that further attempts to move Rex are not made.
	RET

; -------------------------
; Determine Distance to Rex
; -------------------------
; HL=Location of the player.
; DE=Movement offset to apply when the player moves forwards.
GETDISTANCETOREX:;L4ADF:  
	LD A,(PX)		; Save PX=D,PY=E - player position
	LD D,A
	LD A,(PY)
	LD E,A

	LD B,$00		; Initially assume Rex is at the location of the player (Distance = 0)
	LD A,(RX)		; RX=H,RY=L
	LD H,A
	LD A,(RY)
	LD L,A

	LD A,(PD)
	CP A,0 ;NORTH
	JP Z,CHECKNORTH4REX
	CP A,1 ;WEST
	JP Z,CHECKWEST4REX
	CP A,2 ;SOUTH
	JP Z,CHECKSOUTH4REX
	CP A,3 ;EAST
	JP Z,CHECKEAST4REX
	RET ; Shouldnt reach here

; This loopS continually applies an offset to the player's location in the direction being faced to determine
; whether Rex is visible and if so how far away. 
CHECKNORTH4REX:
	DEC E ; Y--
	
	PUSH HL
	PUSH BC
	CALL GET_POS
	POP BC
	LD A,L
	POP HL
	CP _MW
	JP Z,REXNOTVISIBLE;L4B92		; Jump if so as Rex is not visible.
	; Rex is visible.
	INC  B                                  ; Increment the distance.
CHECKNORTH4REXENDLOOP:
	; Is Rex at the new location?
	LD A,H
	CP A,D ; Compare PX ?= RX
	JR NZ,CHECKNORTH4REX		; Loop back if not.
	LD A,L
	CP A,E ; Compare PY ?= RY		
	JR NZ,CHECKNORTH4REX		; Loop back if not.
	JP UPDATEDISTANCETOREX

CHECKSOUTH4REX:
	INC E ; Y++

	PUSH HL
	PUSH BC
	CALL GET_POS
	POP BC
	LD A,L
	POP HL
	CP _MW
	JP Z,REXNOTVISIBLE;L4B92		; Jump if so as Rex is not visible.
	; Rex is visible.
	INC  B                                  ; Increment the distance.
CHECKSOUTH4REXENDLOOP:
	; Is Rex at the new location?
	LD A,H
	CP A,D ; Compare PX ?= RX
	JR NZ,CHECKSOUTH4REX		; Loop back if not.
	LD A,L
	CP A,E ; Compare PY ?= RY		
	JR NZ,CHECKSOUTH4REX		; Loop back if not.
	JP UPDATEDISTANCETOREX

CHECKEAST4REX:
	INC D ; X++

	PUSH HL
	PUSH BC
	CALL GET_POS
	POP BC
	LD A,L
	POP HL
	CP _MW
	JP Z,REXNOTVISIBLE;L4B92		; Jump if so as Rex is not visible.
	; Rex is visible.
	INC  B                                  ; Increment the distance.
CHECKEAST4REXENDLOOP:
	; Is Rex at the new location?
	LD A,H
	CP A,D ; Compare PX ?= RX
	JR NZ,CHECKEAST4REX		; Loop back if not.
	LD A,L
	CP A,E ; Compare PY ?= RY		
	JR NZ,CHECKEAST4REX		; Loop back if not.
	JP UPDATEDISTANCETOREX

CHECKWEST4REX:
	DEC D ; X--

	PUSH HL
	PUSH BC
	CALL GET_POS
	POP BC
	LD A,L
	POP HL
	CP _MW
	JP Z,REXNOTVISIBLE;L4B92		; Jump if so as Rex is not visible.
	; Rex is visible.
	INC  B                                  ; Increment the distance.
CHECKWEST4REXENDLOOP:
	; Is Rex at the new location?
	LD A,H
	CP A,D ; Compare PX ?= RX
	JR NZ,CHECKWEST4REX		; Loop back if not.
	LD A,L
	CP A,E ; Compare PY ?= RY		
	JR NZ,CHECKWEST4REX		; Loop back if not.
	JP UPDATEDISTANCETOREX

UPDATEDISTANCETOREX:
	; The search has reached Rex.
	LD   A,B							; Fetch the distance.
	LD   (DISTANCETOREX),A;L408D		; Store at as the frame to display or Rex.

; Joins here when the player requested to move forwards but there was a wall ahead, or when Rex has caught the player.

; --------
; Draw Rex
; --------
DRAWREX:;L4AF4:  
	LD A,(DISTANCETOREX)			; Fetch the frame display index for Rex.
	CP 6						; Is Rex beyond the visible range?
	JP NC,REXNOTVISIBLE;L4B92		; Jump if so.

; ; Rex is within visible range.
	; Select which rex image to display:
	LD HL,GAMEFLAGS			; Point at the flags byte

	CP A,5
	JP Z,DISPREX5
	CP A,4
	JP Z,DISPREX4
	CP A,3
	JP Z,DISPREX3
	CP A,2
	JP Z,DISPREX2
	CP A,1
	JP Z,DISPREX1
	CP A,0
	JP Z,DISPREX0
	RET

DISPREX5:
	BIT 1,(HL)					; Does Rex have left or right foot forward?
    JR NZ,SETREX5L			; Jump if the left foot is forward
	LD HL,REX5R
	JP PRINTREXSPRITE
SETREX5L:
	LD HL,REX5L
	JP PRINTREXSPRITE

DISPREX4:
	BIT 1,(HL)					; Does Rex have left or right foot forward?
    JR NZ,SETREX4L			; Jump if the left foot is forward
	LD HL,REX4R
	JP PRINTREXSPRITE
SETREX4L:
	LD HL,REX4L
	JP PRINTREXSPRITE

DISPREX3:
	BIT 1,(HL)					; Does Rex have left or right foot forward?
    JR NZ,SETREX3L			; Jump if the left foot is forward
	LD HL,REX3R
	JP PRINTREXSPRITE
SETREX3L:
	LD HL,REX3L
	JP PRINTREXSPRITE

DISPREX2:
	BIT 1,(HL)					; Does Rex have left or right foot forward?
    JR NZ,SETREX2L			; Jump if the left foot is forward
	LD HL,REX2R
	JP PRINTREXSPRITE
SETREX2L:
	LD HL,REX2L
	JP PRINTREXSPRITE

DISPREX1:
	BIT 1,(HL)					; Does Rex have left or right foot forward?
    JR NZ,SETREX1L			; Jump if the left foot is forward
	LD HL,REX1R
	JP PRINTREXSPRITE
SETREX1L:
	LD HL,REX1L
	JP PRINTREXSPRITE

DISPREX0:
	BIT 1,(HL)					; Does Rex have left or right foot forward?
    JR NZ,SETREX0L			; Jump if the left foot is forward
	LD HL,REX0R
	JP PRINTREXSPRITE
SETREX0L:
	LD HL,REX0L
	JP PRINTREXSPRITE

	; Display Rex
PRINTREXSPRITE:
	LD A,L
	CP REX0R & $FF
	JP Z,PRINTREX_0R
	CP REX0L & $FF
	JP NZ,PRINTREX_NOT0

PRINTREX_0:
	BCALL(_ClrLCD)

	LD E,0
    LD D,0
    LD HL,REX0L
    CALL DisplayImage

	SETPEN(0,13)
    LD HL,POSTHUMOUSLYSCREEN
	CALL VPutS

	SETPEN(0,19)
    LD HL,POSTHUMOUSLYSCREEN+14
	CALL VPutS

	SETPEN(0,25)
	LD HL,(SCORE)
	CALL vDispHL

	SETPEN(22,25)
    LD HL,POSTHUMOUSLYSCREEN+35
	CALL VPutS

	SETPEN(0,31)
    LD HL,POSTHUMOUSLYSCREEN+56
	CALL VPutS

	SETPEN(10,37)
    LD HL,POSTHUMOUSLYSCREEN+82
	CALL VPutS

	SETPEN(20,43)
    LD HL,POSTHUMOUSLYSCREEN+104
	CALL VPutS

	SETPEN(30,49)
    LD HL,POSTHUMOUSLYSCREEN+121
	CALL VPutS

	RET ;JP DISPSTATUSSCORE_CONT

PRINTREX_0R:
	LD D,0
	LD E,0
	CALL DisplayImage
	JP DISPSTATUSSCORE_CONT;L4CB3

PRINTREX_NOT0:
	; Update coordinates where Rex picture should be printed
	LD A,(RENDERFLAGS)
	BIT 0,A
	JP Z,REXXPOSITION_NO_RC
	; RAYCAST CENTER REX
	; Assign X position of the image (D)
	INC HL 
	LD A,(HL) ; Get width of image
	LD D,A
	LD A,GAME_W ; Get width of game
	SUB A,D	
	LD D,A	; Get maximum X value for the image to fit in GAME_W AREA

	PUSH HL
	LD HL,(PDD)
	LD B,128
	PUSH DE
	CALL MODULO_16B ; HL MODULO B
	POP DE
	SRL A ; A/2
	ADD A,32
	; If X is bigger than 64 (GAME_W), adjust it by substracting 64
	CP A,GAME_W
	JR C,DONTADJUST_MINUS64_X
	SUB GAME_W-1
DONTADJUST_MINUS64_X:
	; Now, if the X+IMG_W is bigger than GAME_W, dont print it
	; LD B,A
	; ADD A,D
	; CP A,GAME_W
	; JP NC,DISPSTATUSSCORE_CONT

	LD E,A
	POP HL

	DEC HL
	JP REXYPOSITION
REXXPOSITION_NO_RC:
	; Assign X position of the image (D)
	INC HL 
	LD A,(HL) ; Get width of image
	LD D,A
	LD A,GAME_W ; Get width of game
	SUB A,D		
	RR A		; (GAME_W - ImgWidth)/2
	LD E,A

	DEC HL
REXYPOSITION:
	; Assign Y position of the image (E)
	LD A,(HL) ; Get height of image
	LD D,A
	LD A,GAME_H ; Get height of game
	SUB A,D		
	RR A		; (GAME_H - ImgHeight)/2
	INC A ;DEBUG TO CENTER IMAGE BETTER IN Y-AXIS
	LD D,A

	CALL DisplayImage; B_CALL(_DisplayImage) ;TODO: Make rex sprite copy to screen buffer instead of printing it on top of screen

	JP DISPSTATUSSCORE_CONT;L4CB3
	RET

; ------------------------------------------
; Rex is Not Visible or Beyond Visible Range
; ------------------------------------------
; When determining the sprite image to display for Rex, Rex was found not to be visible from the player's
; location and the direction being faced, or Rex was found to be beyond the visible range.
;
; The status message displayed at the bottom of the view is determined as follows:
; - If Rex moved then
;   - If Rex is at a distance of 7 or above then
;     - If Rex is at distance 7 or 8 then
;       - Display "FOOTSTEPS APPROACHING"
;     - Else if timer not expired then
;       - Display "HE IS HUNTING YOU"
;     - Else
;       - Set the countdown timer to clear the status message area
;   - Else if Rex is in line of sight of the player then
;     - If Rex is at distance 0, 1 or 2
;       - Display "run REX IS BEHIND YOU" / "run REX IS BESIDE YOU" (depending upon orientation of the player compared to Rex)
;     - Else
;       - Display "REX HAS SEEN YOU"
; - Else
;   - If countdown timer not expired then
;     - Increment the countdown timer (capping at a maximum of 8)
;   - Display "REX LIES IN WAIT"
REXNOTVISIBLE:;L4B92
	LD   A,(GAMEFLAGS)					; Fetch the flags byte.
    BIT  3,A							; Did Rex move?
    JR   NZ,UPDATESTATUSMSG;L4BB9		; Jump ahead if so to determine and display the status message.

; Rex did not move.
	LD   HL,STATUSTIMER;L408B	; Point to the status area display timeout.
	LD   A,$08
	CP   (HL)					; Is the timeout already at its maximum value?
	JR   Z,TIMEOUT;L4BA2		; Jump ahead if not.

	INC  (HL)					; Increment the timeout value.

; Display "REX LIES IN WAIT" and the score.
TIMEOUT:;L4BA2:  
	LD   DE,REXWAIT				; Offset for status message "   REX LIES IN WAIT   ".
	JP   DISPSTATUSSCORE;L4CB0	; Jump ahead to display the status message and score.

; ------------------------
; Determine Status Message
; ------------------------
; The following code determines how close Rex is to the player to determine the status message that should be displayed.
UPDATESTATUSMSG:;L4BB9: USM  
	; LD   HL,L4088		; Point to the location holding Rex's location.
	; CALL L4BAE		; B=High nibble of low byte of Rex's location (north-south). C=Low nibble of low byte of Rex's location (west-east).
	;B=RY, C=RX
	LD A,(RX) 	;C=RX
	LD E,A
	LD A,(RY)
	LD D,A		;B=RY

	; PUSH BC
	; POP  DE                                 ; Transfer Rex's location information to DE.

	;B=PY, C=PX
	LD A,(PX)	;C=PX
	LD C,A
	LD A,(PY)
	LD B,A		;B=PY

; BC=Player location details.
; DE=Rex location details.
	LD   A,B		; Fetch the high nibble of the low byte of the player's location (north-south value, Y).
	SUB  A,D			; Determine the delta between the player and Rex's north-south location (Positive if player to the south of Rex).
	LD   B,A		; Store the north-south delta in B.

	LD   A,C		; Fetch the low nibble of the low byte of the player's location (west-east value, X).
	SUB  A,E			; Determine the delta between the player and Rex's west-east location (Positive if player to the east of Rex).
	LD   C,A		; Store the west-east delta in C.

	CP   $00		; Is Rex's in line west-east with the player? XDELTA == 0
	JR   NZ,USMNOINLINEWE;L4BF9	; Jump ahead if not.

; Rex is in line with the player west-east.
	LD   A,B			; Fetch the north-south delta, dX.
	CALL ABS;L4BA8		; Convert to an absolute delta, i.e. A=ABS(A).

	CP   $07			; Is Rex close enough to be within visible range?
	JR   NC,USMNOVISIBLE;L4C26		; Jump ahead if not.

; Rex is close enough north-south to be within visible range.
	PUSH BC				; Save the north-south and west-east deltas.
	CALL CHECKREXINLINESIGHT;L4C57		; Determine whether Rex is in line of sight with the player. A return is only made if he is, else execution continues at L4C26.
	POP  BC				; Retrieve the north-south and west-east deltas.

; Rex is in line of sight of the player.
	LD   A,B			; Fetch the north-south delta.
	CALL ABS;L4BA8		; Convert to an absolute delta, i.e. A=ABS(A).

	CP   $03			; Is Rex close to the player?
	JR   NC,REXINLINESIGHTNOTBESIDE;L4C51		; Jump if not.

; Rex is close to the player.
	LD   A,(PD)		; Fetch the direction the player is facing ($00=North, $01=West, $02=South, $03=East).
	BIT  0,A			; Is the player facing west or east (1 or 3, not even numbers)?
	JR   NZ,REXBESIDEPLAYER;L4BF3		; Jump if so, i.e. Rex is beside the player.

; Rex is behind the player.
	LD   DE,REXBEHIND;L4558-L4542		; Offset for status message " run HE IS BEHIND YOU ".
	JP   DISPSTATUSSCORE;L4CB0				; Jump ahead to display the status message and score.

; Rex is beside the player.
REXBESIDEPLAYER;L4BF3:  
	LD   DE,REXBESIDE;L456E-L4542                     ; Offset for status message " run HE IS BESIDE YOU ".
	JP   DISPSTATUSSCORE;L4CB0                              ; Jump ahead to display the status message and score.

; Rex is not in line with the player west-east.
USMNOINLINEWE:;L4BF9:  
	LD   A,B                                ; Fetch the north-south delta.
	CP   $00                                ; Is Rex in line north-south with the player?
	JR   NZ,USMNOVISIBLE;L4C26                           ; Jump ahead if not.

; Rex is not in line with the player west-east but is in line with the player north-south.
	LD   A,C                                ; Fetch the west-east delta.
	CALL ABS;L4BA8                              ; Convert to an absolute delta, i.e. A=ABS(A).

	CP   $07                                ; Is Rex close enough to be within visible range?
	JR   NC,USMNOVISIBLE;L4C26                           ; Jump ahead if not.

; Rex is close enough west-east to be within visible range.
	PUSH BC							; Save the north-south and west-east deltas.
	CALL CHECKREXINLINESIGHT;L4C57		; Determine whether Rex is in line of sight with the player. A return is only made if he is, else execution continues at L4C26.
	POP  BC							; Retrieve the north-south and west-east deltas.

; Rex is in line of sight of the player.
	LD   A,C                                ; Fetch the west-east delta.
	CALL ABS;L4BA8                              ; Convert to an absolute delta, i.e. A=ABS(A).

	CP   $03                                ; Is Rex close to the player?
	JR   NC,REXINLINESIGHTNOTBESIDE;L4C51                           ; Jump if not.

; Rex is close to the player.
	LD   A,(PD)                          ; Fetch the direction the player is facing ($00=North, $01=West, $02=South, $03=East).
	BIT  0,A                                ; Is the player facing north or south?
	JR   Z,REXBESIDEPLAYER2;L4C20                            ; Jump if so, i.e. Rex is beside the player.

; Rex is behind the player.
	LD   DE,REXBEHIND;L4558-L4542                     ; Offset for status message " run HE IS BEHIND YOU ".
	JP   DISPSTATUSSCORE;L4CB0                              ; Jump ahead to display the status message and score.

; Rex is beside the player.
REXBESIDEPLAYER2:;L4C20:  
	LD   DE,REXBESIDE;L456E-L4542                     ; Offset for status message " run HE IS BESIDE YOU ".
	JP   DISPSTATUSSCORE;L4CB0                              ; Jump ahead to display the status message and score.

; Rex is in line with the player north-south or west-east but is not within visible range, or
; Rex is not in line with the player north-south and not in line with the player west-east, or
; Rex is in line with the player but there is a wall in between Rex and the player.

USMNOVISIBLE:;L4C26:  
	LD   A,B                                ; Fetch the north-south delta.
	CALL ABS;L4BA8                              ; Convert to an absolute delta, i.e. A=ABS(A).
	LD   B,A                                ; Store the absolute north-south delta in B.

	LD   A,C                                ; Fetch the west-east delta.
	CALL ABS;L4BA8                              ; Convert to an absolute delta, i.e. A=ABS(A).

	ADD  A,B                                ; Determine the total distance from the player.

	CP   $09                                ; Is Rex close enough to be heard approaching?
	JR   C,USMREXCLOSE;L4C45                            ; Jump if so.

; Rex is not close enough to be heard approaching.
	LD   A,(STATUSTIMER)                          ; Is it time to clear the status message area?
	CP   $00
	JR   Z,USMCLRSTATUS;L4C4B                            ; Jump ahead if so to clear the status message area.

; A message is being displayed so decrement the display timeout.
	DEC  A                                  ; Decrement the timeout value.
	LD   (STATUSTIMER),A                          ; Store the new value.

	LD   DE,REXHUNT;L45B0-L4542                     ; Offset for status message " HE IS HUNTING FOR YOU".
	JP   DISPSTATUSSCORE;L4CB0                              ; Jump ahead to display the status message and score.

; Rex is close enough to be heard but is not within line of sight.
USMREXCLOSE:;L4C45:  
	LD   DE,REXAPPR;L459A-L4542                     ; Offset for status message " FOOTSTEPS APPROACHING".
	JP   DISPSTATUSSCORE;L4CB0                              ; Jump ahead to display the status message and score.

; Clear status message.
USMCLRSTATUS:;L4C4B:  
	LD   DE,REXEMPTY;L45C6-L4542                     ; Offset for status message "                      ".
	JP   DISPSTATUSSCORE;L4CB0                              ; Jump ahead to display the status message and score.

; Rex is in line of sight but not next to the player.
REXINLINESIGHTNOTBESIDE:;L4C51:  
	LD   DE,REXSEEN;L4584-L4542                     ; Offset for status message "   REX HAS SEEN YOU   ".
	JP   DISPSTATUSSCORE;L4CB0                              ; Jump ahead to display the status message and score.


; -----------
; ABS(Number)
; -----------
; Input : A=Value.
; Output: A=ABS(Value).
ABS:;L4BA8:
	BIT  7,A                                ; Is the number negative?
    RET  Z                                  ; Return if not.
	CPL                                     ; Negate the number.
	INC  A
	RET

; ---------------------------------------------------
; Check Whether Rex is in Line of Sight of the Player
; ---------------------------------------------------
; This subroutine only returns if Rex is in line of sight of the player, else it drops the return address
; and continues by jumping to L4C26.
; Entry: B=North-south delta between Rex and player (positive if player is to the south).
;        C=West-east delta between Rex and player (positive if player is to the east).
CHECKREXINLINESIGHT:;L4C57:
	LD   A,B                                ; Fetch the north-south delta.
	CP   $00                                ; Is Rex in line with the player?
	JR   Z,RINS_INLINE;L4C6E                ; Jump ahead if so.

; Rex is not in line with the player north-south.
	CALL ABS;L4BA8                              ; Convert to an absolute north-south delta, i.e. A=ABS(A).
	BIT  7,B                                ; Is the player to the south of Rex? (negative number)
	
	LD   B,A                                ; Transfer the absolute north-south delta to B.
	JR   Z,PLAYERSOUTHOFREX;L4C69            ; Jump ahead if the player is to the south of Rex.

; The player is to the north of Rex.
	; RY++
	LD   DE,$0001                           ; Movement offset to the south. A check for Rex will be made to the south. 
	JR   RINS_CHECKMOVEREX;L4C7F

; The player is to the south of Rex.

PLAYERSOUTHOFREX;L4C69:  
	; RY--
	LD   DE,$00FF                           ; Movement offset to the north. A check for Rex will be made to the north.
	JR   RINS_CHECKMOVEREX;L4C7F

; Rex is in line with the player north-south.
RINS_INLINE:;L4C6E:  
	LD   A,C                                ; Fetch the west-east delta.
	CALL ABS;L4BA8                              ; Convert to an absolute west-east delta, i.e. A=ABS(A).
	BIT  7,C                                ; Is the player to the east of Rex?
	LD   B,A                                ; Transfer the absolute west-east delta to B.
	JR   Z,PLAYEREASTOFREX;L4C7C                            ; Jump ahead if the player is to the east of Rex.

; The player is to the west of Rex.
	; PX++
	LD   DE,$0100                           ; Movement offset to the east. A check for Rex will be made to the east.
	JR   RINS_CHECKMOVEREX;L4C7F

; The player is to the east of Rex.
PLAYEREASTOFREX:;L4C7C: 
	; PX--
	LD   DE,$FF00                           ; Movement offset to the west. A check for Rex will be made to the west.
	JR   RINS_CHECKMOVEREX;L4C7F

; B holds axis delta.
; DE holds offset.

; Search along the length of the delta checking whether there is a wall in between the player and Rex.

RINS_CHECKMOVEREX;L4C7F:  
	;LD   HL,(L4082)                         ; Fetch the location of the player.
	PUSH BC
	PUSH AF
	LD A,(PX)
	LD H,A
	LD A,(PY)
	LD L,C
	POP AF
	POP BC

RINS_LOOPCHECK:;L4C82:  
	; ADD  HL,DE                              ; Add the check direction offset.
	; Inc/dec HL (PX,Y)
	LD A,$FF
	CP A,D ;X
	JP Z,DECXH
	CP A,E ;Y
	JP Z,DECYL
	LD A,$01
	CP A,D ;X
	JP Z,INCXH
	CP A,E ;Y
	JP Z,INCYL
	RET ; Shouldn't reach here
DECXH:
	DEC H
	JP RINS_CONTLOOP
DECYL:
	DEC L
	JP RINS_CONTLOOP
INCXH:
	INC H
	JP RINS_CONTLOOP
INCYL:
	INC L
	JP RINS_CONTLOOP

RINS_CONTLOOP:
	PUSH DE
	PUSH HL
	PUSH BC
	EX DE,HL
	CALL GET_POS
	LD A,L
	POP BC
	POP HL
	POP DE
	CP A,_MW ;BIT  7,(HL)					; Has a wall be reached? 
	JR Z,RINS_WALLREACHED;L4C8A		; Jump ahead if so.

	DJNZ RINS_LOOPCHECK;L4C82			; Repeat for the length of the delta distance.

; Rex is in line of sight with the player.
	RET

RINS_WALLREACHED:;L4C8A:  
	POP DE							; Discard the return address.
	POP BC							; Retrieve stacked delta values.
	JP USMNOVISIBLE;L4C26			; Return to the logic branch that handles the condition when Rex is not able to see the player.


; ----------------------
; Display Status Message
; ----------------------
; Both "HE IS HUNTING YOU" and "REX LIES IN WAIT" display for a fixed length of time before being automatically cleared. A timeout value
; is used to control when the message is cleared from the screen.
; Entry: DE=Offset to the required status message.
DISPSTATUSMSG:;L4C8F: 	
	PUSH DE
	CALL CLEARSTATUSMSG ;DEBUG: To clear the whole line (sometimes there are rests of rpevious msgs)
	POP DE
	LD   A,E
	CP   REXHUNT & $FF					; Is the message "HE IS HUNTING YOU"?
	JR   Z,PRINTSTATUSMSG;L4C9D			; Jump ahead if so.

	CP   REXWAIT & $FF					; Is the message "REX LIES IN WAIT"?
	JR   Z,PRINTSTATUSMSG;L4C9D			; Jump ahead if so.

	CP REXEMPTY & $FF
	JR Z,CLEARSTATUSMSG

; The status message does not use a timeout.
	LD   A,$00							; Clear the status message timeout.
	LD   (STATUSTIMER),A
; Continue below.

; -----------------------------------------
; Copy Status Message into the Display File
; -----------------------------------------
; Entry: DE=Address (NOT Offset) to the required status message.
PRINTSTATUSMSG:;L4C9D:  
	; LD   HL,L4542                           ; Address of the status message table.
	; ADD  HL,DE                              ; Offset to the required message.
	; EX   DE,HL                              ; Transfer the message address to DE.
	; The address of the message is already at DE, no need to add offset
	; LD   HL,(D_FILE)                        ; Fetch the location of the display file.
	; LD   BC,$02F9                           ; Offset to row 23 column 1.
	; ADD  HL,BC
	; EX   DE,HL                              ; DE=Display file address, HL=Message address.
	; LD   BC,$0016                           ; The status message is 22 characters in length.
	; LDIR                                    ; Copy the status message into the display file.

	; DISPLAY STATUS MSG - DISPSTATUS
	; Input: DE (addr to msg)
	; Destroys: AF,HL
	
	; PUSH DE
	; POP HL	; DE -> HL
	LD   A,E
	CP   REXBEHIND & $FF
	JR   Z,PRINTSTATUSMSG_RUN
	LD   A,E
	CP   REXBESIDE & $FF
	JR   NZ,PRINTSTATUSMSGCONT
PRINTSTATUSMSG_RUN:				; Print the word RUN in inverse color text
	EX DE,HL
	SETPEN(0,58)
    CALL VPutS_INV3

PRINTSTATUSMSGCONT:
	EX DE,HL
	SETPEN(0,58)
    CALL VPutS

PRINTSTATUSMSGend:
	RES textInverse, (IY + textFlags)
	RET

; -----------------------------------------
; Clear Status Message
; -----------------------------------------
CLEARSTATUSMSG:
	LD D,58
	LD E,0
	LD HL,BLANKLINEIMG
	CALL DisplayImage
	; TO CLEAR THW WHOLE BOTTOM TEXT LINE
	LD D,58
	LD E,32
	LD HL,BLANKLINEIMG
	CALL DisplayImage
	RET

; --------------------------------
; Display Status Message and Score
; --------------------------------
DISPSTATUSSCORE:;L4CB0:  
	CALL DISPSTATUSMSG;L4C8F		; Insert the status message into the display file, setting the clear message timeout as appropriate.

DISPSTATUSSCORE_CONT:;L4CB3:  
	LD   HL,GAMEFLAGS;L4087			; Point at the flags byte.
	LD   A,$48						; The flags for the player moved forward and Rex moved.
	AND  (HL)						; Keep only these flags.
	CP   $48						; Did the player move forward and Rex also moved?
	RES  6,(HL)						; Clear the player moved forwards flag.
	JR   NZ,CHECKREXCAUGHTP;L4CC5	; Jump ahead if not.

; The player moved forwards and Rex also moved so increment the score by 5 points.
	LD   DE,5;SCOREINC5+$0003;L453E+$0003		; Point to the score increment of 5 for step avoiding capture.
	CALL SCOREADD;L4D0D								; Add the increment to the score.

; Check whether Rex has caught the player.
CHECKREXCAUGHTP:;L4CC5:  
	LD   HL,GAMEFLAGS;L4087			; Point at the flags byte.
	BIT  7,(HL)						; Has the player been caught?
	JR   Z,REXNOCAUGHTP;L4CD1		; Jump ahead if not.

; The player has been caught so display the final score.
	; LD   DE,$018D					; Offset to row 12 column 0;
	; JR   L4CEF					; Jump ahead to display the score.
	;JP DISPSCORE

; The player has not been caught.
REXNOCAUGHTP;L4CD1:  
	; LD   HL,(L4082)                         ; Fetch the location of the player.
	LD A,(PX)
	LD D,A
	LD A,(PY)
	LD E,A

	; LD   A,(HL)                             ; Fetch the contents of the location.
	CALL GET_POS
	LD A,L

	CP   _ME                                ; Is the player at the Exit?
	JR   NZ,PLAYERNOTEXIT;L4CE1				; Jump ahead if not.

; The player is at the Exit.
	LD   DE,200;SCOREINC200;L453A+$0003		; Point to the score increment of 200 for exiting the maze.
	CALL SCOREADD;L4D0D						; Add the increment to the score.

	JP   DISPLAYESCAPED;L4D28				; Jump ahead to display the escaped message text.

; The player is not at the Exit.
PLAYERNOTEXIT:;L4CE1:  
	LD   A,(DISTANCETOREX);L408D)                          ; Fetch the frame display index for Rex.
	JP   DISPSTATUSSCORE_PATCH;L4D58                              ; Jump ahead to continue, returning to LC4CE7 if Rex is not immediately next to the player.

; Rex is not immediately next to the player.
; DE=Points at the blank status message.
REXNOTNEXTTOPLAYER:;L4CE7:  
	CP   $06						; Is Rex within visible range?
	CALL C,PRINTSTATUSMSG;L4C9D		; If so then clear the status message area.

; -----------------
; Display the Score
; -----------------
; DISPLAY SCORE
; Destroys: AF,HL
DISPSCORE:;L4CEC:  
	LD H,16
	LD L,75
	LD (penCol),HL

	LD HL,SCORETEXT
	CALL VPutS

	LD H,11
	LD L,3
	LD (curRow),HL

	LD HL,(SCORE)
	B_CALL(_dispHL)


	; ;DEBUG;DEBUG;DEBUG;DEBUG;DEBUG
	; LD H,11
	; LD L,0
	; LD (curRow),HL

	; ld h,0
	; LD a,(PD)
	; ld l,a
	; B_CALL(_dispHL)

	; LD H,11
	; LD L,1
	; LD (curRow),HL

	; LD HL,(PDD)
	; B_CALL(_dispHL)

	; LD H,11
	; LD L,5
	; LD (curRow),HL

	; LD HL,(PDX)
	; B_CALL(_dispHL)

	; LD H,11
	; LD L,6
	; LD (curRow),HL

	; LD HL,(PDY)
	; B_CALL(_dispHL)
	; ;DEBUG;DEBUG;DEBUG;DEBUG;DEBUG
	RET

; ----------------------------------------
; Display Status Message and Score (Patch)
; ----------------------------------------
; This patch is jumped to when the player has not been caught and is not at the Exit.
; A=Frame display index for Rex.
DISPSTATUSSCORE_PATCH:;L4D58:  
	CP   $00                                ; Is Rex next to the player?
	JP   Z,DISPSCORE;L4CEC                            ; Jump if so to display the score and then make a return.

	LD   DE,REXEMPTY;L45C6-L4542                     ; Offset to the status message text "                      ".
	JP   REXNOTNEXTTOPLAYER;L4CE7                              ; Jump to clear the status message area if Rex is within visible range, then display the score and make a return.

; ------------------
; Increase the Score
; ------------------
; Entry: DE=The amount to add to the score.
SCOREADD:;L4D0D:
	LD HL,(SCORE)
	ADD HL,DE
	LD (SCORE),HL
	RET

; -----------------
; Move player
; -----------------
; Input: KEY pressed in A (KD_UP,KD_LEFT or KD_RIGHT)
; Destroys: AF,HL,DE
MOVEPLAYER:
	CP	KD_UP
    JR	Z,KEYUP
    CP	KD_RIGHT
    JR	Z,KEYRIGHT
	CP	KD_LEFT
    JR	Z,KEYLEFT
	JP NOKEYPRESS	; No arrow key pressed

KEYRIGHT:
	LD A,(PD)
	DEC A
	CP A,255
	JP NZ,KEYRIGHTCONT
	LD A,3
KEYRIGHTCONT:
	LD (PD),A

	JP ENDMOVE

KEYLEFT:
	LD A,(PD)
	INC A
	CP A,4
	JP NZ,KEYLEFTCONT
	LD A,0
KEYLEFTCONT:
	LD (PD),A

	JP ENDMOVE

KEYUP:
	LD HL,(PX)
	LD D,L
	LD HL,(PY)
	LD E,L
	LD A,(PD)
	CP A,0 ; NORTH
	JP Z,MOVEN
	CP A,2 ; SOUTH
	JP Z,MOVES
	CP A,1 ; WEST
	JP Z,MOVEW
	CP A,3 ; EAST
	JP Z,MOVEE
	JP NOKEYPRESS ; Shouldnt reach here

MOVEN:
	DEC E
	CALL GET_POS
	LD A,_MW
	CP A,L
	JP Z,ENDNOMOVE
	LD A,(PY)
	DEC A
	LD (PY),A

	LD HL,GAMEFLAGS
	SET 6,(HL) ; Signal to move the player forward.
	JP ENDMOVE

MOVES:
	INC E
	CALL GET_POS
	LD A,_MW
	CP A,L
	JP Z,ENDNOMOVE
	LD A,(PY)
	INC A
	LD (PY),A

	LD HL,GAMEFLAGS
	SET 6,(HL) ; Signal to move the player forward.
	JP ENDMOVE

MOVEE:
	INC D
	CALL GET_POS
	LD A,_MW
	CP A,L
	JP Z,ENDNOMOVE
	LD A,(PX)
	INC A
	LD (PX),A

	LD HL,GAMEFLAGS
	SET 6,(HL) ; Signal to move the player forward.
	JP ENDMOVE

MOVEW:
	DEC D
	CALL GET_POS
	LD A,_MW
	CP A,L
	JP Z,ENDNOMOVE
	LD A,(PX)
	DEC A
	LD (PX),A

	LD HL,GAMEFLAGS
	SET 6,(HL) ; Signal to move the player forward.
	JP ENDMOVE

NOKEYPRESS:
	LD HL,GAMEFLAGS
	SET 5,(HL)	; Signal the player has not moved and so there is no need to redraw the view of the maze.
	RET
ENDNOMOVE:
	LD HL,GAMEFLAGS
	RES 6,(HL)
	RET
ENDMOVE:
	SET 5,(HL)		; Signal the player has moved and so the view of the maze will need to be redrawn.
    RES 7,(HL)		; Signal the player has not been caught.
	RES 4,(HL)		; Assume the Exit is not visible.
	CALL DRAW3DVIEW ;DEBUG
	RET


; -----------------
; Move player RAY CAST EDITION
; -----------------
; Input: KEY pressed in A (KD_UP,KD_LEFT or KD_RIGHT)
; Destroys: AF,HL,DE
MOVEPLAYER_RC:
	LD A,B
	CP	KD_UP
    JP	Z,FASTKEYUP
    CP	KD_RIGHT
    JP	Z,FASTKEYRIGHT
	CP	KD_LEFT
    JP	Z,FASTKEYLEFT
	CP	KD_DOWN
    JP	Z,FASTKEYDOWN
	JP FASTNOKEYPRESS	; No arrow key pressed

FASTKEYUP:
	;RAYCAST PARAMETERS
	LD A,(PD)
	CP A,0 ; NORTH
	JP Z,FASTMOVEN
	CP A,2 ; SOUTH
	JP Z,FASTMOVES
	CP A,1 ; WEST
	JP Z,FASTMOVEW
	CP A,3 ; EAST
	JP Z,FASTMOVEE
	JP FASTNOKEYPRESS ; Shouldnt reach here

FASTKEYDOWN: ; EXTRA FUNCTIONALITY, GO BACKWARDS
	LD A,(PD)
	CP A,0 ; NORTH
	JP Z,FASTMOVES
	CP A,2 ; SOUTH
	JP Z,FASTMOVEN
	CP A,1 ; WEST
	JP Z,FASTMOVEE
	CP A,3 ; EAST
	JP Z,FASTMOVEW
	JP FASTNOKEYPRESS ; Shouldnt reach here

FASTMOVEN:
	LD HL,(PDY)
	LD BC,STEPXY
	AND A
	SBC HL,BC

	; Check if new position is inside wall
	CALL REMOVEFPM
	LD E,A
	LD A,(PX)
	LD D,A
	PUSH HL
	CALL GET_POS	; D=X,E=Y
	LD E,L
	POP HL
	LD A,_MW
	CP A,E
	JP Z,FASTENDNOMOVE

	LD (PDY),HL
	CALL REMOVEFPM ; PY -> A
	LD (PY),A
	JP FASTMOVEEND

FASTMOVES:
	LD HL,(PDY)
	LD BC,STEPXY
	ADD HL,BC

	; Check if new position is inside wall
	CALL REMOVEFPM 
	LD E,A
	LD A,(PX)
	LD D,A
	PUSH HL
	CALL GET_POS	; D=X,E=Y
	LD E,L
	POP HL
	LD A,_MW
	CP A,E
	JP Z,FASTENDNOMOVE

	LD (PDY),HL
	CALL REMOVEFPM ; PY -> A
	LD (PY),A
	JP FASTMOVEEND

FASTMOVEW:
	LD HL,(PDX)
	LD BC,STEPXY
	AND A
	SBC HL,BC

	; Check if new position is inside wall
	CALL REMOVEFPM
	LD D,A
	LD A,(PY)
	LD E,A
	PUSH HL
	CALL GET_POS	; D=X,E=Y
	LD E,L
	POP HL
	LD A,_MW
	CP A,E
	JP Z,FASTENDNOMOVE

	LD (PDX),HL
	CALL REMOVEFPM ; PX -> A
	LD (PX),A
	JP FASTMOVEEND

FASTMOVEE:
	LD HL,(PDX)
	LD BC,STEPXY
	ADD HL,BC

	; Check if new position is inside wall
	CALL REMOVEFPM
	LD D,A
	LD A,(PY)
	LD E,A
	PUSH HL
	CALL GET_POS	; D=X,E=Y
	LD E,L
	POP HL
	LD A,_MW
	CP A,E
	JP Z,FASTENDNOMOVE

	LD (PDX),HL
	CALL REMOVEFPM ; PX -> A
	LD (PX),A
	JP FASTMOVEEND

FASTKEYRIGHT:
	; RAYCASTING UPDATE PARAMETERS
	LD HL,(PDD)
	LD BC,TURN_SUBCIRCLE
	ADD HL,BC
	; LD BC,16
	; AND A
	; SBC HL,BC
	CALL CLAMPANGLE
	LD (PDD),HL
	; Now adjust PD to angle of PDD
	CALL ADJUSTPDD_TO_NWES
	JP FASTMOVEEND

FASTKEYLEFT:
	; RAYCASTING UPDATE PARAMETERS
	LD HL,(PDD)
	LD BC,TURN
	ADD HL,BC
	CALL CLAMPANGLE
	LD (PDD),HL
	; Now adjust PD to angle of PDD
	CALL ADJUSTPDD_TO_NWES
	JP FASTMOVEEND

FASTNOKEYPRESS:
	LD HL,GAMEFLAGS
	SET 5,(HL)	; Signal the player has not moved and so there is no need to redraw the view of the maze.
	RET

FASTENDNOMOVE:
	LD HL,GAMEFLAGS
	RES 6,(HL)
	RET

FASTMOVEEND:
	LD HL,GAMEFLAGS
	SET 6,(HL) ; Signal to move the player forward.
	SET 5,(HL)		; Signal the player has moved and so the view of the maze will need to be redrawn.
    RES 7,(HL)		; Signal the player has not been caught.
	RES 4,(HL)		; Assume the Exit is not visible.
	;CALL CLEAR3DVIEW
	; CALL CLEAR3DVIEW_GAMEAREA
	CALL DRAW3DVIEW
	RET

; Receives an angle in HL and updates PD according to the angle ranges:
; PD | PDD 	  RANGE
; W1 | 256 +- 64 
; N0 | 384 +- 64
; E3 | 0   +- 64
; S2 | 128 +- 64
; Destroys: 
ADJUSTPDD_TO_NWES:
	; Check if its WEST (192 < PDD <= 321)
	LD A,0
	CP A,H
	JP Z,COMPARE_LESSTHAN256
	; If high byte of HL is 1, it means that the HL value is >= 256
	; Now compare low byte L to check if it's < 320+1
	LD A,321 & $FF ; Low byte of 321
	CP A,L
	JP C,NOTWEST
	; It's WEST
	LD A,0
	LD (PD),A
	JP END_ADJUSTPDD_TO_NWES

COMPARE_LESSTHAN256:
	; If high byte of HL is 0, it means that the HL value is < 256
	; Now compare low byte L to check if it's >= 192
	LD A,192 ; Low byte of 192
	CP A,L
	JP NC,NOTWEST
	; It's WEST
	LD A,0
	LD (PD),A
	JP END_ADJUSTPDD_TO_NWES

NOTWEST:
	; Check if its NORTH (320 < PDD <= 448)
	LD A,1
	CP A,H
	JP NZ,NOTNORTH
	LD A,320 & $FF ; Low byte of 321
	CP A,L
	JP NC,NOTNORTH
	LD A,449 & $FF ; Low byte of 448
	CP A,L
	JP C,NOTNORTH
	; It's NORTH
	LD A,1;0
	LD (PD),A
	JP END_ADJUSTPDD_TO_NWES
	
NOTNORTH:
	; Check if its SOUTH (64 < PDD <= 192)
	LD A,0
	CP A,H
	JP NZ,NOTSOUTH

	LD A,64 ; Low byte of 321
	CP A,L
	JP NC,NOTSOUTH

	LD A,192 ; Low byte of 448
	CP A,L
	JP C,NOTSOUTH
	; It's SOUTH
	LD A,3;2
	LD (PD),A
	JP END_ADJUSTPDD_TO_NWES

NOTSOUTH:
; 	; Check if its EAST (should be)
; 	; It's EAST
	LD A,2
	LD (PD),A
	
END_ADJUSTPDD_TO_NWES:
	RET

; -----------------
; Generate the Maze
; -----------------
; Original BASIC code:
; 100 LET A=USR 17441                                   ; Fill the maze with all walls.
; 110 LET T=0                                           ; Initialise the count of the number of passageway insertions attempted into the maze.

; ;;Enter a loop to insert passageways into the maze.

; 120 LET X=INT (RND*4)                                 ; Select a direction ($00=North, $01=West, $02=South, $03=East)
; 130 IF PEEK 16514<16 AND RND<.9 THEN LET X=2          ; If the current position is at the far north of the maze then head south.
; 140 POKE 16517,X                                      ; Store the passageway direction.

; 150 LET X=INT (RND*6)                                 ; Pick a length of passageway.
; 160 LET T=T+X                                         ; Add the length to the passageway counter.
; 170 POKE 16516,X                                      ; Store the passageway length.

; 180 LET A=USR 17461                                   ; Insert a passageway into the maze.
; 190 IF T<800 THEN GOTO 120                            ; Repeat until 800 passageway insertion attempts have been made.

; ;;The maze has now been generated, so now insert the Exit and Rex.

; 200 POKE 16514,INT (RND*113)                          ; Select a random offset within the maze to place the Exit.
; 210 LET A=USR 17617                                   ; Attempt to place the Exit within the maze, which signals its success by setting the player's start position to $46FF.
; 220 IF PEEK 16514<>255 THEN GOTO 200                  ; If the player's start position has not been set (i.e. the Exit location selected was not good) then loop back to select a new random location for the Exit.

; 230 LET A=USR 17683                                   ; Insert Rex into the maze in the first free location within the north of the maze.

GENERATEMAZE:
	; Fill the maze with all walls.
	CALL FILLMAZE

	; ###110 LET T=0 ; Initialise the count of the number of passageway insertions attempted into the maze.
	LD H,0	; 110 LET T=0
	LD L,0

	;Enter a loop to insert passageways into the maze.
INSERTPASSAGEWAYSLOOP:
	; ATTENTION: RND PRODUCES A NUMBER BETWEEN [0,1), SO 1 IS NOT INCLUDED. E.G.:RND*6 = [0,5]
	; ###120 LET X=INT (RND*4)                                 ; Select a direction ($00=North, $01=West, $02=South, $03=East)
	LD B,4
	CALL RANDOMAR ; Saves random num (0<=A<=(B-1)) to A

	; ###130 IF PEEK 16514<16 AND RND<.9 THEN LET X=2          ; If the current position is at the far north of the maze then head south.
	; ###140 POKE 16517,X                                      ; Store the passageway direction.
	; Update heading to random num generated:
	LD (PWD),A ; Store the passageway direction.

	; If PY=1 (north of the maze), then head south - IF SOUTH->HEAD NORTH
	LD A,(PY)
	CP A,16
	JP NZ,NOHEADNORTH
HEADNORTH:
	; The part of IF PEEK 16514<16 AND RND<.9 THEN LET X=2, has the "rnd<.9" ommited to prevent risk of double passageways at the south of the maze
	LD B,10
	CALL RANDOMAR
	CP A,9			; RND<(9/10) -> Change heading
	JP NC,NOHEADNORTH
	LD A,0 ; NORTH=0
	LD (PWD),A ; Store the passageway direction.
NOHEADNORTH:

	; ###150 LET X=INT (RND*6)	; Pick a length of passageway 0-5
	LD B,6
	CALL RANDOMAR

	LD B,0
	LD C,A		; BC = RND*6
	
	; ###160 LET T=T+X	; Add the length to the passageway counter.
	ADD HL,BC

	; ###170 POKE 16516,X  ; Store the passageway length - in player direction
	LD (PD),A

	; ###180 LET A=USR 17461  ; Insert a passageway into the maze.
	PUSH HL
	CALL INSERTPASSAGEWAY
	POP HL

	; ###190 IF T<800 THEN GOTO 120  ; Repeat until 800 passageway insertion attempts have been made.
	LD A,%00000011 ; Upper byte of 800 (0000 0011 0010 0000)
	CP A,H
    JP NC,INSERTPASSAGEWAYSLOOP ; IF A >= L(COUNTER), JUMP


	; ;;The maze has now been generated, so now insert the Exit and Rex.
INSERT_EXIT_AND_REX:
	; 200 POKE 16514,INT (RND*113)				; Select a random offset within the maze to place the Exit.
	;X=MAX 16
	;Y=MAX 18
	LD B,7
	CALL RANDOMAR	; RND*B -> A
	LD (PY),A
	LD B,6
	CALL RANDOMAR	; RND*B -> A
	LD (PX),A
	; LD B,0
	; LD C,A
	; LD HL,MAZE
	; ADD HL,BC
	; LD A,_ME
	; LD (HL),A

	; 210 LET A=USR 17617						; Attempt to place the Exit within the maze, which signals its success by setting the player's start position to $46FF.
	CALL INSERTEXIT
	; 220 IF PEEK 16514<>255 THEN GOTO 200		; If the player's start position has not been set (i.e. the Exit location selected was not good) then loop back to select a new random location for the Exit.
	; 16514 = PY
	LD A,(PY)
	CP A,16
	JP NZ,INSERT_EXIT_AND_REX

	; 230 LET A=USR 17683						; Insert Rex into the maze in the first free location within the north of the maze.
	CALL INSERTREX
 
	RET


; ----------------
; Draw the 3D View
; ----------------
; GAME GUI SIZE: 68x56
; The view is divided into 7 sections that correspond to different distances:
; - Section -1 is 24 characters tall (48b) and 2 (4b) characters wide. (frame)
; - Section  0 is 24 characters tall (48b) and 6 (12b) characters wide.
; - Section  1 is 22 characters tall (44b) and 4 (8b) characters wide.
; - Section  2 is 14 characters tall (28b) and 3 (6b) characters wide
; - Section  3 is  8 characters tall (16b) and 2 (4b) characters wide.
; - Section  4 is  4 characters tall  (8b) and 1 (2b) characters wide.
; - Section  5 is  2 characters tall  (4b) and 1 (2b) characters wide.
; - Section  6 is  2 characters tall  (4b) and 1 (2b) characters wide.
;
; 0|    |   |  | | | | | |  |   |    |0              |    |   |  | | | | | |  |   |    |0
; 0|1   |   |  | | | | | |  |   |   1|0             0|1   |   |  | | | | | |  |   |    |0
; 0|11  |   |  | | | | | |  |   |  11|0             0|11  |   |  | | | | | |  |   |    |0
; 0|111 |   |  | | | | | |  |   | 111|0             0|111 |   |  | | | | | |  |   |    |0
; 0|1111|   |  | | | | | |  |   |1111|0             0|1111|   |  | | | | | |  |   |    |0
; 0|1111|2  |  | | | | | |  |  2|1111|0             0|1111|   |  | | | | | |  |  2|1111|0
; 0|1111|22 |  | | | | | |  | 22|1111|0             0|1111|   |  | | | | | |  | 22|1111|0
; 0|1111|222|  | | | | | |  |222|1111|0             0|1111|   |  | | | | | |  |222|1111|0
; 0|1111|222|3 | | | | | | 3|222|1111|0             0|1111|222|3 | | | | | |  |222|1111|0
; 0|1111|222|33| | | | | |33|222|1111|0             0|1111|222|33| | | | | |  |222|1111|0
; 0|1111|222|33|4| | | |4|33|222|1111|0             0|1111|222|33| | | | |4|33|222|1111|0
; 0|1111|222|33|4|5|6|5|4|33|222|1111|0             0|1111|222|33|4|5|6|5|4|33|222|1111|0
; 0|1111|222|33|4|5|6|5|4|33|222|1111|0             0|1111|222|33|4|5|6|5|4|33|222|1111|0
; 0|1111|222|33|4| | | |4|33|222|1111|0             0|1111|222|33| | | | |4|33|222|1111|0
; 0|1111|222|33| | | | | |33|222|1111|0             0|1111|222|33| | | | | |  |222|1111|0
; 0|1111|222|3 | | | | | | 3|222|1111|0             0|1111|222|3 | | | | | |  |222|1111|0
; 0|1111|222|  | | | | | |  |222|1111|0             0|1111|   |  | | | | | |  |222|1111|0
; 0|1111|22 |  | | | | | |  | 22|1111|0             0|1111|   |  | | | | | |  | 22|1111|0
; 0|1111|2  |  | | | | | |  |  2|1111|0             0|1111|   |  | | | | | |  |  2|1111|0
; 0|1111|   |  | | | | | |  |   |1111|0             0|1111|   |  | | | | | |  |   |    |0
; 0|111 |   |  | | | | | |  |   | 111|0             0|111 |   |  | | | | | |  |   |    |0
; 0|11  |   |  | | | | | |  |   |  11|0             0|11  |   |  | | | | | |  |   |    |0
; 0|1   |   |  | | | | | |  |   |   1|0             0|1   |   |  | | | | | |  |   |    |0
; 0|ssss|sss|ss|s|s|s|s|s|ss|sss|sss |0              |ssss|sss|ss|s|s|s|s|s|ss|sss|sss |0
;
; The status message appears on row 23 between columns 1 and 22.
;
; Section 6 will display as chequerboard if there is a wall at this distance, or black if not.
; Rex is only visible at distance 5 or closer.
;
;
; The following actions are performed:
; - Draw the wall side / passageway gap next to the player on the right (section 0)
; - Draw the wall side / passageway gap next to the player on the left (section 0)
; - Enter a loop for sections 1 to 5 performing the following actions:
;    - If a wall is in front of the player then
;      - Draw the wall face
;      - If at the Exit then
;        - Draw the Exit pattern
;    - Else
;      - Draw the wall side / passageway gap on the right
;      - Draw the wall side / passageway gap on the left
; - Draw distance 6, which is either a wall face (chequerboard) or further distance not visible (black)
; - Enter a loop from section 5 and moving towards the player performing the following actions:
;   - Draw all visible wall faces on the left
;   - Draw all visible wall faces on the right
; - If Rex is ahead and within visible range then
;   - Draw Rex
DRAW3DVIEW:
	LD A,(RENDERFLAGS)
	BIT 0,A
	JP NZ,DRAW3DVIEW_RC

	CALL GETSEENMAZE		; Save 7x3 cells in FOV in SEENMAZE

	; Now, draw each section taking in account only SEENMAZE
	; Sections are drawn from the nearest to the player to the furthest

SECTION0: ;SECTION0;SECTION0;SECTION0;SECTION0;SECTION0;SECTION0;SECTION0;SECTION0
	LD A,(SEENMAZE)		; Left to the player
	CP A,_MW
	JP Z,S0LW
	; Goes here if left cell is empty
	LD B,0
	LD C,GAME_H-SIZE_S0

	LD A,FRAME_W
	CALL DRAWSECTIONE	; Draw ▒ frame

	LD A,SIZE_S0
	CALL DRAWSECTIONE

	JP SECTION0R

S0LW:
	LD B,0
	LD C,GAME_H

	LD A,FRAME_W
	CALL DRAWSECTIONF	; Draw █ frame
	
	LD A,SIZE_S0
	CALL DRAWSECTION

	JP SECTION0R

SECTION0R:
	LD A,(SEENMAZE+14)		; Right to the player
	CP A,_MW
	JP Z,S0RW
	; Goes here if right cell is empty
	LD B,GAME_W-FRAME_W-0
	LD C,GAME_H-SIZE_S0
	LD A,FRAME_W
	CALL DRAWSECTIONE

	LD B,GAME_W-FRAME_W-SIZE_S0-0
	LD C,GAME_H-SIZE_S0
	LD A,SIZE_S0
	CALL DRAWSECTIONE

	JP SECTION1
S0RW:
	LD B,GAME_W-FRAME_W-0
	LD C,GAME_H
	LD A,FRAME_W
	CALL DRAWSECTIONF

	LD B,GAME_W-FRAME_W-SIZE_S0-0
	LD C,GAME_H-SIZE_S0+1
	LD A,SIZE_S0
	CALL DRAWSECTIONR

	JP SECTION1


SECTION1: ;SECTION1;SECTION1;SECTION1;SECTION1;SECTION1;SECTION1;SECTION1;SECTION1
	LD A,(SEENMAZE+7) ; Check 0 positions in front of player if theres the exit
	CP A,_ME
	JP Z,S1EXIT
	; First check if theres a wall in front of the player
	LD A,(SEENMAZE+8)
	CP A,_MW
	JP Z,S1WALL
	JP SECTION1CONT
S1WALL:
	LD B,FRAME_W+SIZE_S0 ; Start of wall (X)
	LD C,GAME_H-SIZE_S0 ; Height of the wall
	LD A,GAME_W-SIZE_S0-SIZE_S1 ; End of wall (X)
	CALL DRAWSECTIONE
	JP DRAW3DVIEWCOMMIT
S1EXIT:
	LD B,FRAME_W+SIZE_S0 ; Start of wall (X)
	LD C,GAME_H-SIZE_S0 ; Height of the wall
	LD A,GAME_W-SIZE_S0-SIZE_S1 ; End of wall (X)
	CALL DRAWEXIT
	JP DRAW3DVIEWCOMMIT

SECTION1CONT:
	LD A,(SEENMAZE+1)		; Left to the player
	CP A,_MW
	JP Z,S1LW
	; Goes here if left cell is empty
	LD B,FRAME_W+SIZE_S0
	LD C,GAME_H-SIZE_S0-SIZE_S1

	LD A,SIZE_S1
	CALL DRAWSECTIONE

	JP SECTION1R

S1LW:
	LD B,FRAME_W+SIZE_S0
	LD C,GAME_H-SIZE_S0
	
	LD A,SIZE_S1
	CALL DRAWSECTION

	JP SECTION1R

SECTION1R:
	LD A,(SEENMAZE+15)		; Right to the player
	CP A,_MW
	JP Z,S1RW
	; Goes here if right cell is empty
	LD B,GAME_W-FRAME_W-SIZE_S0-SIZE_S1-0
	LD C,GAME_H-SIZE_S0-SIZE_S1
	LD A,SIZE_S1
	CALL DRAWSECTIONE

	JP SECTION2
S1RW:
	LD B,GAME_W-FRAME_W-SIZE_S0-SIZE_S1-0
	LD C,GAME_H-SIZE_S0-SIZE_S1+1
	LD A,SIZE_S1
	CALL DRAWSECTIONR

	JP SECTION2

SECTION2: ;SECTION2;SECTION2;SECTION2;SECTION2;SECTION2;SECTION2;SECTION2;SECTION2
	LD A,(SEENMAZE+8) ; Check 1 positions in front of player if theres the exit
	CP A,_ME
	JP Z,S2EXIT
	; First check if theres a wall in front of the player
	LD A,(SEENMAZE+9)
	CP A,_MW
	JP Z,S2WALL
	JP SECTION2CONT
S2WALL:
	LD B,FRAME_W+SIZE_S0+SIZE_S1
	LD C,GAME_H-SIZE_S0-SIZE_S1
	LD A,GAME_W-SIZE_S0-SIZE_S1-SIZE_S2
	CALL DRAWSECTIONE
	JP DRAW3DVIEWCOMMIT
S2EXIT:
	LD B,FRAME_W+SIZE_S0+SIZE_S1
	LD C,GAME_H-SIZE_S0-SIZE_S1
	LD A,38;GAME_W-SIZE_S0-SIZE_S1-SIZE_S2
	CALL DRAWEXIT
	JP DRAW3DVIEWCOMMIT

SECTION2CONT:
	LD A,(SEENMAZE+2)		; Left to the player
	CP A,_MW
	JP Z,S2LW
	; Goes here if left cell is empty
	LD B,FRAME_W+SIZE_S0+SIZE_S1
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2
	LD A,SIZE_S2
	CALL DRAWSECTIONE

	JP SECTION2R

S2LW:
	LD B,FRAME_W+SIZE_S0+SIZE_S1
	LD C,GAME_H-SIZE_S0-SIZE_S1
	LD A,SIZE_S2
	CALL DRAWSECTION

	JP SECTION2R

SECTION2R:
	LD A,(SEENMAZE+16)		; Right to the player
	CP A,_MW
	JP Z,S2RW
	; Goes here if right cell is empty
	LD B,GAME_W-FRAME_W-SIZE_S0-SIZE_S1-SIZE_S2-0
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2
	LD A,SIZE_S2
	CALL DRAWSECTIONE

	JP SECTION3
S2RW:
	LD B,GAME_W-FRAME_W-SIZE_S0-SIZE_S1-SIZE_S2-0
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2+1			;?????
	LD A,SIZE_S2
	CALL DRAWSECTIONR

	JP SECTION3

SECTION3: ;SECTION3;SECTION3;SECTION3;SECTION3;SECTION3;SECTION3;SECTION3;SECTION3
	LD A,(SEENMAZE+9) ; Check 2 positions in front of player if theres the exit
	CP A,_ME
	JP Z,S3EXIT
	; First check if theres a wall in front of the player
	LD A,(SEENMAZE+10)
	CP A,_MW
	JP Z,S3WALL
	JP SECTION3CONT
S3WALL:
	LD B,FRAME_W+SIZE_S0+SIZE_S1+SIZE_S2
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2
	LD A,GAME_W-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3
	CALL DRAWSECTIONE
	JP DRAW3DVIEWCOMMIT
S3EXIT:
	LD B,FRAME_W+SIZE_S0+SIZE_S1+SIZE_S2
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2
	LD A,26;GAME_W-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3
	CALL DRAWEXIT
	JP DRAW3DVIEWCOMMIT

SECTION3CONT:
	LD A,(SEENMAZE+3)		; Left to the player
	CP A,_MW
	JP Z,S3LW
	; Goes here if left cell is empty
	LD B,FRAME_W+SIZE_S0+SIZE_S1+SIZE_S2
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3
	LD A,SIZE_S3
	CALL DRAWSECTIONE

	JP SECTION3R

S3LW:
	LD B,FRAME_W+SIZE_S0+SIZE_S1+SIZE_S2
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2
	LD A,SIZE_S3
	CALL DRAWSECTION

	JP SECTION3R

SECTION3R:
	LD A,(SEENMAZE+17)		; Right to the player
	CP A,_MW
	JP Z,S3RW
	; Goes here if right cell is empty
	LD B,GAME_W-FRAME_W-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3-0
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3
	LD A,SIZE_S3
	CALL DRAWSECTIONE

	JP SECTION4
S3RW:
	LD B,GAME_W-FRAME_W-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3-0
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3+1			;?????
	LD A,SIZE_S3
	CALL DRAWSECTIONR

	JP SECTION4

SECTION4: ;SECTION4;SECTION4;SECTION4;SECTION4;SECTION4;SECTION4;SECTION4;SECTION4
	LD A,(SEENMAZE+10) ; Check 3 positions in front of player if theres the exit
	CP A,_ME
	JP Z,S4EXIT
	; First check if theres a wall in front of the player
	LD A,(SEENMAZE+11)
	CP A,_MW
	JP Z,S4WALL
	JP SECTION4CONT
S4WALL:
	LD B,FRAME_W+SIZE_S0+SIZE_S1+SIZE_S2+SIZE_S3
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3
	LD A,18													;?????
	CALL DRAWSECTIONE
	JP DRAW3DVIEWCOMMIT
S4EXIT:
	LD B,FRAME_W+SIZE_S0+SIZE_S1+SIZE_S2+SIZE_S3
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3
	LD A,18
	CALL DRAWEXIT
	JP DRAW3DVIEWCOMMIT

SECTION4CONT:
	LD A,(SEENMAZE+4)		; Left to the player
	CP A,_MW
	JP Z,S4LW
	; Goes here if left cell is empty
	LD B,FRAME_W+SIZE_S0+SIZE_S1+SIZE_S2+SIZE_S3
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3-SIZE_S4
	LD A,SIZE_S4
	CALL DRAWSECTIONE

	JP SECTION4R

S4LW:
	LD B,FRAME_W+SIZE_S0+SIZE_S1+SIZE_S2+SIZE_S3
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3
	LD A,SIZE_S4
	CALL DRAWSECTION

	JP SECTION4R

SECTION4R:
	LD A,(SEENMAZE+18)		; Right to the player
	CP A,_MW
	JP Z,S4RW
	; Goes here if right cell is empty
	LD B,GAME_W-FRAME_W-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3-SIZE_S4-0
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3-SIZE_S4
	LD A,SIZE_S4
	CALL DRAWSECTIONE

	JP SECTION5
S4RW:
	LD B,GAME_W-FRAME_W-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3-SIZE_S4-0
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3-SIZE_S4+1			;?????
	LD A,SIZE_S4
	CALL DRAWSECTIONR

	JP SECTION5

SECTION5: ;SECTION5;SECTION5;SECTION5;SECTION5;SECTION5;SECTION5;SECTION5;SECTION5
	LD A,(SEENMAZE+11) ; Check 4 positions in front of player if theres the exit
	CP A,_ME
	JP Z,S5EXIT
	; First check if theres a wall in front of the player
	LD A,(SEENMAZE+12)
	CP A,_MW
	JP Z,S5WALL
	JP SECTION5CONT
S5WALL:
	LD B,FRAME_W+SIZE_S0+SIZE_S1+SIZE_S2+SIZE_S3+SIZE_S4
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3-SIZE_S4
	LD A,14													;?????
	CALL DRAWSECTIONE
	JP DRAW3DVIEWCOMMIT
S5EXIT:
	LD B,FRAME_W+SIZE_S0+SIZE_S1+SIZE_S2+SIZE_S3+SIZE_S4
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3-SIZE_S4
	LD A,14
	CALL DRAWEXIT
	JP DRAW3DVIEWCOMMIT

SECTION5CONT:
	LD A,(SEENMAZE+5)		; Left to the player
	CP A,_MW
	JP Z,S5LW
	; Goes here if left cell is empty
	LD B,FRAME_W+SIZE_S0+SIZE_S1+SIZE_S2+SIZE_S3+SIZE_S4
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3-SIZE_S4-SIZE_S5
	LD A,SIZE_S5
	CALL DRAWSECTIONE

	JP SECTION5R

S5LW:
	LD B,FRAME_W+SIZE_S0+SIZE_S1+SIZE_S2+SIZE_S3+SIZE_S4
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3-SIZE_S4
	LD A,SIZE_S5
	CALL DRAWSECTION

	JP SECTION5R

SECTION5R:
	LD A,(SEENMAZE+19)		; Right to the player
	CP A,_MW
	JP Z,S5RW
	; Goes here if right cell is empty
	LD B,GAME_W-FRAME_W-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3-SIZE_S4-SIZE_S5-0
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3-SIZE_S4-SIZE_S5
	LD A,SIZE_S5
	CALL DRAWSECTIONE

	JP SECTION6
S5RW:
	LD B,GAME_W-FRAME_W-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3-SIZE_S4-SIZE_S5-0
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3-SIZE_S4-SIZE_S5+1			;?????
	LD A,SIZE_S5
	CALL DRAWSECTIONR

	JP SECTION6

SECTION6: ;SECTION6;SECTION6;SECTION6;SECTION6;SECTION6;SECTION6;SECTION6;SECTION6
	LD A,(SEENMAZE+12) ; Check 5 positions in front of player if theres the exit
	CP A,_ME
	JP Z,S6EXIT
	; First check if theres a wall in front of the player
	LD A,(SEENMAZE+13)
	CP A,_MW
	JP Z,S6WALL
	JP SECTION6E
S6WALL:
	LD B,FRAME_W+SIZE_S0+SIZE_S1+SIZE_S2+SIZE_S3+SIZE_S4+SIZE_S5
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3-SIZE_S4-SIZE_S5
	LD A,12													;?????
	CALL DRAWSECTIONE
	JP DRAW3DVIEWCOMMIT
S6EXIT:
	LD B,FRAME_W+SIZE_S0+SIZE_S1+SIZE_S2+SIZE_S3+SIZE_S4+SIZE_S5
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3-SIZE_S4-SIZE_S5
	LD A,12
	CALL DRAWEXIT
	JP DRAW3DVIEWCOMMIT

SECTION6E:
	LD B,FRAME_W+SIZE_S0+SIZE_S1+SIZE_S2+SIZE_S3+SIZE_S4+SIZE_S5
	LD C,GAME_H-SIZE_S0-SIZE_S1-SIZE_S2-SIZE_S3-SIZE_S4-SIZE_S5
	LD A,12													;?????
	CALL DRAWSECTIONF
	JP DRAW3DVIEWCOMMIT

DRAW3DVIEWCOMMIT:
	;CALL CHECKREX ;DEBUG
	; CALL DRAWREX
	CALL DISPSCREEN

DRAW3DEND:
	;CALL CHECKREX ;DEBUG
	RET

; Ray casted version of the DRAW3DVIEW subroutine
; DRAW3DVIEW_RAYCAST
; PSEUDOCODE:  by Hans Törnqvist (https://www.ticalc.org/archives/files/fileinfo/196/19646.html)
;
; 		  copy player direction to ray angle
;         angle - 32 (FOV / 2), so that we start from one side of the display
;
;         for column = 0 to 63
;                 copy player location to ray location
;                 get stepping variables from angle
;
;                 repeat
;                         update ray location with stepping variables
;                 until a wall is hit
;
;                 calculate wall height depending on distance
;
;                 draw wall section at column
;
;                 increase angle
;         end for

; Use the 9 first bits as decimals
#DEFINE FPM             512

; Trigonometrics
#DEFINE CIRCLE          512
#DEFINE QUARTER         128
#DEFINE HALF            256

; Player-specific definitions
#DEFINE TURN      		20
#DEFINE TURN_SUBCIRCLE	CIRCLE - TURN     ; CIRCLE - RIGHT_TURN
#DEFINE STEPXY 			128

#DEFINE FOV				144

; _________________
; |end\/////start
; |\\\\////
; | \\\///  ←direction of ray angles (decreasing)←
; |  \\//
; |   \/
; |    o

; Relation of orientation PD ~ PDD
;
; ___|__PD______PDD_______RANGE____
;  N |   0	    256		[192,320)
;  S |   2	      0		[448, 64)
;  W |   1	    384		[320,448)
;  E |   3	    128		[64, 192)


DRAW3DVIEW_RC:
	XOR A
	LD (INCANGLEDIV),A
	; Convert player direction (angle - (FOV / 2))
	LD HL,(PDD)
	LD BC,FOV/2
	; AND  A
    ; SBC HL,BC
	ADD HL,BC

    CALL CLAMPANGLE
    LD (CASTINGANGLE),HL

    ; RESET COLUMN COUNTER
    XOR A
    LD (SCREENCOLUMN),A 

RAYCASTCOLUMNLOOP:
        ; COPY LOCATION OF PLAYER
        LD HL,(PDX)
        LD (RAYX),HL ; Ray location X
        LD HL,(PDY)
        LD (RAYY),HL ; Ray location Y

        ; GET TRIG STEPS
        LD HL, (CASTINGANGLE)
        CALL GETTRIGS

        ; RESET DISTANCE
        XOR A
        LD (RAYLENGTH), A

RAYCASTINGLOOP:
        ; UPDATE VARIABLES
        ; X COORDINATE
        LD HL, (RAYX)
        LD A, (COS)
        CALL STEP
        LD (RAYX), HL
        ; Y COORDINATE
        LD HL, (RAYY)
        LD A, (SIN)
        CALL STEP
        LD (RAYY), HL

        ; DISTANCE / RAYLENGTH
        LD A,(RAYLENGTH)
        INC A
        LD (RAYLENGTH), A

        ; SAVE NON-FPM LOCATION
        LD HL, (RAYX)
        CALL REMOVEFPM
        LD (TEMPPDX), A
        LD HL, (RAYY)
        CALL REMOVEFPM
        LD (TEMPPDY), A

        ; CHECK WALLHIT
        CALL CHECKHIT
        OR A ; Check if its 0
        JR Z,RAYCASTINGLOOP

        ; STORE DISTANCE/RAYLENGTH
		; -> Paint ray (column)
        ; LD      HL, ZBUFFER
        ; LD      A, (SCREENCOLUMN)
        ; LD      B, 0
        ; LD      C, A
        ; ADD     HL, BC
        ; LD      A, (RAYLENGTH)
        ; LD      (HL), A

		LD A,(RAYLENGTH) ; Height of the column
		LD HL,HEIGHT
        LD B,0
        LD C,A
        ADD HL, BC
        LD A,(HL)
        LD C,A
        CP (GAME_H/2)+1
        JR Z,OUTOFDISPLAY
        LD A,(GAME_H/2)+1
        SUB C
		LD C,A

		LD A,(SCREENCOLUMN) ; X on screen
		LD B,A

		; LD A,GAME_W 	; To flip image vertically
		; SUB A,B			; GAME_W - X
		; LD B,A
		PUSH BC
		CALL CHECK_HIT_EXIT
        OR A ; Check if its 0
		POP BC
        JR Z,NORMALDRAW_RC
		CALL DRAWVLINE_RAY_EXIT
		JP OUTOFDISPLAY
NORMALDRAW_RC:
		CALL DRAWVLINE_RAY

OUTOFDISPLAY:

        ; UPDATE ANGLE
        LD HL, (CASTINGANGLE)
        DEC HL
		DEC HL ; To double FOV

		; Skip lines which index is divisble by 5
		; This way we eliminate 28 angles
		LD A,(INCANGLEDIV)
		CP A,4
		JP NZ,ANGLENODIVBY4
		LD A,0
		INC HL
ANGLENODIVBY4:
		INC A
		LD (INCANGLEDIV),A

		; INC     HL ; To triple FOV
        CALL CLAMPANGLE
        LD (CASTINGANGLE), HL

        ; UPDATE COLUMN LOOP
        LD A, (SCREENCOLUMN)
        INC A
        LD (SCREENCOLUMN), A
        CP GAME_W
        JP NZ, RAYCASTCOLUMNLOOP

	CALL DISPSCREEN ; Original lo imprime en el GAMELOOP
	RET

; =========================== ;
; CLAMP HL INSIDE ANGLE RANGE ;
; =========================== ;
CLAMPANGLE:
	LD A,H
	AND 1
	LD H,A
	LD A,L
	AND 255
	LD L,A
	RET

; ====================== ;
; GET TRIGS FOR ANGLE HL ;
; ====================== ;
GETTRIGS:
	; SIN
	LD BC,TRIGS
	ADD HL,BC
	LD A,(HL)
	LD (COS),A
	; COS
	LD BC,QUARTER
	ADD HL,BC
	LD A,(HL)
	LD (SIN),A
	RET


; ============ ;
; STEP HL BY A ;
; ============ ;
STEP:
	LD B,0
	LD C,A
	AND 80H
	OR A
	JR Z,ADDSTEP
	LD B,255
ADDSTEP:
	ADD HL,BC
	RET


; =================== ;
; REMOVES FPM FROM HL ;
; =================== ;
REMOVEFPM:
	LD A, H
	SRA A
	RET

; Trig table. 0..511 -> Sin, 128..639 -> Cos : 640 bytes!
TRIGS:
	.DB     0, 1, 3, 4, 6, 7, 9, 10
	.DB     12, 13, 15, 17, 18, 20, 21, 23
	.DB     24, 26, 27, 29, 30, 32, 33, 35
	.DB     36, 38, 39, 41, 42, 44, 45, 47
	.DB     48, 50, 51, 52, 54, 55, 57, 58
	.DB     59, 61, 62, 63, 65, 66, 67, 69
	.DB     70, 71, 73, 74, 75, 76, 78, 79
	.DB     80, 81, 82, 84, 85, 86, 87, 88
	.DB     89, 90, 91, 93, 94, 95, 96, 97
	.DB     98, 99, 100, 101, 102, 102, 103, 104
	.DB     105, 106, 107, 108, 108, 109, 110, 111
	.DB     112, 112, 113, 114, 114, 115, 116, 116
	.DB     117, 117, 118, 119, 119, 120, 120, 121
	.DB     121, 121, 122, 122, 123, 123, 123, 124
	.DB     124, 124, 125, 125, 125, 125, 126, 126
	.DB     126, 126, 126, 126, 126, 126, 126, 126
	.DB     127, 126, 126, 126, 126, 126, 126, 126
	.DB     126, 126, 126, 125, 125, 125, 125, 124
	.DB     124, 124, 123, 123, 123, 122, 122, 121
	.DB     121, 121, 120, 120, 119, 119, 118, 117
	.DB     117, 116, 116, 115, 114, 114, 113, 112
	.DB     112, 111, 110, 109, 108, 108, 107, 106
	.DB     105, 104, 103, 102, 102, 101, 100, 99
	.DB     98, 97, 96, 95, 94, 93, 91, 90
	.DB     89, 88, 87, 86, 85, 84, 82, 81
	.DB     80, 79, 78, 76, 75, 74, 73, 71
	.DB     70, 69, 67, 66, 65, 63, 62, 61
	.DB     59, 58, 57, 55, 54, 52, 51, 50
	.DB     48, 47, 45, 44, 42, 41, 39, 38
	.DB     36, 35, 33, 32, 30, 29, 27, 26
	.DB     24, 23, 21, 20, 18, 17, 15, 13
	.DB     12, 10, 9, 7, 6, 4, 3, 1
	.DB     0, -1, -3, -4, -6, -7, -9, -10
	.DB     -12, -13, -15, -17, -18, -20, -21, -23
	.DB     -24, -26, -27, -29, -30, -32, -33, -35
	.DB     -36, -38, -39, -41, -42, -44, -45, -47
	.DB     -48, -50, -51, -52, -54, -55, -57, -58
	.DB     -59, -61, -62, -63, -65, -66, -67, -69
	.DB     -70, -71, -73, -74, -75, -76, -78, -79
	.DB     -80, -81, -82, -84, -85, -86, -87, -88
	.DB     -89, -90, -91, -93, -94, -95, -96, -97
	.DB     -98, -99, -100, -101, -102, -102, -103, -104
	.DB     -105, -106, -107, -108, -108, -109, -110, -111
	.DB     -112, -112, -113, -114, -114, -115, -116, -116
	.DB     -117, -117, -118, -119, -119, -120, -120, -121
	.DB     -121, -121, -122, -122, -123, -123, -123, -124
	.DB     -124, -124, -125, -125, -125, -125, -126, -126
	.DB     -126, -126, -126, -126, -126, -126, -126, -126
	.DB     -127, -126, -126, -126, -126, -126, -126, -126
	.DB     -126, -126, -126, -125, -125, -125, -125, -124
	.DB     -124, -124, -123, -123, -123, -122, -122, -121
	.DB     -121, -121, -120, -120, -119, -119, -118, -117
	.DB     -117, -116, -116, -115, -114, -114, -113, -112
	.DB     -112, -111, -110, -109, -108, -108, -107, -106
	.DB     -105, -104, -103, -102, -102, -101, -100, -99
	.DB     -98, -97, -96, -95, -94, -93, -91, -90
	.DB     -89, -88, -87, -86, -85, -84, -82, -81
	.DB     -80, -79, -78, -76, -75, -74, -73, -71
	.DB     -70, -69, -67, -66, -65, -63, -62, -61
	.DB     -59, -58, -57, -55, -54, -52, -51, -50
	.DB     -48, -47, -45, -44, -42, -41, -39, -38
	.DB     -36, -35, -33, -32, -30, -29, -27, -26
	.DB     -24, -23, -21, -20, -18, -17, -15, -13
	.DB     -12, -10, -9, -7, -6, -4, -3, -1
	.DB     0, 1, 3, 4, 6, 7, 9, 10
	.DB     12, 13, 15, 17, 18, 20, 21, 23
	.DB     24, 26, 27, 29, 30, 32, 33, 35
	.DB     36, 38, 39, 41, 42, 44, 45, 47
	.DB     48, 50, 51, 52, 54, 55, 57, 58
	.DB     59, 61, 62, 63, 65, 66, 67, 69
	.DB     70, 71, 73, 74, 75, 76, 78, 79
	.DB     80, 81, 82, 84, 85, 86, 87, 88
	.DB     89, 90, 91, 93, 94, 95, 96, 97
	.DB     98, 99, 100, 101, 102, 102, 103, 104
	.DB     105, 106, 107, 108, 108, 109, 110, 111
	.DB     112, 112, 113, 114, 114, 115, 116, 116
	.DB     117, 117, 118, 119, 119, 120, 120, 121
	.DB     121, 121, 122, 122, 123, 123, 123, 124
	.DB     124, 124, 125, 125, 125, 125, 126, 126
	.DB     126, 126, 126, 126, 126, 126, 126, 126

; Height table for slivers (focus = 127, height = 1, distance = 0..90)
HEIGHT:
	; .DB   32, 32, 32, 31, 25, 21, 18, 15, 14, 14
	; .DB   11, 10, 9, 9, 8, 7, 7, 7, 6, 6
	; .DB   6, 5, 5, 5, 5, 4, 4, 4, 4, 4
	; .DB   4, 3, 3, 3, 3, 3, 3, 3, 3, 3
	; .DB   3, 3, 2, 2, 2, 2, 2, 2, 2, 2
	; .DB   2, 2, 2, 2, 2, 2, 2, 2, 2, 2
	; .DB   2, 2, 2, 1, 1, 1, 1, 1, 1, 1
	; .DB   1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	; .DB   1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	.DB     27, 27, 26, 26, 22, 18, 15, 12, 11, 11
	.DB     9, 8, 7, 7, 6, 5, 5, 5, 4, 4
	.DB     4, 3, 3, 3, 3, 2, 2, 2, 2, 2
	.DB     2, 2, 2, 2, 2, 2, 2, 2, 2, 2
	.DB     2, 2, 1, 1, 1, 1, 1, 1, 1, 1
	.DB     1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	.DB     1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	.DB     1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	.DB     1, 1, 1, 1, 1, 1, 1, 1, 1, 1

; =========================== ;
; Have we hit a wall or exit? ;
; =========================== ;
CHECKHIT:
	LD A,(TEMPPDX)
	LD D,A
	LD A,(TEMPPDY)
	LD E,A
	CALL GET_POS
	LD A,_MW
	CP A,L
	JP NZ,TESTEXIT
	; Wall hit
	LD A,1
	JP ENDCHECKHIT

TESTEXIT:
	LD A,_ME
	CP A,L
	JP NZ,NOHIT
	; Exit hit
	LD A,1
	JP ENDCHECKHIT

NOHIT:
	LD A,0
ENDCHECKHIT:
	RET

; =================== ;
; Have we hit the Exit? ;
; =================== ;
CHECK_HIT_EXIT:
	LD A,(TEMPPDX)
	LD D,A
	LD A,(TEMPPDY)
	LD E,A
	CALL GET_POS
	LD A,_ME
	CP A,L
	JP NZ,NOHIT_EXIT
	; Exit hit
	LD A,1
	JP ENDCHECK_HIT_EXIT
NOHIT_EXIT:
	LD A,0
ENDCHECK_HIT_EXIT:
	RET


; Clear 3D view on SCREEN
CLEAR3DVIEW:
	LD HL,SCREEN
	BCALL(_BufClr)
	RET

; Refresh (redisplay) Screen
; Destroys: E,D,HL
DISPSCREEN:
	; LD  E,0
    ; LD  D,0
	; LD HL,SCREEN
	; B_CALL(_DisplayImage)
	LD HL,SCREEN
	B_CALL(_BufCpy)
	RET

; Draw wall (opaque) section with positionOnScreen(B),heightOfStartLine(C),widthOfSection(A)
DRAWSECTION:
DSLOOP:
	PUSH BC
	PUSH AF
    CALL DRAWVLINE
	POP AF
	POP BC
	INC B
	DEC C	;!
	DEC A
	JP NZ,DSLOOP
DSEND:
	RET

; Draw wall (opaque) section with positionOnScreen(B),heightOfStartLine(C),widthOfSection(A)
DRAWSECTIONR:
DSRLOOP:
	PUSH BC
	PUSH AF
    CALL DRAWVLINE
	POP AF
	POP BC
	INC B
	INC C	;!
	DEC A
	JP NZ,DSRLOOP
DSREND:
	RET

; Draw empty (grid)  section with positionOnScreen(B),heightOfStartLine(C),widthOfSection(A)
; Same as DRAWSECTIONFE
DRAWSECTIONE:
DSELOOP:
	PUSH BC
	PUSH AF
    CALL DRAWVLINE_HALF
	POP AF
	POP BC
	INC B
	DEC A
	JP NZ,DSELOOP
DSEEND:
	RET

; Draw exit section with positionOnScreen(B),heightOfStartLine(C),widthOfSection(A)
DRAWEXIT:
DELOOP:
	PUSH BC
	PUSH AF
    CALL DRAWVLINE
	POP AF
	POP BC
	INC B
	INC B
	DEC A
	DEC A
	CP A,222
	JP NC,DEEND ; Leave some margin for width of section (overflow "protection")
	; CP A,254
	; JP Z,DEEND
	; CP A,253
	; JP Z,DEEND
	CP A,0
	JP NZ,DELOOP
DEEND:
	RET

; Draw frame(opaque) section with positionOnScreen(B),heightOfStartLine(C),widthOfSection(A)
DRAWSECTIONF:
DSFLOOP:
	PUSH BC
	PUSH AF
    CALL DRAWVLINE
	POP AF
	POP BC
	INC B
	DEC A
	JP NZ,DSFLOOP
DSFEND:
	RET


; Draw vertical line on screen on x(B),y0(C) upto its simetric point having GAME_H/2 as the center line
DRAWVLINE:
	LD A,GAME_H
	SUB A,C
DLLOOP:
	PUSH BC
	PUSH AF
	CALL SET_SCREEN_BIT
	POP AF
	POP BC

	DEC C
	CP A,C
	JP Z,DVLEND
	JP DLLOOP
DVLEND:
	CALL SET_SCREEN_BIT
	RET

; DRAW INTERMITTENT VERTICAL LINE
DRAWVLINE_HALF:
	;First see if sum of x,y0 coordinates of the vertical line is even, to alternate bits on/off
	LD A,B
	ADD A,C
	AND $01
	JR NZ,IMPAR
PAR:
	DEC C
	LD A,GAME_H
	SUB C
	DEC A
PAR_DLLOOP_H:
	PUSH BC
	PUSH AF
	CALL SET_SCREEN_BIT
	POP AF
	POP BC
	; Check if this or the next pixel to draw/skip is inside range, if not, end loop and print final pixel
	DEC C
	CP A,C
	JP Z,DVLEND_H
	DEC C
	CP A,C
	JP Z,PARDVLEND_H
	JP PAR_DLLOOP_H

IMPAR:
	LD A,GAME_H
	SUB C
	DEC A
IMPAR_DLLOOP_H:
	PUSH BC
	PUSH AF
	CALL SET_SCREEN_BIT
	POP AF
	POP BC
	; Check if this or the next pixel to draw/skip is inside range, if not, end loop and print final pixel
	DEC C
	CP A,C
	JP Z,DVLEND_H
	DEC C
	CP A,C
	JP Z,DVLEND_H
	JP IMPAR_DLLOOP_H
PARDVLEND_H:
	CALL SET_SCREEN_BIT
DVLEND_H:
	RET

; Draw vertical line on screen on x(B),y0(C) upto its simetric point having GAME_H/2 as the center line
; This variation paints only the top and bottom  pixels of the line
DRAWVLINE_RAY:
	; Paint both pixels
	PUSH BC
	CALL SET_SCREEN_BIT ; Bottom pixel
	POP BC
	DEC C
	PUSH BC
	CALL SET_SCREEN_BIT ; Bottom pixel
	POP BC

	LD A,GAME_H
	SUB A,C
	LD C,A

	PUSH BC
	CALL SET_SCREEN_BIT
	POP BC
	INC C
	CALL SET_SCREEN_BIT

DVLEND_RAY:
	RET

DRAWVLINE_RAY_EXIT:
	LD A,GAME_H
	SUB A,C
	LD C,A

	CALL DRAWVLINE_HALF ;B(X),C(Y0)

DVLEND_RAY_EXIT:
	RET


; Modify screen bit on position x(B),y(C)
; Destroys: A,B,C,HL,D
SET_SCREEN_BIT:
	; CALL MULT 		; y*96 -> HL	
	LD H,0		; Load Y into HL and multiply it by 12 (bytes per line in screen (12B*8pixels=96))
	LD L,C
	ADD HL,HL
	ADD HL,HL
	LD D,H
	LD E,L
	ADD HL,HL
	ADD HL,DE		; This is a more efficient way to multiply C*96 than calling MULT

	LD A,B
	LD B,12

	LD D,A
	CALL DIV8
	LD B,0
	LD C,A
	ADD HL,BC		; Y*96 + X -> BC

	LD B,H
	LD C,L
	LD HL,SCREEN
	ADD HL,BC

	; Now we have to pass x to the bit position knowing the least significant bit is the right one
	; [B7,B6,B5,B4,B3,B2,B1,B0][B7,B6,B5,B4,B3,B2,B1,B0]
	; So if you wanted to set the 7th bit in that, it should be the least significant on the first byte
	LD B, (HL)	; load the byte address that we want to modify of the screen in B
	LD A,D
	AND 7		; perform modulo 8 operation in A
	; TODO: Optimize this (maybe use a lookup table or something)
	; BITS_LOOKUP:	.DB 7, 6, 5, 4, 3, 2, 1, 0
	CP A,0
	JP Z,SSB0
	CP A,1
	JP Z,SSB1
	CP A,2
	JP Z,SSB2
	CP A,3
	JP Z,SSB3
	CP A,4
	JP Z,SSB4
	CP A,5
	JP Z,SSB5
	CP A,6
	JP Z,SSB6
	CP A,7
	JP Z,SSB7
	JP SSB_END

SSB0:
	SET 7, B
	JP SSB_END
SSB1:
	SET 6, B
	JP SSB_END
SSB2:
	SET 5, B
	JP SSB_END
SSB3:
	SET 4, B
	JP SSB_END
SSB4:
	SET 3, B
	JP SSB_END
SSB5:
	SET 2, B
	JP SSB_END
SSB6:
	SET 1, B
	JP SSB_END
SSB7:
	SET 0, B
	JP SSB_END
SSB_END:
	LD (HL), B
    RET

div8: ; Divide a by 8
	srl a
	srl a
	srl a
	RET


; GAME LOGIC SUBROUTINES
; Returns in L content of position X(D),Y(E) in maze (MW or MP) 
; maze is y=18,x=16 = MAZE_H,MAZE_W
; Destroys: HL,BC,A
GET_POS:
	; Calculate offset in maze (Y*MAZE_W + X)
	; LD C,E			; Load Y in C
	; LD B,MAZE_W		; Load MAZE_W in B
	; CALL MULT 		; y*16 -> HL
	LD H,0
	LD L,E			; Y -> HL

	ADD HL,HL 		; Y*16 -> HL
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL

	LD C,0			; Load 0 into C
	LD B,C			; Load C into B
	LD C,D			; Load D into C
	ADD HL,BC		; Y*16 + X -> HL

	LD BC,MAZE
	ADD HL,BC		; Add Maze address to offset

	LD L,(HL) 	; Load result in L
	LD H,0		; Clear upper part of HL
	RET

;---------------------
; Set position in maze
;---------------------
; Input: A(what to write), X(D),Y(E)
; Output: 
; Destroys: HL,BC
SET_POS:
	PUSH AF
	; Calculate offset in maze (Y*MAZE_W + X)
	; LD C,E			; Load Y in C
	; LD B,MAZE_W		; Load MAZE_W in B
	; CALL MULT 		; y*16 -> HL
	LD H,0
	LD L,E			; Y -> HL

	ADD HL,HL 		; Y*16 -> HL
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL

	LD C,0			; Load 0 into C
	LD B,C			; Load C into B
	LD C,D			; Load D into C
	ADD HL,BC		; Y*16 + X -> HL

	LD BC,MAZE
	ADD HL,BC		; Add Maze address to offset

	; LD L,(HL) 	; Load result in L
	; LD H,0		; Clear upper part of HL
	POP AF
	LD (HL),A
	RET

; Copies the seen part of the maze into SEENMAZE 6x3
; Destroys: HL,DE,AF,BC
GETSEENMAZE:
	LD HL,TEMPDISTREX ; Set 0 dist to rex
	LD (HL),0

	LD HL,(PX)
	LD D,L
	LD HL,(PY)
	LD E,L

	LD HL,(PD)
	LD A,L
	CP 0 ; NORTH
	JP Z,NORTHSEEN
	CP 2 ; SOUTH
	JP Z,SOUTHSEEN
	CP 3 ; EAST
	JP Z,EASTSEEN
	CP 1 ; WEST
	JP Z,WESTSEEN
	RET

NORTHSEEN:
	DEC D
	LD HL,SEENMAZE
	LD A,0
NSLOOP1:
	PUSH HL
	PUSH AF
	CALL GET_POS	;D=X, E=Y
	POP AF
	LD C,L
	POP HL
	LD (HL),C
	INC HL
	INC A
	; PUSH AF		; Check if E is 0 (next iteration would be negative)
	; LD A,E
	; CP A,0
	; JP Z,NS2
	; POP AF
	DEC E
	CP A,7
	JP NZ,NSLOOP1

NS2:
	LD BC,(PY)
	LD E,C
	INC D
NSLOOP2:
	PUSH HL
	PUSH AF
	CALL GET_POS
	LD C,L
	LD A,_ME
	CP A,C
	JP NZ,NSNOEXIT
	; The Exit is at this location.
	LD A,(GAMEFLAGS)	; Fetch the flags.
	SET 4,A				; Signal the Exit is visible.
	LD (GAMEFLAGS),A	; Store the updated flags.
NSNOEXIT:
	LD A,_MR	; Check if theres initial position of rex (it should have moved by now)
	CP A,C
	JP NZ,NSLOOP2CONT
	LD C,_MP
NSLOOP2CONT:
	; Insert Rex if coords match. If yes, _MR is inserted into seenmaze
	LD A,(RX)
	CP A,D
	JP NZ,NSLOOP2NOREX
	LD A,(RY)
	CP A,E
	JP NZ,NSLOOP2NOREX
	LD C,_MR
NSLOOP2NOREX:
	POP AF
	POP HL
	LD (HL),C
	INC HL
	INC A
	DEC E
	PUSH HL ; Update dist to rex
	LD HL,TEMPDISTREX
	INC (HL)
	POP HL	; End update dist to rex
	CP A,14
	JP NZ,NSLOOP2

	LD BC,(PY)
	LD E,C
	INC D
NSLOOP3:
	PUSH HL
	PUSH AF
	CALL GET_POS
	POP AF
	LD C,L
	POP HL
	LD (HL),C
	INC HL
	INC A
	DEC E
	CP A,21
	JP NZ,NSLOOP3

	JP ENDGETSEEN


SOUTHSEEN:		; Revisar orientacionesy AVANCES
	INC D
	LD HL,SEENMAZE
	LD A,0
SSLOOP1:
	PUSH HL
	PUSH AF
	CALL GET_POS	;D=X, E=Y
	POP AF
	LD C,L
	POP HL
	LD (HL),C
	INC HL
	INC A
	INC E
	CP A,7
	JP NZ,SSLOOP1

	LD BC,(PY)
	LD E,C
	DEC D
SSLOOP2:
	PUSH HL
	PUSH AF
	CALL GET_POS
	LD C,L
	LD A,_ME
	CP A,C
	JP NZ,SSNOEXIT
	; The Exit is at this location.
	LD A,(GAMEFLAGS)	; Fetch the flags.
	SET 4,A				; Signal the Exit is visible.
	LD (GAMEFLAGS),A	; Store the updated flags.
SSNOEXIT:
	LD A,_MR ; Check if theres initial position of rex (it should have moved by now)
	CP A,C
	JP NZ,SSLOOP2CONT
	LD C,_MP
SSLOOP2CONT:
	; Insert Rex if coords match. If yes, _MR is inserted into seenmaze
	LD A,(RX)
	CP A,D
	JP NZ,SSLOOP2NOREX
	LD A,(RY)
	CP A,E
	JP NZ,SSLOOP2NOREX
	LD C,_MR
SSLOOP2NOREX:
	POP AF
	POP HL
	LD (HL),C
	INC HL
	INC A
	INC E
	PUSH HL ; Update dist to rex
	LD HL,TEMPDISTREX
	INC (HL)
	POP HL	; End update dist to rex
	CP A,14
	JP NZ,SSLOOP2

	LD BC,(PY)
	LD E,C
	DEC D
SSLOOP3:
	PUSH HL
	PUSH AF
	CALL GET_POS
	POP AF
	LD C,L
	POP HL
	LD (HL),C
	INC HL
	INC A
	INC E
	CP A,21
	JP NZ,SSLOOP3

	JP ENDGETSEEN

EASTSEEN:
	DEC E
	LD HL,SEENMAZE
	LD A,0
ESLOOP1:
	PUSH HL
	PUSH AF
	CALL GET_POS	;D=X, E=Y
	POP AF
	LD C,L
	POP HL
	LD (HL),C
	INC HL
	INC A
	INC D
	CP A,7
	JP NZ,ESLOOP1

	LD BC,(PX)
	LD D,C
	INC E
ESLOOP2:
	PUSH HL
	PUSH AF
	CALL GET_POS
	LD C,L
	LD A,_ME
	CP A,C
	JP NZ,ESNOEXIT
	; The Exit is at this location.
	LD A,(GAMEFLAGS)	; Fetch the flags.
	SET 4,A				; Signal the Exit is visible.
	LD (GAMEFLAGS),A	; Store the updated flags.
ESNOEXIT:
	LD A,_MR ; Check if theres initial position of rex (it should have moved by now)
	CP A,C
	JP NZ,ESLOOP2CONT
	LD C,_MP
ESLOOP2CONT:
	; Insert Rex if coords match. If yes, _MR is inserted into seenmaze
	LD A,(RX)
	CP A,D
	JP NZ,ESLOOP2NOREX
	LD A,(RY)
	CP A,E
	JP NZ,ESLOOP2NOREX
	LD C,_MR
ESLOOP2NOREX:
	POP AF
	POP HL
	LD (HL),C
	INC HL
	INC A
	INC D
	PUSH HL ; Update dist to rex
	LD HL,TEMPDISTREX
	INC (HL)
	POP HL	; End update dist to rex
	CP A,14
	JP NZ,ESLOOP2

	LD BC,(PX)
	LD D,C
	INC E
ESLOOP3:
	PUSH HL
	PUSH AF
	CALL GET_POS
	POP AF
	LD C,L
	POP HL
	LD (HL),C
	INC HL
	INC A
	INC D
	CP A,21
	JP NZ,ESLOOP3

	JP ENDGETSEEN

WESTSEEN:
	INC E
	LD HL,SEENMAZE
	LD A,0
WSLOOP1:
	PUSH HL
	PUSH AF
	CALL GET_POS	;D=X, E=Y
	POP AF
	LD C,L
	POP HL
	LD (HL),C
	INC HL
	INC A
	DEC D
	CP A,7
	JP NZ,WSLOOP1

	LD BC,(PX)
	LD D,C
	DEC E
WSLOOP2:
	PUSH HL
	PUSH AF
	CALL GET_POS
	LD C,L
	LD A,_ME
	CP A,C
	JP NZ,WSNOEXIT
	; The Exit is at this location.
	LD A,(GAMEFLAGS)	; Fetch the flags.
	SET 4,A				; Signal the Exit is visible.
	LD (GAMEFLAGS),A	; Store the updated flags.
WSNOEXIT:
	LD A,_MR ; Check if theres initial position of rex (it should have moved by now)
	CP A,C
	JP NZ,WSLOOP2CONT
	LD C,_MP
WSLOOP2CONT:
	; Insert Rex if coords match. If yes, _MR is inserted into seenmaze
	LD A,(RX)
	CP A,D
	JP NZ,WSLOOP2NOREX
	LD A,(RY)
	CP A,E
	JP NZ,WSLOOP2NOREX
	LD C,_MR
WSLOOP2NOREX:
	POP AF
	POP HL
	LD (HL),C
	INC HL
	INC A
	DEC D
	PUSH HL ; Update dist to rex
	LD HL,TEMPDISTREX
	INC (HL)
	POP HL	; End update dist to rex
	CP A,14
	JP NZ,WSLOOP2

	LD BC,(PX)
	LD D,C
	DEC E
WSLOOP3:
	PUSH HL
	PUSH AF
	CALL GET_POS
	POP AF
	LD C,L
	POP HL
	LD (HL),C
	INC HL
	INC A
	DEC D
	CP A,21
	JP NZ,WSLOOP3

	JP ENDGETSEEN

ENDGETSEEN:
	RET

;-----------------------------
;-----------------------------
; MATH SUBROUTINES
;-----------------------------
;-----------------------------
; MULTIPLY B and C and store result in HL
; Input: B in B register, C in C register
; Output: B * C in HL register
; B * C -> HL
; Destroys: HL,A,B,C
MULT:
	LD HL,0
	LD A,C
    CP A,0
	JP Z,MULT_END
	LD A,B
	CP A,0
	JP Z,MULT_END 
	LD B,0 			; Clear B
	JP MULTCONT

MULTCONT:
	ADD HL,BC
	DEC A
	JP NZ,MULTCONT

MULT_END:
    RET         ; return with result in HL


; DIVIDE
;Inputs:
;   HL and D
;Outputs:
;   HL is the quotient (HL/D)
;   A is the remainder
;   B is 0
;   C,D,E are preserved
DIVIDE:
    xor a         ; Clear upper eight bits of AHL
    ld b,16       ; Sixteen bits in dividend
_loop:
    add hl,hl     ; Do a "SLA HL". If the upper bit was 1, the c flag is set
    rla           ; This moves the upper bits of the dividend into A
    jr c,_overflow; If D is allowed to be >128, then it is possible for A to overflow here. (Yes future Zeda, 128 is "safe.")
    cp d          ; Check if we can subtract the divisor
    jr c,_skip    ; Carry means A < D
_overflow:
    sub d         ; Do subtraction for real this time
    inc l         ; Set the next bit of the quotient (currently bit 0)
_skip:
    djnz _loop
    ret

; -----------------
; A MODULO B => A
; -----------------
; Inputs: A(number to module), B(modulo)
; Output: A (moduled, between 0 and B-1)
; Destroys: BC
MODULO:
	;INC B		; If you perform the modulo operation with a random number A between 0 and 255 and a fixed number B, the result will be a random number between 0 and B-1
MODULOOP:
	CP B        ; compare A with B
	JR C,MODULADO  ; if A < B, jump to DONE
	SUB B       ; subtract B from A
	JR MODULOOP   ; jump to MODULO
MODULADO:
	RET

; For 16bit values (HL modulo B)
MODULO_16B:
	LD C,B
	LD B,0
	; Reduce value to 8Bit
MODULOOP_16B:
	LD A,H
	CP 0        ; compare A with B
	JR Z,MODULADO_16B  ; if A < B, jump to DONE
	AND A
	SBC HL,BC       ; subtract B from A
	JR MODULOOP_16B   ; jump to MODULO
MODULADO_16B:
	LD A,L
	LD B,C
	CALL MODULO
	RET

; Ricardo Bittencourt provided us with a fast routine for division by 9. It is built for .dsk or Disk ROM routines. It’s very fast, but only works in the range 0-1440.
; https://map.grauw.nl/articles/mult_div_shifts.php
; division by nine
; enter     HL = number from 0 to 1440
; exit      A = HL/9
; destroy   HL,DE
;                                 Z80  R800
DIV9:   INC     HL              ;  7    1
        LD      D,H             ;  5    1
        LD      E,L             ;  5    1
        ADD     HL,HL           ;  12   1
        ADD     HL,HL           ;  12   1
        ADD     HL,HL           ;  12   1
        SBC     HL,DE           ;  17   2
        LD      E,0             ;  8    2
        LD      D,L             ;  5    1
        LD      A,H             ;  5    1
        ADD     HL,HL           ;  12   1
        ADD     HL,HL           ;  12   1
        ADD     HL,DE           ;  12   1
        ADC     A,E             ;  5    1
        XOR     H               ;  5    1
        AND     03FH            ;  8    2
        XOR     H               ;  5    1
        RLCA                    ;  5    1
        RLCA                    ;  5    1
        RET            ; total  = 157  22 


; TIMER miliseconds in reg A
;WAIT 0.5S BEFORE PRINTING NEXT LINE
;Inputs: bc = Delay length
WAIT_HALFSEC:
	PUSH AF
	PUSH BC
WAITL:
	NOP 
	DEC	BC 
	LD	A, B 
	OR	C 
	JR	NZ, WAITL
	POP BC
	POP AF
	RET
	; B_CALL(_starttimer)
	; B_CALL(_waittimer)
	; B_CALL(_stoptimer)

;-----------------------------
;-----------------------------
; TEXT ZONE SUBROUTINES
;-----------------------------
;-----------------------------
; Write text pointed by HL to screen and scroll the rest of the text up.
; Uses TEXTBUFFER to make the scrolling animation
; Destroys: DE,HL,BC,A
WRITESCREENTEXT:
	PUSH HL
	; Copy all text to the line above it
	; ; LD DE,TEXTBUFFER
	; ; LD HL,TEXTBUFFER+18
    ; ; LD BC,126 ; Number of bytes per line
    ; ; LDIR

	LD DE,TEXTBUFFER 
	LD HL,TEXTBUFFER+18 ; Point HL to the second line
    LD BC,18 ; Number of bytes per line
    LDIR ; Copy the line to the row above it			;TODO: LDIR everything at once by moving +18 to +0, size(BC)=18*8
	LD DE,TEXTBUFFER+18
	LD HL,TEXTBUFFER+36
    LD BC,18 ; Number of bytes per line
    LDIR ; Copy the line to the row above it
	LD DE,TEXTBUFFER+36
	LD HL,TEXTBUFFER+54
    LD BC,18 ; Number of bytes per line
    LDIR ; Copy the line to the row above it
	LD DE,TEXTBUFFER+54
	LD HL,TEXTBUFFER+72
    LD BC,18 ; Number of bytes per line
    LDIR ; Copy the line to the row above it
	LD DE,TEXTBUFFER+72
	LD HL,TEXTBUFFER+90 
    LD BC,18 ; Number of bytes per line
    LDIR ; Copy the line to the row above it
	LD DE,TEXTBUFFER+90
	LD HL,TEXTBUFFER+108
    LD BC,18 ; Number of bytes per line
    LDIR ; Copy the line to the row above it
	LD DE,TEXTBUFFER+108
	LD HL,TEXTBUFFER+126
    LD BC,18 ; Number of bytes per line
    LDIR ; Copy the line to the row above it

	; Write new text to last row
	POP HL
	LD DE,TEXTBUFFER+126
	LD BC,18
	LDIR

; 	; Clear line, write line. Clear line, write line. Clear line, write line.
;TODO: Refactor this into a loop
	; Clear line 8
	PUSH BC
	LD D,56
	LD E,30
	LD HL,BLANKLINEIMG
	CALL DisplayImage ;BCALL(_DisplayImage)
	POP BC

	LD H,56
	LD L,30
	LD (PenCol),HL
	LD HL,TEXTBUFFER+126
	CALL VPutS

	; Clear line 7
	PUSH BC
	LD D,48
	LD E,30
	LD HL,BLANKLINEIMG
	CALL DisplayImage ;BCALL(_DisplayImage)
	POP BC

	LD H,48
	LD L,30
	LD (PenCol),HL
	LD HL,TEXTBUFFER+108
	CALL VPutS

	; Clear line 6
	PUSH BC
	LD D,40
	LD E,30
	LD HL,BLANKLINEIMG
	CALL DisplayImage ;BCALL(_DisplayImage)
	POP BC

	LD H,40
	LD L,30
	LD (PenCol),HL
	LD HL,TEXTBUFFER+90
	CALL VPutS

	; Clear line 5
	PUSH BC
	LD D,32
	LD E,30
	LD HL,BLANKLINEIMG
	CALL DisplayImage ;BCALL(_DisplayImage)
	POP BC

	LD H,32
	LD L,30
	LD (PenCol),HL
	LD HL,TEXTBUFFER+72
	CALL VPutS
	
	; Clear line 4
	PUSH BC
	LD D,24
	LD E,30
	LD HL,BLANKLINEIMG
	CALL DisplayImage ;BCALL(_DisplayImage)
	POP BC

	LD H,24
	LD L,30
	LD (PenCol),HL
	LD HL,TEXTBUFFER+54
	CALL VPutS
	
	; Clear line 3
	PUSH BC
	LD D,16
	LD E,30
	LD HL,BLANKLINEIMG
	CALL DisplayImage ;BCALL(_DisplayImage)
	POP BC

	LD H,16
	LD L,30
	LD (PenCol),HL
	LD HL,TEXTBUFFER+36
	CALL VPutS

	; Clear line 2
	PUSH BC
	LD D,8
	LD E,30
	LD HL,BLANKLINEIMG
	CALL DisplayImage ;BCALL(_DisplayImage)
	POP BC

	LD H,8
	LD L,30
	LD (PenCol),HL
	LD HL,TEXTBUFFER+18
	CALL VPutS

	; Clear line 1
	PUSH BC
	LD D,0
	LD E,30
	LD HL,BLANKLINEIMG
	CALL DisplayImage ;BCALL(_DisplayImage)
	POP BC

	LD H,0
	LD L,30
	LD (PenCol),HL
	LD HL,TEXTBUFFER
	CALL VPutS

	; LD B,100
	; CALL WAIT_HALFSEC

; 	LD A,8 ; 8 lines
; 	LD HL,TEXTBUFFER
; 	LD C,0 ; X pos of text
; REWRITETEXTLOOP:
; 	PUSH AF		; Push line counter
; 	PUSH HL		; Push text address from stack
; 	; Put new X,Y+=8 coords
; 	LD A,C 
; 	LD H,A ; X=0

; 	LD A,30
; 	LD L,A ; Y=30
; 	PUSH HL		; Push current coordinates to stack

; 	; Clear line
; 	; PUSH BC
; 	; LD D,C
; 	; LD E,30
; 	; LD HL,BLANKLINEIMG
; 	; CALL DisplayImage ;BCALL(_DisplayImage)
; 	; POP BC

; 	POP HL		; Pop current coordinates to stack
; 	LD (PenCol),HL
; 	POP HL		; Pop text address from stack
; 	; Print text
;     CALL VPutS
	
; 	LD A,C 
; 	ADD A,8 ; Y+=8
; 	LD C,A

; 	POP AF		; Pop counter
; 	DEC A
; 	CP A,0
; 	JP NZ,REWRITETEXTLOOP
	
	RET

; Clear text zone by scrolling 8 blank lines
CLRTEXTZONE:
	LD A,0
CLRTEXTZONELOOP:
	PUSH AF
	LD HL,BLANKLINE
	CALL WRITESCREENTEXT
	POP AF
	INC A
	CP A,8
	JP NZ,CLRTEXTZONELOOP
	RET

CLEARTEXTBUFFER:
	; Initialize TEXTBUFFER to blank lines so it prints a whole empty line and it doesnt just print 0 characters, because that way when the textbuffer is empty it scrolls faster
	LD HL,BLANKLINE
	LD DE,TEXTBUFFER
	LD BC,18
	LDIR
	LD HL,BLANKLINE
	LD DE,TEXTBUFFER+18
	LD BC,18
	LDIR
	LD HL,BLANKLINE
	LD DE,TEXTBUFFER+36
	LD BC,18
	LDIR
	LD HL,BLANKLINE
	LD DE,TEXTBUFFER+54
	LD BC,18
	LDIR
	LD HL,BLANKLINE
	LD DE,TEXTBUFFER+72
	LD BC,18
	LDIR
	LD HL,BLANKLINE
	LD DE,TEXTBUFFER+90
	LD BC,18
	LDIR
	LD HL,BLANKLINE
	LD DE,TEXTBUFFER+108
	LD BC,18
	LDIR
	LD HL,BLANKLINE
	LD DE,TEXTBUFFER+126
	LD BC,18
	LDIR
	RET

;GETKD/GETKDH
; Direct Input Routines for the 83/83+
; By Joe Pemberton (joe@joepnet.com)
; https://www.ticalc.org/pub/83plus/asm/source/routines/getkd.z80
;
;GetKD will return b with the following bits reset (if the keys are down):
;bit 0 - down
;bit 1 - left
;bit 2 - right
;bit 3 - up
;bit 4 - 2nd
;bit 5 - mode
;bit 6 - clear
;bit 7 - enter
;
; GetKDH will do the same, but it will not repeat on 2nd, mode, clear or enter (i.e.
; if you press enter you must release it before GetKDH will detect it again)  The arrow
; keys will always repeat.
;============= key equates for getkd(h) =============
KDB_DOWN	=	0
KD_DOWN		=	%11111110
KDB_LEFT	=	1
KD_LEFT		=	%11111101
KDB_RIGHT	=	2
KD_RIGHT	=	%11111011
KDB_UP		=	3
KD_UP		=	%11110111
KDB_2ND		=	4
KD_2ND		=	%11101111
KDB_MODE	=	5
KD_MODE		=	%11011111
KDB_CLEAR	=	6
KD_CLEAR	=	%10111111
KDB_ENTER	=	7
KD_ENTER	=	%01111111

KD_MASK		=	%11110000	;do not repeat keys for bits 4-7
					;change this mask to make different keys repeat
;================= routine ===================
getkdh:	call	getkd
	ld	hl,getkdflag
	ld	a,b
	ld	c,b
	or	(hl)
	ld	b,a
	ld	a,c
	cpl
	and	KD_MASK
	ld	(hl),a
	ei
	halt			;to mimic _getcsc
	ret

getkd:	ld	a,$ff
	ld	b,a
	out	(1),a
	ld	a,$fe
	out	(1),a
	in	a,(1)
	and	b
	ld	b,a		;bits 0,1,2,3 are the arrows
	ld	a,$ff
	out	(1),a
	ld	a,$fd
	out	(1),a
	in	a,(1)		;catch enter/clear keypress
	or	%10111110	;only get enter/clear keypress
	rrca			;enter keypress is in bit 7, clear in bit 5
	bit	5,a
	jr	nz,getkd2
	xor	%01100000
getkd2:
	and	b
	ld	b,a		;bit 7 is the enter key
	ld	a,$ff
	out	(1),a
	ld	a,$bf
	out	(1),a
	in	a,(1)
	rra
	or	%11001111	;only get 2nd/mode
	and	b
	ld	b,a
	ret
getkdflag:
	.DB 0

; -------------
; Fill the Maze
; -------------
; The maze is 18 x 16 positions in size, although the very north, south and west locations will always contain walls.
; Therefore the active maze sixe is 16 x 15. This routine fills all positions with wall cells. It is called from BASIC.
FILLMAZE:  
	LD HL,MAZE			; Point to the first location of the maze.
	LD BC,MAZE_H*MAZE_W-1			; The size of the maze-1.
	LD DE,MAZE+$0001	; Point to the second location of the maze.
	LD (HL),_MW			; Fill the first location with a wall.
	LDIR				; Copy the wall to all other locations within the maze.

	;LD   HL,MAZE+(MAZE_H-1)*MAZE_W+$000F	; Point to the far south-east location.
	;LD   (PD),HL	; Set as the player position.
	LD A,16
	LD (PY),A
	LD A,14
	LD (PX),A
	RET

; ---------------------------------
; Insert a Passageway into the Maze
; ---------------------------------
; A direction and length for the passageway has been selected at random from BASIC beforehand.
; The first passageway begins at the player's initial location (the very south-east of the maze). Each subsequent passageway
; begins where the previous one terminated.
; Input: Passageway length in PD
; Output: 
; Destroys: all - AF,BC,HL,DE
INSERTPASSAGEWAY:;L4435
	LD   A,(PD)                          ; Fetch the passageway length. (L4084)
	LD   B,A

; Enter a loop to examine each position along the passageway length.
IPWLOOP;L4439:
	;LD   DE,$0010		; The width of the maze.
	
	;LD   HL,(L4082)	; Fetch the current passageway insertion location.
	PUSH BC
	LD BC,(PX)
	LD H,C
	LD BC,(PY)
	LD L,C
	POP BC

	; DEBUG
	; CALL PRINTMAZE ;DEBUG / LOADING SCREEN - Increases significatively maze generation time
	; END DEBUG

	LD   A,(PWD)			; Fetch the passageway direction. (L4085)  
	CP   $00            ; Is the passageway to the north?
	JP   Z,PWNORTH      ; Jump if so. L4465

	CP   $01            ; Is the passageway to the west?
	JP   Z,PWWEST		; Jump if so. L449B

	CP   $02			; Is the passageway to the south?
	JP   Z,PWSOUTH		; Jump if so. L445E

	CP   $03			; Is the passageway to the east?
	JP   Z,PWEAST		; Jump if so. L4457

; Should never reach here.
	RET

; The passageway is to the east
; -----------------------------
PWEAST;L4457:  
	;INC  HL				; Point at the location to the east.
	INC H

	; LD   A,$0F			; Get Y (L)
	; AND  L				; At the far east of the maze?
	LD A,15
	CP A,H

	JR   NZ,PWEASTJOIN 	;L44A4		; Jump if not.

; At the far east of the maze so the passageway can progress no further.
	RET

; The passageway is to the south
; ------------------------------
PWSOUTH:;L445E:  
	;ADD  HL,DE			; Point to the location to the south.
	INC L

	; LD   A,$F0			; At the far south of the maze?
	; AND  L
	LD A,17
	CP A,L

	JR   NZ,PWSOUTHJOIN ;L446E	; Jump if not.

; At the far south of the maze so the passageway can progress no further.
	RET

; The passageway is to the north
; ------------------------------
PWNORTH:;L4465
	; LD   A,$F0			; At the far north of the maze?
	; AND  L
	LD A,1
	CP A,L

	JR   NZ,PWNORTHCONT;L446B		; Jump if not.

; At the far north of the maze so the passageway can progress no further.
	RET

; The passageway is to the north.
PWNORTHCONT:;L446B:  
	; AND  A
	; SBC  HL,DE			; Point to the location to the north.
	DEC L

; Joins here when the passageway is to the south.
PWSOUTHJOIN: ;L446E:  
	;LD   A,(HL)			; Fetch the contents of the location.
	PUSH DE
	PUSH HL
	PUSH BC
	EX DE,HL
	CALL GET_POS
	LD A,L		; GET_POS returns value in X,Y to HL
	POP BC
	POP HL
	POP DE

	CP   _MP			; Does it already contain a passageway?
	JR   Z,PWSPROGRESS;L448F		; Jump ahead if so.

; The location contains a wall so is a candidate for inserting a passageway.
	; LD   A,$0F
	; AND  L				; At the far west? WEST???????????
	LD A,1
	CP A,H

	JR   Z,JOINNOTFARWEST;L4482		; Jump ahead if so.

; Not at the far west.
	;DEC  HL				; Point to the location to the west.
	DEC H

	;LD   A,(HL)			; Fetch the contents of the location.
	PUSH DE
	PUSH HL
	PUSH BC
	EX DE,HL
	CALL GET_POS
	LD A,L
	POP BC
	POP HL
	POP DE

	CP   _MP			; Does it already contain a passageway?
	JR   NZ,PWNSCONT;L4481		; Jump ahead if not.

; The location to the west contains a passageway.
	RET

; The loop back to examine the next position along the passageway length jumps to here since the distance to
; the loop start is too far to relative jump to in one go.
PWLOOPBACK:;L447F:  
	JR   IPWLOOP ;L4439                              ; Jump to the loop start.

; Continues here when the passageway is to the north or south.
PWNSCONT:;L4481:  
	;INC  HL                                 ; Reverse the decrement above to point back to the original location.
	INC H

; Joins here when the passageway is not at the far west.
JOINNOTFARWEST:;L4482:  
	;INC  HL                                 ; Point to the location to the east.
	INC H

	; LD   A,$0F
	; AND  L                                  ; At the far east?
	LD A,15
	CP A,H

	JR   Z,PWNSWALLS;L448E                            ; Jump ahead if so.

; Not at the far east.
	;LD   A,(HL)                             ; Fetch the contents of the location.
	PUSH DE
	PUSH HL
	PUSH BC
	EX DE,HL
	CALL GET_POS
	LD A,L
	POP BC
	POP HL
	POP DE

	CP   _MP                                ; Does it already contain a passageway?
	JR   NZ,PWNSWALLS;L448E                           ; Jump ahead if not.
	
; The location to the east contains a passageway.
	RET

; the loop start is too far to relative jump to in one go 
PWLOOPBACK2:
	JR   PWLOOPBACK ; Jump to the loop start.

; The passageway is to the north or south and walls are to the west and east.
PWNSWALLS:;L448E:  
	;DEC  HL                                 ; Reverse the increment above to point back to the original location.
	DEC H

; Joins here when the passageway can be progressed into this location, or the location already contains a passageway.
PWSPROGRESS:;L448F:
	; LD   (L4082),HL			; Store as the new passageway insertion position.
	LD A,H
	LD (PX),A
	LD A,L
	LD (PY),A

	LD   A,_MP

	EX   DE,HL
	;LD   (DE),A                             ; Insert a passageway into the maze at the current position.
	PUSH HL
	PUSH BC
	CALL SET_POS
	POP BC
	POP HL

	DJNZ PWLOOPBACK2 ;L4439                              ; Loop back to examine the next position along the desired passageway length.

	LD   B,D
	LD   C,E                                ; Return the end location of the passageway [never used].
	RET

; The passageway is to the west
; -----------------------------
PWWEST:  
	; LD   A,L
	; AND  $0F                                ; At the far west of the maze?
	; CP   $01
	LD A,1
	CP A,H

	JR   NZ,PWNOTFARWEST;L44A3                           ; Jump if not.

; At the far west of the maze so the passageway can progress no further.
	RET

; Not at the far west.
PWNOTFARWEST:;L44A3:  
	;DEC  HL                                 ; Point to the location to the west. (not east as it said)
	DEC H 

; Joins here when the passageway is to the east.
PWEASTJOIN:;L44A4:  
	;LD   A,(HL)                             ; Fetch the contents of the position.
	PUSH DE
	PUSH HL
	PUSH BC
	EX DE,HL
	CALL GET_POS
	LD A,L
	POP BC
	POP HL
	POP DE

	CP   _MP ; _SPACE						; Does it already contain a passageway?
	JR   Z,PWEPROGRESS;L44C7				; Jump ahead if so.

; The location contains a wall so is a candidate for inserting a passageway.
	; LD   A,$F0
	; AND  L								; At the far north or far south? ;CHECK
	LD A,1
	CP A,L

	JR   Z,PWNORTHJOIN;L44B8			; Jump ahead if so.

	LD A,16
	CP A,L

	JR   Z,PWSOUTHJOIN;L44B8			; Jump ahead if so.; It said PWNORTHJOIN before, but passageways at far south were created next to other ones (bad)

; Not at the far north or far south.
	; AND  A
	; SBC  HL,DE
	DEC L	;CHECK

	;LD   A,(HL)                             ; Does the location to the north contain a passageway?
	PUSH DE
	PUSH HL
	PUSH BC
	EX DE,HL
	CALL GET_POS
	LD A,L
	POP BC
	POP HL
	POP DE

	CP   _MP; _SPACE
	JR   NZ,NOPW_NORTH;L44B7                           ; Jump ahead if not.

; The location to the north contains a passageway.
	RET

; The location to the north does not contain a passageway.
NOPW_NORTH:;L44B7:  
	;ADD  HL,DE                              ; Reverse the subtraction above to point back to the original location.
	INC L

; Joins here when at the far north.
PWNORTHJOIN:;L44B8:  
	;ADD  HL,DE                              ; Point to the location to the south.
	INC L

	; LD   A,$F0
	; AND  L                                  ; At the far south?
	LD A,17
	CP A,L

	JR   Z,NOPW_SOUTH;L44C4                            ; Jump ahead if so.

; Not at the far south.
	; LD   A,(HL)                             ; Does the location to the south contain a passageway?
	PUSH DE
	PUSH HL
	PUSH BC
	EX DE,HL
	CALL GET_POS
	LD A,L
	POP BC
	POP HL
	POP DE

	CP   _MP; _SPACE
	JR   NZ,NOPW_SOUTH;L44C4                           ; Jump ahead if not.

; The location to the south contains a passageway.
	RET

; The location to the south does not contain a passageway.
NOPW_SOUTH:;L44C4:  
	; AND  A
	; SBC  HL,DE                              ; Reverse the addition above to point back to the original location.
	DEC L

; Joins here when the passageway can be progressed into this location, or the location already contains a passageway.
PWEPROGRESS:;L44C7:  
	; LD   (L4082),HL			; Store as the new passageway insertion position.
	PUSH AF
	LD A,H
	LD (PX),A
	LD A,L
	LD (PY),A
	POP AF

	LD   A,_MP; _SPACE

	EX   DE,HL
	;LD   (DE),A                             ; Insert a passageway into the maze at the current position.
	PUSH HL
	PUSH BC
	CALL SET_POS
	POP BC
	POP HL

	DJNZ PWLOOPBACK2;L447F                              ; Loop back to examine the next position along the desired passageway length.

	RET

; -----------------------------
; Insert the Exit into the Maze (17617)
; -----------------------------
INSERTEXIT:;L44D1:  
; 	LD   HL,L4630				; Point at row 4 column 0 within the maze, which is the starting search position.
	LD HL,MAZE+64 ; X=0,Y=4
	LD D,0
	LD E,4

; 	LD   A,(L4082)				; Fetch the random offset within the maze.
	; Get PX to A
	LD A,(PX)
	ADD A,L
	LD L,A						; Apply it to the starting search position.

	PUSH AF
	LD A,(PX)
	ADD A,D ; X + random offset
	LD D,A
	POP AF

; 	LD   A,(HL)
	PUSH HL
	PUSH DE
	CALL GET_POS
	POP DE
	LD A,L
	POP HL
	CP _MP					; Does the maze location contain a passageway?
	RET NZ					; Return if it does not, i.e. it contains a wall.

; The location contains a passageway.
	LD   (HL),_ME			; Insert the Exit into the maze.
	; CALL L4D7C			; Perform a program protection check (NOT APPLICABLE TO THIS PROGRAM) and fetches an offset to apply to point to the position to the north.
	; LD DE,$FFF0				; Offset of -16, used to check the position to the north when inserting the Exit into the maze.
	DEC E ; Y-- (north)

	LD   C,$00						; Signal that an adjacent passageway has not yet been found.
	CALL CHECKADJPOSEXIT;L4504		; Check the position to the north.

	; LD   DE,$000F					; Offset to point to the position to the west.
	DEC D
	CALL CHECKADJPOSEXIT;L4504		; Check the position to the west.

	; LD   DE,$0002					; Offset to point to the position to the east.
	INC D
	INC D
	CALL CHECKADJPOSEXIT;L4504		; Check the position to the east.

	; LD   DE,$000F					; Offset to point to the position to the south.
	INC E
	CALL CHECKADJPOSEXIT;L4504		; Check the position to the south.

; By here the Exit position is now only reachable from one direction.
	; LD   HL,L46F0+$000F				; The address of row 16 column 15 - the start location for the player.
	LD HL,MAZE+16*16+15
	LD (HL),_MP					; Ensure this location contains a passageway.

	; LD HL,L4082					; The low address of the player's position (the high byte will always be $46).
	; LD (HL),$FF					; Set the player's start location to $46FF.
	LD A,15 ; X
	LD (PX),A
	LD A,16 ; Y
	LD (PY),A
    RET

; ---------------------------------------
; Check Adjacent Location Around the Exit
; ---------------------------------------
; This routine is called to check the locations around the Exit position. Only one passageway is allowed
; to be adjacent to the Exit position. The locations around the Exit are checked in the following order:
; North, East, West, South. Only the first passageway found is retained; the others are filled in with walls.
CHECKADJPOSEXIT:;L4504:
 	; ADD  HL,DE						; Apply the position offset to the Exit location.
    ; LD   A,(HL)
	PUSH BC
	PUSH DE
	PUSH HL
	CALL GET_POS
	POP DE
	POP BC
	LD A,L
	POP HL

    CP A,_MP							; Does this location contain a passageway?
    JR NZ,CHECKADJPOSEXITEND;L4512		; Jump ahead if not to make a return.

; The location contains a passageway.
    BIT 0,C								; Has an adjacent passageway already been found?
    JR Z,FIRSTPWFOUND;L4510							; Jump ahead if not.

; This is another adjacent passageway.
    ; LD (HL),_MW							; Fill in the position with a wall.
	LD A,_MW
	CALL SET_POS

; This is the first adjacent passageway found.
FIRSTPWFOUND:;L4510:
	LD C,$01							; Signal that an adjacent passageway has been found.

CHECKADJPOSEXITEND;L4512:
	RET

; ------------------------
; Insert Rex into the Maze
; ------------------------
; An attempt is made to insert Rex at row 1 column 5. If a wall exists here then an attempt is made to the east (column 6).
; If this also contains a wall then the process is repeated for columns 7 to 10. If a passageway location has still not been found
; then the search moves to row 2 column 5 and continues across to column 10. If a passageway location is still not found then the
; process moves to row 3 column 5, and continues across and down the maze until the first passageway location is found.
; This routine is called from BASIC.
INSERTREX:;L4513: 
	; LD   HL,L4600+$0005		; Point at row 1 column 5 within the maze.
	LD HL,MAZE+16+5 ; Position (5,1) on maze
	LD D,5 ; Init coords to 5,1 (D=X,E=Y)
	LD E,1 ; Init coords to 5,1 (D=X,E=Y)
	
IR_SEARCHPOS:;L4516:  
	LD   B,$06					; There are 6 possible positions to consider in the current row (spanning columns 5 to 10).

IR_SEARCHPOSLOOP:;L4518:  
	; BIT  7,(HL)				; Does the location contain a wall?
	LD A,(HL)
	CP A,_MW
	JR NZ,IR_PWFOUND;L4525		; Jump ahead if it does not.

; The location contains a wall.
	INC HL						; Advance to the east.
	INC D
	DJNZ IR_SEARCHPOSLOOP;L4518	; Repeat for all test positions.

; A passageway location was not found so the search is repeated on the next row (Position 5,2).
	LD   BC,$000A
	ADD  HL,BC					; Advance to the 6th column in the row below.
	INC E

	JR   IR_SEARCHPOS;L4516	; Jump back to search 6 positions within the new row.

; A passageway location was found.
IR_PWFOUND:;L4525:  
	; LD   (L4088),HL                         ; Note the location of Rex.
	LD A,D
	LD (RX),A
	LD A,E
	LD (RY),A

	LD   (HL),_MR                           ; Insert Rex into the maze.

	RET ; Because sometimes the maze breaks ;TODO

	JP   INSERTPASSAGEWAY4REX;L4D92                              ; Jump to attempt to insert a passageway to the east 10 tiles long.

; -------------------------
; Insert Passageway for Rex
; -------------------------
; Attempt to insert a passageway from the location containing Rex to the east for 10 tiles.
; This presumably aims to ensure that Rex is not in an isolated section of the maze.
INSERTPASSAGEWAY4REX;L4D92:  
	; LD   (L4082),HL                         ; Store as the passageway insertion position.
	PUSH AF
	LD A,D
	LD (PX),A
	LD A,E
	LD (PY),A
	POP AF

	; LD   HL,L4084
	; LD   (HL),$0A                           
	LD HL,PD
	LD (HL),$0A			; Set a passageway length of 10.

	LD HL,PWD
	LD (HL),$03		; Set the passageway direction to the east (3).

	JP   INSERTPASSAGEWAY;L4435                              ; Attempt to insert the passageway.
	RET


; -------------------
; Display Escape Text
; -------------------
DISPLAYESCAPED:;L4D28:  
	RET
; 	LD   HL,(D_FILE)                        ; Fetch the location of the display file.
; 	LD   DE,$003C                           ; Offset to row 1 column 26.
; 	ADD  HL,DE

; 	LD   DE,L4DAA                           ; Point at the successful escape message text.
; 	EX   DE,HL                              ; DE=Display file address, HL=Message text address.

; 	LD   B,$13                              ; There are 19 rows of text.

; L4D35:  PUSH BC                                 ; Save the row counter.

; 	LD   BC,$0006                           ; There are 6 columns of text.
; 	LDIR                                    ; Insert a row of the escape message text into the display file.

; 	LD   BC,$001B                           ; The offset to the next row.
; 	EX   DE,HL
; 	ADD  HL,BC                              ; Advance to the next row.
; 	EX   DE,HL                              ; DE=Display file address, HL=Message text address.

; 	POP  BC                                 ; Retrieve the row counter.
; 	DJNZ L4D35                              ; Repeat for all rows.

; 	LD   DE,$0103                           ; Offset to row 7 column 27.
; 	CALL L4CEF                              ; Display the score.

; 	LD   DE,$0084                           ; Offset to the status message text "                      ".
; 	JP   L4C9D                              ; Jump to blank out the status message.



; -----------------
; Generate random int
; -----------------
; https://wikiti.brandonw.net/index.php?title=Z80_Routines:Math:Random#IONRANDOM
; output a=answer 0<=a<=255
; Destroys: af
RANDOMA:
	push    hl
	push    de
	ld      hl,(randData)
	ld      a,r				; Load refresh register
	ld      d,a
	ld      e,(hl)
	add     hl,de
	add     a,l
	xor     h
	rlc 	l
	ld      (randData),hl
	pop     de
	pop     hl
	ret

; -----------------
; Generate random number between 0 and B (Range)
; -----------------
; Input: B = Range(max)
; Output: A = random number 0<=N<=B
; Destroys: AF,BC
RANDOMAR:
	CALL RANDOMA
	CALL MODULO ; A MODULO B
	RET



;VPutS Inline
;Same as OS's PutS routine, but inline
;Modified by ARS to print in small font
;Source: http://z80-heaven.wikidot.com/flash-applications
VPutS:
	RES fracDrawLFont, (IY + fontFlags) ; Reset (=0) for small font
	PUSH BC
	PUSH AF
	LD A,(winBtm)
	LD B,A ; B = bottom line of window
VPutS10:
	LD A,(HL) ; get a character of string name
	INC HL
	OR A ; end of string?
	SCF ; indicate entire string was displayed
	JR Z, VPutS20 ; yes --->
	; BCALL(_PutC) 
	BCALL(_VPutMap) ; display one character of string
	LD A,(curRow) ; check cursor position
	CP B ; off end of window?
	JR C,VPutS10 ; no, display rest of string
VPutS20:
	POP BC ; restore A (but not F)
	LD A,B
	POP BC ; restore BC
	RET

;VPutS for putting 3 first letters in inverse text (for 'RUN he is behind' you for ex.)
;Same as OS's PutS routine, but inline
;Modified by ARS to print in small font
;Source: http://z80-heaven.wikidot.com/flash-applications
VPutS_INV3:
	RES fracDrawLFont, (IY + fontFlags) ; Reset (=0) for small font
	SET textInverse, (IY + textFlags) ; Set inverse text
	;PUSH DE
	PUSH BC
	PUSH AF
	LD E,0
	LD A,(winBtm)
	LD B,A ; B = bottom line of window
VPutS10_INV3:
	INC E
	LD A,4
	CP A,E
	JP NC,VPutS10_INV3_CONT
	RES textInverse, (IY + textFlags) ; Resume non-inverse text when written the word RUN
VPutS10_INV3_CONT:

	LD A,(HL) ; get a character of string name
	INC HL
	OR A ; end of string?
	SCF ; indicate entire string was displayed
	JR Z, VPutS20_INV3 ; yes --->
	; BCALL(_PutC) 
	PUSH DE
	BCALL(_VPutMap) ; display one character of string
	POP DE
	LD A,(curRow) ; check cursor position
	CP B ; off end of window?
	JR C,VPutS10_INV3 ; no, display rest of string
VPutS20_INV3:
	POP BC ; restore A (but not F)
	LD A,B
	POP BC ; restore BC
	POP DE
	RET

; Routines to display text from registers A and HL in small font
; Author: Dan Weiss (https://www.ticalc.org/archives/oldmail/assembly-83/2002_January/msg00443.html)
;==========================================
;  VDispA - Displays A in the small font
;==========================================
VDISPA:
    LD H,0
    LD L,A
;===========================================
;  VDispHL - Displays hl in the small font
;===========================================
VDISPHL:
    PUSH DE
    PUSH HL
    LD DE,OP1+5
    XOR A
    LD (DE),A
VDHLREPEAT:
    BCALL(_DIVHLBY10)
    ADD A,'0'
    DEC DE
    LD (DE),A
    LD A,H
    OR L
    JR NZ,VDHLREPEAT
    EX DE,HL
    BCALL(_VPUTS)
    POP HL
    POP DE
    RET

; Display Image subroutine (_DisplayImage)
; but it moves the image to display to RAM so it can call _DisplayImage
; Destroys: BC,HL,... assume everything
DisplayImage:
	PUSH DE
	PUSH HL
	; Get size of image
	LD B,(HL) ; Height/Y

	INC HL
	LD A,(HL) ; Width/X - must be divided by 8 (3xRRCA) since 8 pixels = 1BYte
	RRCA
	RRCA
	RRCA
	LD C,A
	CALL MULT ;B*C ->HL
	INC HL
	INC HL ; Add size bytes of the start of the image to the total size

	LD B,H
	LD C,L	; Move size to BC

	LD HL,0
    LD (penCol),HL	; Set coordinates where the image will be printed
	POP HL

	; Move data to safeRAM
	; LD HL,TESTIMG
	LD DE,saveSScreen
	; LD BC,514 ; Size of the biggest image we're using
	LDIR

	POP DE
	; LD E,1
	; LD E,1
    LD HL,saveSScreen
	BCALL(_DisplayImage)
	RET 

;_____________________________________________________________________________
; DEBUG SUBROUTINES

; PRINTMAZE
; Prints maze on screen (1 pixel = 1 cell of maze)
; Destoys: AF
PRINTMAZE:
	;DEBUG
	PUSH BC
	PUSH DE
	PUSH HL
	; Update MAZEDEBUG and then print it
	CALL CONVERTMAZE
	LD  E,0
    LD  D,SCREEN_H-18
    LD  HL,MAZEDEBUG
    CALL DisplayImage ;B_CALL(_DisplayImage)
	POP HL
	POP DE
	POP BC
	RET

; CONVERTMAZE
; Mazedebug - Converts MAZE to an "image" in MAZEDEBUG, W=2,H=18
CONVERTMAZE:
    LD DE, MAZE        ; DE = address of MAZE
    LD HL, MAZEDEBUG+2   ; HL = address of MAZEDEBUG

	LD B,36
CONVMAZELOOP:
	PUSH BC
	CALL CONVERTMAZE_BYTE
	INC HL
	POP BC
	DJNZ CONVMAZELOOP
    RET

; AUX FOR CONVERTMAZE
CONVERTMAZE_BYTE:
	LD B,8 ; counter
MDLOOP:
	LD A,(DE)
	CP _MW
	JP NZ, CMBNOTWALL
CMBWALL:
	SET 7,C
	JP CMBNEXTCELL
CMBNOTWALL:
	RES 7,C
	JP CMBNEXTCELL
CMBNEXTCELL:
	RLC C
	INC DE
	DJNZ MDLOOP

	LD A,C
	LD (HL),A
	RET
;_____________________________________________________________________________

; ----------------------------------------------
; VARIABLES
; ----------------------------------------------

; ;DEBUG MAZE 0-1s
; MAZEDEBUG:
; 	.DB 18,16
; 	.DB %00000000,%00000000
; 	.DB %10101010,%10101010
; 	.DB %00000000,%00000000
; 	.DB %11111111,%11111111
; 	.DB %11111111,%11111111
; 	.DB %00000000,%00000000
; 	.DB %00000000,%00000000
; 	.DB %00000000,%00000000
; 	.DB %00000000,%00000000
; 	.DB %00000000,%00000000
; 	.DB %00000000,%00000000
; 	.DB %00000000,%00000000
; 	.DB %00000000,%00000000
; 	.DB %00000000,%00000000
; 	.DB %00000000,%00000000
; 	.DB %00000000,%00000000
; 	.DB %00000000,%00000000
; 	.DB %00000000,%00000000

; ; MAZE (init to all walls)
; ;    N
; ;    |
; ; W -+- E
; ;    |
; ;    S
MAZE_INIT:	; .DB 18,16 ;DEBUG
; 	; .DB _MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
; 	; .DB _MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
; 	; .DB _MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
; 	; .DB _MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
; 	; .DB _MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
; 	; .DB _MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
; 	; .DB _MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
; 	; .DB _MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
; 	; .DB _MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
; 	; .DB _MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
; 	; .DB _MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
; 	; .DB _MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
; 	; .DB _MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
; 	; .DB _MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
; 	; .DB _MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
; 	; .DB _MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
; 	; .DB _MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
; 	; .DB _MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW

; 	; .DB _MW, _MW, _MW, _MW, _MW, _MW, _MW, _MW, _MW, _MW, _MW, _MW, _MW, _MW, _MW, _MW
; 	; .DB _MW, _MP, _MW, _MP, _MW, _MW, _MP, _MW, _MW, _MW, _MW, _MW, _MW, _MW, _MW, _MP
; 	; .DB _MW, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MW, _MW, _MP
; 	; .DB _MW, _MP, _MW, _MP, _MW, _MW, _MP, _MW, _MW, _MW, _MP, _MW, _MW, _MW, _MW, _MP
; 	; .DB _MW, _MP, _MP, _MP, _MP, _MP, _MP, _MW, _MW, _MW, _MP, _MP, _MP, _MP, _MP, _MP
; 	; .DB _MW, _MP, _MW, _MP, _MW, _MW, _MP, _MW, _MW, _MW, _ME, _MW, _MW, _MW, _MW, _MP
; 	; .DB _MW, _MP, _MW, _MP, _MW, _MW, _MP, _MW, _MW, _MW, _MW, _MW, _MW, _MW, _MW, _MP
; 	; .DB _MW, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MW, _MW, _MW, _MW, _MP
; 	; .DB _MW, _MP, _MW, _MP, _MW, _MW, _MP, _MW, _MW, _MW, _MP, _MP, _MP, _MP, _MP, _MP
; 	; .DB _MW, _MP, _MW, _MP, _MW, _MW, _MP, _MP, _MP, _MP, _MW, _MW, _MP, _MW, _MW, _MP
; 	; .DB _MW, _MP, _MP, _MP, _MP, _MP, _MP, _MW, _MW, _MP, _MW, _MW, _MP, _MW, _MW, _MP
; 	; .DB _MW, _MP, _MW, _MP, _MW, _MW, _MP, _MW, _MW, _MP, _MW, _MW, _MP, _MW, _MW, _MP
; 	; .DB _MW, _MP, _MW, _MP, _MW, _MW, _MP, _MW, _MW, _MP, _MW, _MW, _MP, _MW, _MW, _MP
; 	; .DB _MW, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MP
; 	; .DB _MW, _MP, _MW, _MP, _MW, _MW, _MP, _MW, _MW, _MP, _MW, _MW, _MP, _MW, _MW, _MW
; 	; .DB _MW, _MP, _MW, _MP, _MW, _MW, _MP, _MW, _MW, _MP, _MW, _MW, _MP, _MP, _MP, _MP
; 	; .DB _MW, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MP, _MW, _MW, _MW, _MP
; 	; .DB _MW, _MW, _MW, _MW, _MW, _MW, _MW, _MW, _MW, _MW, _MW, _MW, _MW, _MW, _MW, _MW

	.DB _MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
	.DB _MW,_MP,_MP,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MP,_MP,_MW
	.DB _MW,_MP,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MP,_MW
	.DB _MW,_MP,_MP,_MP,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
	.DB _MW,_MP,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
	.DB _MW,_MP,_MW,_MW,_MW,_MP,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
	.DB _MW,_MP,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
	.DB _MW,_MP,_MW,_MW,_MW,_MW,_MW,_MP,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
	.DB _MW,_MP,_MP,_MP,_MP,_MP,_MP,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
	.DB _MW,_MP,_MW,_MW,_MW,_MW,_MP,_MW,_MW,_MP,_MW,_MW,_MW,_MW,_MW,_MW
	.DB _MW,_MP,_MW,_MW,_MW,_MW,_MP,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
	.DB _MW,_MP,_MW,_MW,_MW,_MW,_MP,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
	.DB _MW,_MP,_MP,_MW,_MW,_MW,_MP,_MP,_MP,_MP,_MP,_MW,_MW,_MW,_MW,_MW
	.DB _MW,_MP,_MW,_MP,_MW,_MW,_MP,_MW,_MW,_MW,_MP,_MW,_MW,_MW,_MW,_MW
	.DB _MW,_MP,_MP,_MP,_MR,_MP,_MP,_MP,_ME,_MW,_MP,_MW,_MW,_MW,_MW,_MW
	.DB _MW,_MP,_MW,_MP,_MW,_MP,_MW,_MW,_MW,_MW,_MP,_MW,_MP,_MW,_MP,_MW
	.DB _MW,_MP,_MW,_MP,_MP,_MP,_MW,_MW,_MW,_MW,_MP,_MP,_MP,_MP,_MP,_MW
	.DB _MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW

	; .DB _MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW
	; .DB _MW,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MW
	; .DB _MW,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MW
	; .DB _MW,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MW
	; .DB _MW,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MW
	; .DB _MW,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MW
	; .DB _MW,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MW
	; .DB _MW,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MW
	; .DB _MW,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MW
	; .DB _MW,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MW
	; .DB _MW,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MW,_MW,_MW
	; .DB _MW,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MW,_MP,_MW
	; .DB _MW,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MW,_MP,_MW
	; .DB _MW,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MW,_MP,_MW
	; .DB _MW,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MW,_MP,_MP,_MP,_MW,_MP,_MW
	; .DB _MW,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MW,_MP,_MP,_MP,_MW,_MP,_MW
	; .DB _MW,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MP,_MW,_MP,_MP,_MP,_MP,_MP,_MW
	; .DB _MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW,_MW

SEENMAZE_INIT: ;DEBUG: Comment it because its has no function apart from debugging
	.DB _MW,_MW,_MW,_MW,_MW,_MW,_MW
	.DB _MP,_MP,_MP,_MP,_MP,_MP,_MP
	.DB _MW,_MW,_MW,_MW,_MW,_MW,_MW

; ; PLAYER
; PX:
; 	.DB 1,0
; PY:
; 	.DB 16,0

; ; Player direction (N,S,W,E):
; ;($00=North, $01=West, $02=South, $03=East)
; ;      N0
; ;      |
; ; W1 --+-- E3
; ;      |
; ;      S2
; PD: ; Needed for drawing the 3d view
; 	.DB 0,0

; PWD: ;L4085 - PassageWay Direction for generating maze
; 	.DB 1,0

; ; REX PARAMETERS
; RX:
; 	.DB 4,0;1,0
; RY:
; 	.DB 14,0;7,0

; ; SCORE: ; max value is FF (65.535), first byte is low part, second is high ($01,$00 is 1)
; ; 	.DB $00,$00,0

; ; -----
; ; Score
; ; -----
; ; The maximum score is 65536. A wrap back to 0 will then occur.
; SCORE:;L4536:  
; 	.DB $00,$00,0 ;DEFB _0, _0, _0, _0

; ; ; --------------------------------------------
; ; ; Score Increment of 200 for Escaping the Maze
; ; ; --------------------------------------------
; ; SCOREINC200:;L453A:  
; ; 	.DB $C8,0

; ; ; -----------------------------------------
; ; ; Score Increment of 5 for Avoiding Capture
; ; ; -----------------------------------------
; ; SCOREINC5:;L453E:  
; ; 	.DB $05,0

; GAMESTATE: ; 0=PLAYING, 1=GAMEOVER
; 	.DB 0,0 

; GAMECOUNTER: ; Increments in each iteration, used for rex position messages
; 	.DB 0,0

; GAMEFLAGS:  
; 	.DB $02	; Flags:
; 				;   Bit 7: 1=The player has been caught.
; 				;   Bit 6: 1=The player has moved forwards.
; 				;   Bit 5: 1=The player has not moved and so there is no need to redraw the view of the maze.
; 				;   Bit 4: 1=The Exit is visible.
; 				;   Bit 3: 1=Rex has moved.
; 				;   Bit 2: 1=Rex has moved into a new location.
; 				;   Bit 1: 1=Rex has his left foot forward, 0=Rex has his right foot forward.
; 				;   Bit 0: Controls the movement speed of Rex. It combines with bits 1 and 2 to form a 3 bit counter. Bit 0 will be forced to 1
; 				;          when the played is moving thereby forcing Rex to take quicker steps.

; STATUSTIMER:;L408B
; 	.DB $08	; Holds a timeout used to determine when to clear the status message area (maximum value=$08, $00 means countdown expired so clear the status message).

; TEMPDISTREX: ;L408C
; 	.DB $01	; Temporary store used when the view is being drawn to determine the distance to Rex ($00=Rex is at the same location as the player).

; KEYPRESS: ;L408A
; 	.DB $02	; Holds the key press INKEY$ code, used by the game loop

; DISTANCETOREX: ;L408D
; 	.DB $07,0 ; Holds the distance Rex is away from the player when in direct line of site. It is used to determine the sprite to display for Rex ($00=Rex at the same location as the player, $06=Rex is beyond visible range).
; 	; Added a byte next to it for debugging distancetore since it prints 2bytes in dispscore ;DEBUG
; RANDDATA:
; 	.DB %11010100,0

; ; ----------------------------------------------
; ; LOOKUP TABLES
; ; ----------------------------------------------


; ; ----------------------------------------------
; ; TEXT
; ; ----------------------------------------------
; ;Screen text buffer (18chars x 8rows)
; TEXTBUFFER:
; 	.DB "                 ",0
; 	.DB "                 ",0
; 	.DB "                 ",0
; 	.DB "                 ",0
; 	.DB "                 ",0
; 	.DB "                 ",0
; 	.DB "                 ",0
; 	.DB "                 ",0

BLANKLINE:
	.DB "                 ",0

BLANKLINEIMG:
	.DB 7,64
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000

SCORETEXT:
    .DB "SCORE",0

TXT_INTRO1:
    .DB "ANYONE  THERE  ?",0
TXT_INTRO2:
    .DB "WELL  PRESS  SOMETHING THEN.",0
TXT_COPYRIGHT:
    .DB "ALFREDO RODRIGUEZ",0

TXT_APPEAL:
    .DB "APPEAL",0
TXT_ACCEPTED:
    .DB "ACCEPTED",0
TXT_REJECTED:
    .DB "REJECTED",0

; "YOU HAVE BEEN"
; "POSTHUMOUSLY AWARDED"
; "     POINTS AND SENTENCED"
; "TO ROAM THE MAZE FOREVER."
; "    IF YOU WISH TO APPEAL"
; "        PRESS stop, ELSE"
; "             PRESS cont."
POSTHUMOUSLYSCREEN: ;25 CHARS WIDE + null(0)
	; .DB "YOU HAVE BEEN            ", 0
	; .DB "POSTHUMOUSLY AWARDED     ", 0
	; .DB "     POINTS AND SENTENCED", 0
	; .DB "TO ROAM THE MAZE FOREVER.", 0
	; .DB "    IF YOU WISH TO APPEAL", 0
	; .DB "         PRESS mode, ELSE", 0
	; .DB "             PRESS clear.", 0
	.DB "YOU HAVE BEEN", 0
	.DB "POSTHUMOUSLY AWARDED", 0
	.DB "POINTS AND SENTENCED", 0
	.DB "TO ROAM THE MAZE FOREVER.", 0
	.DB "IF YOU WISH TO APPEAL", 0
	.DB "PRESS mode, ELSE", 0
	.DB "PRESS clear.", 0

; INTRO RINGMASTER
; "   ROLL UP,ROLL UP,   "
; " SEE THE AMAZING      "
; " TYRANNOSAURUS REX    "
; " KING OF THE DINOSAURS"
; " IN HIS LAIR.         "
; " PERFECTLY PRESERVED  "
; " IN SILICON SINCE     "
; " PREHISTORIC TIMES,HE "
; " IS BROUGHT TO YOU FOR"
; " YOUR ENTERTAINMENT   "
; " AND EXHILARATION.    "
; "   IF YOU DARE TO     "
; " ENTER HIS LAIR,YOU DO"
; " SO AT YOUR OWN RISK. "
; " THE MANAGEMENT ACCEPT"
; " NO RESPONSIBILITY FOR"
; " THE HEALTH AND SAFETY"
; " OF THE ADVENTURER WHO"
; " ENTERS HIS REALM.THE "
; " MANAGEMENT ADVISE    "
; " THAT THIS IS NOT A   "
; " GAME FOR THOSE OF A  "
; " NERVOUS DISPOSITION. "
; "   IF YOU ARE IN ANY  "
; " DOUBT,THEN PRESS stop"
; " IF INSTRUCTIONS ARE  "
; " NEEDED TO PROCEEED,  "
; " THEN PRESS       list"
; " OTHERWISE PRESS  cont"
TXT_RINGMASTER1: ; 18B WIDE
    .DB "ROLL UP,ROLL UP, ", 0
	.DB "SEE THE AMAZING  ", 0
	.DB "TYRANNOSAURUS REX", 0
	.DB "KING OF THE      ", 0
	.DB "DINOSAURS IN HIS ", 0
	.DB "LAIR. PERFECTLY  ", 0
	.DB "PRESERVED IN     ", 0
	.DB "SILICON SINCE    ", 0
	.DB "PREHISTORIC      ", 0
	.DB "TIMES, HE IS     ", 0
	.DB "BROUGHT TO YOU   ", 0
	.DB "FOR YOUR         ", 0
	.DB "ENTERTAINMENT AND", 0
	.DB "EXHILARATION     ", 0
	.DB "   IF YOU DARE TO", 0
	.DB "ENTER HIS LAIR,  ", 0
	.DB "YOU DO SO AT YOUR", 0
	.DB "OWN RISK. THE    ", 0
	.DB "MANAGEMENT ACCEPT", 0
	.DB "NO RESPONSIBILITY", 0
	.DB "FOR THE HEALTH   ", 0
	.DB "AND SAFETY OF THE", 0
	.DB "ADVENTURER WHO   ", 0
	.DB "ENTERS HIS REALM.", 0
	.DB "THE MANAGEMENT   ", 0
	.DB "ADVISE THAT THIS ", 0
	.DB "IS NOT A GAME FOR", 0
	.DB "THOSE OF A       ", 0
	.DB "NERVOUS          ", 0
	.DB "DISPOSITION.     ", 0
	.DB "   IF YOU ARE IN ", 0
	.DB "ANY DOUBT,THEN   ", 0
	.DB "PRESS del        ", 0
	.DB "IF INSTRUCTIONS  ", 0
	.DB "ARE NEEDED TO    ", 0
	.DB "PROCEEED, THEN   ", 0
	.DB "PRESS mode       ", 0
	.DB "OTHERWISE PRESS  ", 0
	.DB "clear            ", 0

TXT_RINGMASTER2: ; 18B WIDE
	;"   THE MISTS OF TIME  "
	;" WILL PASS OVER YOU   "
	;" FOR ABOUT 30 SECONDS "
	;" WHILE TRANSPORTING   "
	;" YOU TO THE LAIR OF   "
	;" TYRANNOSAURUS REX.   "
	;"   BEST OF LUCK.....  "
	.DB "THE MISTS OF TIME", 0
	.DB "WILL PASS OVER   ", 0
	.DB "YOU FOR ABOUT 30 ", 0
	.DB "SECONDS WHILE    ", 0
	.DB "TRANSPORTING YOU ", 0
	.DB "TO THE LAIR OF   ", 0
	.DB "TYRANNOSAURUS REX", 0
	.DB "BEST OF LUCK.....", 0

; Controls Text Messages
CONTROLS:
	;"   THE ONLY CONTROLS  "
	;" YOU REQUIRE ARE:-    "
	;"   5....TURN LEFT     "
	;"   7....MOVE FORWARD  "
	;"   8....TURN RIGHT    "
	;" FURTHER INFORMATION  "
	;" IS PROVIDED DURING   "
	;" THE ENCOUNTER.       "
	;"   FOR EACH MOVE      "
	;" SCORING IS AS FOLLOWS"
	;"   5 PTS-WHILE HE IS  "
	;"         TRACKING YOU."
	;" 200 PTS-IF YOU ESCAPE"
	;"         HIS LAIR.    "
	;"   SINCE REX IS ALWAYS"
	;" TRYING TO MOVE       "
	;" TOWARDS HIS PREY,A   "
	;" SKILFUL ADVENTURER   "
	;" CAN CONTROL THE      "
	;" MONSTERS MOVEMENTS TO"
	;" IMPROVE HIS SCORE.   "
	;" THE ESCAPE ROUTE,    "
	;" WHICH IS AT THE END  "
	;" OF A CUL-DE-SAC,IS   "
	;" VISIBLE UP TO 5 MOVES"
	;" AWAY.                "
	;"   THE GAME ENDS WHEN "
	;" HE CATCHES YOU.IF YOU"
	;" ESCAPE A NEW MAZE IS "
	;" GENERATED AND YOUR   "
	;" PREVIOUS SCORE       "
	;" CARRIED FORWARD.     "

	.DB "THE ONLY CONTROLS", 0
	.DB "YOU REQUIRE ARE:-", 0
	.DB "  <....TURN LEFT ", 0
	.DB "  ^....MOVE FWD  ", 0
	.DB "  >....TURN RIGHT", 0
	.DB "  FURTHER INFO IS", 0
	.DB "PROVIDED DURING  ", 0
	.DB "THE ENCOUNTER.   ", 0
	.DB "  FOR EACH MOVE  ", 0
	.DB "SCORING IS AS    ", 0
	.DB "FOLLOWS:         ", 0
	.DB "   5 PTS-WHILE HE", 0
	.DB "      IS TRACKING", 0
	.DB "             YOU.", 0
	.DB "   200 PTS-IF YOU", 0
	.DB " ESCAPE HIS LAIR.", 0
	.DB "   SINCE REX IS  ", 0
	.DB "ALWAYS TRYING TO ", 0
	.DB "MOVE TOWARDS HIS ", 0
	.DB "PREY, A SKILFUL  ", 0
	.DB "ADVENTURER CAN   ", 0
	.DB "CONTROL THE      ", 0
	.DB "MONSTERS MOVEMENT", 0
	.DB "TO IMPROVE HIS   ", 0
	.DB "SCORE. THE ESCAPE", 0
	.DB "ROUTE, WHICH IS  ", 0
	.DB "AT THE END OF A  ", 0
	.DB "CUL-DE-SAC, IS   ", 0
	.DB "VISIBLE UP TO    ", 0
	.DB "5 MOVES AWAY.    ", 0
	.DB "   THE GAME ENDS ", 0
	.DB "WHEN HE CATCHES  ", 0
	.DB " YOU. IF YOU     ", 0
	.DB "ESCAPE A NEW MAZE", 0
	.DB "IS GENERATED AND ", 0
	.DB "YOUR PREVIOUS    ", 0
	.DB "SCORE CARRIED    ", 0
	.DB "FORWARD.         ", 0

; ------------------------------
; Successful Escape Message Text
; ------------------------------
; " YOU  "
; " HAVE "
; "ELUDED"
; " HIM  "
; " AND  "
; "SCORED"
; "      "
; "POINTS"
; "      "
; "REX IS"
; " VERY "
; "ANGRY "
; "      "
; "YOU,LL"
; " NEED "
; " MORE "
; " LUCK "
; " THIS "
; " TIME."
TXT_ESCAPE: ; 10 lines
	.DB " YOU HAVE  ",0
	.DB "ELUDED HIM ",0
	.DB "AND SCORED ",0
	.DB "           ",0
	.DB "POINTS.    ",0
	.DB "REX IS VERY",0
	.DB "VERY ANGRY ",0
	.DB "YOU,LL NEED",0
	.DB "MORE LUCK  ",0
	.DB "THIS TIME  ",0

; REX STATUS MESSAGES (22B WIDE)
REXWAIT:
	;"   REX LIES IN WAIT   "
	.DB "   REX LIES IN WAIT   ",0

REXBEHIND:
	;" run HE IS BEHIND YOU "
	.DB " RUN HE IS BEHIND YOU ",0 

REXBESIDE:
	;" run HE IS BESIDE YOU "
	.DB " RUN HE IS BESIDE YOU ",0

REXSEEN:
	;"   REX HAS SEEN YOU   "
	.DB "   REX HAS SEEN YOU   ",0

REXAPPR:
	;" FOOTSTEPS APPROACHING"
	.DB " FOOTSTEPS APPROACHING",0

REXHUNT:
	;" HE IS HUNTING FOR YOU"
	.DB " HE IS HUNTING FOR YOU",0

REXEMPTY:
	;"                      "
	.DB "                      ",0

CHOOSERENDER:
	.DB "CHOOSE THE RENDERING:",0
ORIGINAL:
	.DB "(MODE)  ORIGINAL ",0
RAYCAST:
	.DB "(DEL)   RAYCASTED",0


; ----------------------------------------------
; IMAGES/SPRITES
; ----------------------------------------------
COPYRIGHT:
	.DB 8,8
	.DB %00000000
	.DB %00111110
	.DB %01000001
	.DB %01011101
	.DB %01010001
	.DB %01011101
	.DB %01000001
	.DB %00111110

; -------------------
; Rex Sprite Graphics
; -------------------
; REX DISTANCE 5 RIGHT STEP 
REX5R:	
	.DB 8,8
	.DB %11111111
	.DB %11111111
	.DB %11111111
	.DB %11111111
	.DB %11111111
	.DB %11111111
	.DB %11111111
	.DB %11111111

; REX DISTANCE 5 LEFT STEP 
REX5L:	
	.DB 10,8
	.DB %11111111
	.DB %11111111
	.DB %11111111
	.DB %11111111
	.DB %11111111
	.DB %11111111
	.DB %11111111
	.DB %11111111
	.DB %11111111
	.DB %11111111
	.DB %11111111
	.DB %11111111

; REX DISTANCE 4 RIGHT STEP
REX4R: 	
	.DB 6,8
	.DB %01100000
	.DB %01101000
	.DB %11111000
	.DB %01110000
	.DB %11110000
	.DB %11000000

; REX DISTANCE 4 LEFT STEP
REX4L: 	
	.DB 9,8
	.DB %01110000
	.DB %01110000
	.DB %00100000
	.DB %11011000
	.DB %11111100
	.DB %11110100
	.DB %01111000
	.DB %11111000
	.DB %00001100

; REX DISTANCE 3 RIGHT STEP
REX3R:	
	.DB 12,8
	.DB %00111000
	.DB %00111100
	.DB %00111100
	.DB %00011000
	.DB %01100100
	.DB %01111100
	.DB %11111100
	.DB %10111110
	.DB %01111110
	.DB %01111110
	.DB %01111111
	.DB %11110000

; REX DISTANCE 3 LEFT STEP
REX3L:	
	.DB 17,16
	.DB %00001111,%00000000
	.DB %00011111,%10000000
	.DB %00110110,%10000000
	.DB %00111111,%10000000
	.DB %00101111,%00000000
	.DB %00010000,%10000000
	.DB %00111001,%11000000
	.DB %00111111,%11000000
	.DB %00111111,%11100000
	.DB %00011111,%11100000
	.DB %00011111,%11000000
	.DB %00111111,%11000000
	.DB %01111111,%11000000
	.DB %01111111,%11000000
	.DB %00110111,%11000000
	.DB %11110001,%11000000
	.DB %00000001,%11100000

; REX DISTANCE 2 RIGHT STEP
REX2R:	
	.DB 22,16
	.DB %00000111,%11000000
	.DB %00001111,%11100000
	.DB %00001011,%10100000
	.DB %00001111,%11100000
	.DB %00011111,%11100000
	.DB %00010011,%10100000
	.DB %00111000,%00110000
	.DB %00111000,%01110000
	.DB %00111100,%11111000
	.DB %00111111,%11111000
	.DB %01111111,%11111000
	.DB %01101111,%11110000
	.DB %01101111,%11100000
	.DB %01011111,%11110000
	.DB %00011111,%11111000
	.DB %00111111,%11111100
	.DB %00111111,%10011100
	.DB %01111111,%10111100
	.DB %00111101,%11111100
	.DB %00011101,%11011111
	.DB %00111000,%00000000
	.DB %11111000,%00000000

; REX DISTANCE 2 LEFT STEP
REX2L:	
	.DB 28,24
	.DB %00000000,%11111000,%00000000
	.DB %00000001,%11111100,%00000000
	.DB %00000011,%11111110,%00000000
	.DB %00000011,%11111110,%00000000
	.DB %00000011,%11111110,%00000000
	.DB %00000011,%01111010,%00000000
	.DB %00000011,%11111110,%00000000
	.DB %00000101,%11111101,%00000000
	.DB %00000100,%11111011,%00000000
	.DB %00000110,%01110011,%10000000
	.DB %00001110,%00000111,%10000000
	.DB %00001111,%00001111,%11000000
	.DB %00001111,%10001111,%11000000
	.DB %00001111,%11111110,%11100000
	.DB %00000111,%11111110,%11100000
	.DB %00000011,%11111110,%01110000
	.DB %00000011,%11111111,%00110000
	.DB %00000111,%11111111,%10110000
	.DB %00001111,%11111111,%11110000
	.DB %00011111,%11111111,%11110000
	.DB %00111111,%11111111,%11100000
	.DB %00111101,%11111011,%11100000
	.DB %00111100,%11110111,%11100000
	.DB %00011100,%01111111,%11000000
	.DB %00111100,%01111011,%11000000
	.DB %11111000,%00111011,%10000000
	.DB %00000000,%00000011,%10000000
	.DB %00000000,%00000001,%11100000

; REX DISTANCE 1 RIGHT STEP
REX1R:	
	.DB 36,24
	.DB %00000000,%00000000,%00000000
	.DB %00000000,%00111111,%10000000
	.DB %00000000,%01111111,%11100000
	.DB %00000000,%11111111,%11100000
	.DB %00000001,%11111111,%11110000
	.DB %00000001,%11111111,%11110000
	.DB %00000001,%10011111,%00110000
	.DB %00000001,%11011111,%10100000
	.DB %00000011,%11111111,%11110000
	.DB %00000110,%11111111,%11111000
	.DB %00001111,%01110101,%11111000
	.DB %00001111,%00111111,%10111100
	.DB %00011111,%00011111,%00111100
	.DB %00011111,%10000000,%01111100
	.DB %00011111,%11000000,%01111100
	.DB %00111111,%11000000,%11111100
	.DB %00111011,%11100001,%11111100
	.DB %01111011,%11111111,%11111000
	.DB %01110111,%11111111,%11111000
	.DB %01100111,%11111111,%11110000
	.DB %01100111,%11111111,%11111000
	.DB %01001111,%11111111,%11111000
	.DB %00001111,%11111111,%11111100
	.DB %00001111,%11111111,%11111110
	.DB %00001111,%11111111,%11111111
	.DB %00011111,%11111111,%11111111
	.DB %00011111,%11111111,%01111111
	.DB %00011111,%11111111,%00111110
	.DB %00001111,%11111111,%11111110
	.DB %00001111,%11111111,%11111110
	.DB %00000111,%11101111,%11011100
	.DB %00000111,%11001111,%00111110
	.DB %00001111,%11000110,%00111111
	.DB %01111111,%11000000,%00000000
	.DB %01111111,%10000000,%00000000
	.DB %00000000,%00000000,%00000000

; REX DISTANCE 1 LEFT STEP
REX1L:	
	.DB 42,32
	.DB %00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00011111,%11100000,%00000000
	.DB %00000000,%00111111,%11110000,%00000000
	.DB %00000000,%01111111,%11111000,%00000000
	.DB %00000000,%11111111,%11111100,%00000000
	.DB %00000001,%11111111,%11111100,%00000000
	.DB %00000001,%11001111,%11001110,%00000000
	.DB %00000011,%11001111,%11001110,%00000000
	.DB %00000011,%11111111,%11111110,%00000000
	.DB %00000011,%11111111,%11111110,%00000000
	.DB %00000011,%11111111,%11111110,%00000000
	.DB %00000111,%11111011,%01111110,%00000000
	.DB %00001111,%11111111,%11111111,%00000000
	.DB %00011111,%00111111,%11110011,%10000000
	.DB %00111110,%00101111,%11010011,%10000000
	.DB %00111110,%00010100,%10100011,%11000000
	.DB %01111111,%00000011,%00001111,%11000000
	.DB %01111111,%10000000,%00011111,%11000000
	.DB %01111111,%01000000,%00101111,%11100000
	.DB %01111111,%01000000,%00101111,%11100000
	.DB %01111111,%00100000,%00101111,%11100000
	.DB %01111111,%11010000,%00101111,%11100000
	.DB %00111111,%11010000,%01001111,%11100000
	.DB %00011111,%11001100,%10111111,%11100000
	.DB %00101111,%11110011,%10111111,%11100000
	.DB %00110111,%11111100,%01111111,%11110000
	.DB %00111011,%11111111,%11111110,%11110000
	.DB %00011101,%11111111,%11111101,%11110000
	.DB %00011110,%11111111,%11111110,%11110000
	.DB %00001111,%11111111,%11111101,%11110000
	.DB %00001111,%11111111,%10011110,%11110000
	.DB %00000111,%11101111,%10111111,%01110000
	.DB %00000111,%11101111,%11111111,%10100000
	.DB %00000111,%11101111,%11111111,%10000000
	.DB %00001111,%11100111,%11110111,%10000000
	.DB %01111111,%11100111,%11100111,%10000000
	.DB %01111111,%11000011,%10000111,%11100000
	.DB %01111111,%10000000,%00000111,%11111000
	.DB %00000000,%00000000,%00000011,%11111100
	.DB %00000000,%00000000,%00000011,%11111110
	.DB %00000000,%00000000,%00000001,%11111110
	.DB %00000000,%00000000,%00000000,%00000000

; REX DISTANCE 0 RIGHT STEP (Rex Mouth Open Screen.)
REX0R: 	
	.DB 64,64
	.DB %11111110,%00000111,%11111111,%11111111,%11000001,%11101111,%11000000,%00000000
	.DB %11110000,%00001111,%11111111,%11111111,%11100000,%11101111,%11000000,%00000000
	.DB %00000000,%00011111,%11111111,%11111111,%11000000,%01110111,%11000000,%00000000
	.DB %00000000,%01111111,%11111111,%11111111,%11000000,%00111111,%11000000,%00000000
	.DB %00000001,%11111111,%11111111,%11111111,%11100000,%00001111,%10000000,%00000000
	.DB %11111111,%11111111,%11111111,%11111111,%11110000,%00000000,%00000000,%00000000
	.DB %11111111,%11111111,%11111111,%11111111,%11111000,%00000000,%00000000,%00000000
	.DB %11111111,%11111111,%11111111,%11111111,%11111110,%00000000,%00000000,%00000000
	.DB %11111111,%11111111,%10000111,%11111111,%11111111,%11000000,%00000000,%00000000
	.DB %11111111,%11111110,%00000011,%11111000,%01111111,%11111111,%10000000,%00000000
	.DB %11111111,%11111100,%00000011,%11110000,%00111111,%11111111,%11000000,%00000000
	.DB %11111111,%11111111,%00000111,%11110000,%00011111,%11111111,%11000000,%00000000
	.DB %11111111,%11111111,%11111111,%11111110,%00011111,%11111111,%11000000,%00000000
	.DB %11111111,%11111111,%11111111,%11111111,%11111111,%11111111,%11000000,%00000000
	.DB %11111111,%11111111,%11111111,%11111111,%11111111,%11111111,%11000000,%00000000
	.DB %11111111,%11111111,%11111111,%11111111,%11111111,%11111111,%11000000,%00000000
	.DB %11111111,%11111111,%11111111,%11111111,%11111111,%11111111,%11000000,%00000000
	.DB %11111111,%10000111,%00000011,%10000001,%11111111,%11111111,%11000000,%00000000
	.DB %11001110,%00000111,%00000101,%10000010,%11110000,%00111111,%11000000,%00000000
	.DB %00001110,%00001111,%00000101,%10000010,%11110000,%00011111,%11000000,%00000000
	.DB %00001011,%00001011,%00001001,%10000100,%11110000,%00101100,%00000000,%00000000
	.DB %00010011,%00010011,%00001001,%11000100,%01110000,%00101100,%00000000,%00000000
	.DB %00010001,%00010001,%00010000,%11001000,%01110000,%01001100,%00000000,%00000000
	.DB %00100000,%10100001,%11100000,%11110000,%01111000,%10001100,%00000000,%00000000
	.DB %00100000,%11000000,%11000000,%01100000,%00111001,%00001100,%00000000,%00000000
	.DB %10100000,%00000000,%00000000,%00000000,%00011110,%00000110,%01000000,%00000000
	.DB %11000000,%00000000,%00000000,%00000000,%00000000,%00000110,%10000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000111,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00011000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00111100,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %01111100,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %11100100,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %11100010,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %11000010,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %10000010,%00000111,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %10000010,%00111110,%10000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %11000010,%01110000,%10000001,%10000000,%11000000,%00000000,%00000000,%00000000
	.DB %11110010,%11100000,%01000011,%11000001,%11100000,%11100000,%00000000,%00000000
	.DB %11111111,%11000000,%01000111,%00100001,%10010001,%11010000,%01000000,%00000000
	.DB %11111111,%10000000,%10000110,%00010011,%00010001,%10001001,%10000000,%00000000
	.DB %11111111,%10000000,%10001100,%00010011,%00001011,%00000101,%00000000,%00000000

; REX DISTANCE 0 LEFT STEP ("You Have Been Posthumously Awarded" Screen.)
REX0L: 	
	.DB 64,64
	.DB %01111111,%11111111,%11111111,%11111111,%11111111,%11111111,%11111111,%11111110
	.DB %01111111,%11111111,%11111111,%11111111,%11111111,%11111111,%11111111,%11111110
	.DB %01111111,%11111111,%11000011,%11111110,%00111111,%11111111,%11111111,%11111110
	.DB %01111111,%11100011,%11000001,%10111100,%00000101,%11111111,%11111111,%11111110
	.DB %01110011,%10000011,%11000001,%00111100,%00000101,%11111111,%11111111,%11111110
	.DB %01000011,%10000110,%11000010,%00111000,%00001001,%11100011,%11111111,%11111110
	.DB %00000111,%10000100,%11000010,%00011000,%00010001,%11100000,%11111111,%11111110
	.DB %00000101,%10000100,%01100100,%00011000,%00100001,%11100001,%00111111,%11111110
	.DB %01001100,%11001100,%00100100,%00010000,%01000001,%11000010,%00011111,%11111110
	.DB %01101000,%11001000,%00011000,%00010000,%10000001,%10000010,%00111110,%00011110
	.DB %00101000,%01101000,%00000000,%00001111,%00000001,%10001100,%00111000,%00000110
	.DB %00011000,%00011000,%00000000,%00000000,%00000001,%10010000,%00111000,%00001100
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%11100000,%00110000,%00010000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%01110000,%01100000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%01100001,%10000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%01100010,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%01001100,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%01110000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00100000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %01100001,%11110000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00100011,%11111000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %00100111,%10011000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %01100110,%00011000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %01101000,%00011000,%00111000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %01111000,%00010000,%11101000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %01110000,%00010001,%10001000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %01111110,%00100111,%00001000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %01111111,%00101110,%00001000,%00000000,%00000000,%00000000,%00000000,%00000000
	.DB %01111111,%11011100,%00001000,%00011100,%00000000,%00000000,%00000000,%00000000
	.DB %01111111,%11111000,%00001000,%01110110,%00000000,%00000000,%00000000,%00000000
	.DB %01111111,%11111000,%00010000,%11100010,%00011100,%00000000,%00000000,%00000000
	.DB %01111111,%11111100,%00010001,%11000010,%00110100,%00000000,%00000000,%00000000
	.DB %01111111,%11111110,%00100011,%10000100,%01110010,%00110000,%00000000,%00000000
	.DB %01111111,%11111111,%11100111,%00000100,%11100010,%01101000,%01100000,%11000000
	.DB %01111111,%11111111,%11111110,%00001001,%11000010,%01001000,%10010001,%00100000
		

; RINGMASTER
RINGMASTER:
	.DB 53,32 ; 53X27
	.DB %11111111,%11111111,%11111111,%11100000
	.DB %11111111,%10000000,%11111111,%11100000
	.DB %11111111,%10000000,%11111111,%11100000
	.DB %11111111,%10000000,%11111111,%11100000
	.DB %11111111,%10000000,%11111111,%11100000
	.DB %11111111,%10000000,%11111111,%11100000
	.DB %11111000,%11111111,%10001111,%11100000
	.DB %11111111,%00000000,%01110001,%11100000
	.DB %11111111,%00001000,%01110001,%11100000
	.DB %11111111,%01010101,%01110000,%11100000
	.DB %11111111,%00001000,%01111100,%01100000
	.DB %11111111,%00000000,%01111100,%01100000
	.DB %11111111,%00011100,%01111100,%01100000
	.DB %11111111,%10011100,%11111000,%01100000
	.DB %11111111,%01000001,%01111000,%01100000
	.DB %11111110,%00100010,%00111000,%01100000
	.DB %11111000,%00011100,%00011000,%00100000
	.DB %11110000,%00000000,%00001000,%00100000
	.DB %11100000,%00000000,%00001000,%00100000
	.DB %11000000,%00000000,%00001000,%00100000
	.DB %10000000,%00000000,%00000000,%00100000
	.DB %10000000,%00000000,%00000000,%00100000
	.DB %10000000,%00010000,%00000000,%00100000
	.DB %10001000,%00011000,%00000000,%00100000
	.DB %10001000,%00011000,%00100000,%01100000
	.DB %10001000,%00010100,%00010000,%11100000
	.DB %10001000,%00010100,%00001111,%11100000
	.DB %10001000,%00100100,%00000111,%11100000
	.DB %10001000,%00100010,%00000111,%11100000
	.DB %10001000,%01000001,%00000111,%11100000
	.DB %10001000,%10001000,%10000111,%11100000
	.DB %10000001,%00010100,%01000111,%11100000
	.DB %10001110,%00101010,%00100111,%11100000
	.DB %10001000,%01010101,%00011111,%11100000
	.DB %10000010,%10101010,%10000111,%11100000
	.DB %11010101,%01010101,%01000111,%11100000
	.DB %11100010,%10101010,%10100111,%11100000
	.DB %11100101,%01000001,%01000111,%11100000
	.DB %11110010,%10101010,%10101111,%11100000
	.DB %11110101,%01001001,%01001111,%11100000
	.DB %11110010,%10101010,%10101111,%11100000
	.DB %11110101,%01001001,%01001111,%11100000
	.DB %11110010,%10101010,%10101111,%11100000
	.DB %11110101,%01001001,%01001111,%11100000
	.DB %11110010,%10011100,%10101111,%11100000
	.DB %11110101,%01011101,%01001111,%11100000
	.DB %11110010,%10011100,%10101111,%11100000
	.DB %11110101,%01011101,%01001111,%11100000
	.DB %11110010,%10011100,%10001111,%11100000
	.DB %11110001,%01011101,%00011111,%11100000
	.DB %11111010,%10011100,%10111111,%11100000
	.DB %11111001,%00111101,%00111111,%11100000
	.DB %11111100,%00111100,%01111111,%11100000

; Ringmaster Bowing Graphic
RINGMASTERHAT:
	.DB 53,32 ; 53X27
	.DB %11111111,%11111111,%11111111,%11100000
	.DB %11111111,%11111111,%11111111,%11100000
	.DB %11111111,%11111111,%11111111,%11100000
	.DB %11111111,%11111111,%11111111,%11100000
	.DB %11111111,%11111111,%11111111,%11100000
	.DB %11111111,%11111111,%11111111,%11100000
	.DB %11111111,%11100011,%11111111,%11100000
	.DB %11111111,%10010100,%11111111,%11100000
	.DB %11111111,%00101010,%01111111,%11100000
	.DB %11111111,%01010101,%01111111,%11100000
	.DB %11111110,%10101010,%10111111,%11100000
	.DB %11111110,%01010101,%00111111,%11100000
	.DB %11111110,%10101010,%10111111,%11100000
	.DB %11111111,%01010101,%01111111,%11100000
	.DB %11111111,%00101010,%01111111,%11100000
	.DB %11111111,%10010100,%11111111,%11100000
	.DB %11111000,%11100011,%00111111,%11100000
	.DB %11110000,%00111110,%00001111,%11100000
	.DB %11100000,%00010100,%00000111,%11100000
	.DB %11000000,%00001000,%00000111,%11100000
	.DB %10000000,%00000000,%00000011,%11100000
	.DB %10000000,%00111000,%00000011,%11100000
	.DB %10000001,%11000111,%01000011,%11100000
	.DB %10001010,%00000000,%11000011,%11100000
	.DB %10001010,%00000000,%01000011,%11100000
	.DB %10001010,%00000000,%01000011,%11100000
	.DB %10001010,%00000000,%01000011,%11100000
	.DB %10001010,%00000000,%10000111,%11100000
	.DB %10001010,%00000001,%00000111,%11100000
	.DB %10001001,%00000010,%00011111,%11100000
	.DB %10001000,%11110100,%00111111,%11100000
	.DB %10000000,%00001000,%01011111,%11100000
	.DB %10001100,%10101111,%10001111,%11100000
	.DB %10001001,%01010101,%00000111,%11100000
	.DB %10000010,%10101010,%10000111,%11100000
	.DB %11010101,%01010101,%01000111,%11100000
	.DB %11100010,%10101010,%10100111,%11100000
	.DB %11100101,%01000001,%01000111,%11100000
	.DB %11110010,%10101010,%10101111,%11100000
	.DB %11110101,%01001001,%01001111,%11100000
	.DB %11110010,%10101010,%10101111,%11100000
	.DB %11110101,%01001001,%01001111,%11100000
	.DB %11110010,%10101010,%10101111,%11100000
	.DB %11110101,%01001001,%01001111,%11100000
	.DB %11110010,%10011100,%10101111,%11100000
	.DB %11110101,%01011101,%01001111,%11100000
	.DB %11110010,%10011100,%10101111,%11100000
	.DB %11110101,%01011101,%01001111,%11100000
	.DB %11110010,%10011100,%10001111,%11100000
	.DB %11110001,%01011101,%00011111,%11100000
	.DB %11111010,%10011100,%10111111,%11100000
	.DB %11111001,%00111101,%00111111,%11100000
	.DB %11111100,%00111100,%01111111,%11100000

.validate
