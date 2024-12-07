IDEAL
MODEL small
STACK 100h
DATASEG
; --------------------------
Cube_Size = 7;pixels
Board_Width_By_Cube = 13
Board_Length_By_Cube = 20
Board_Left_X_Border = 116
Board_Right_X_Boarder = 206
Board_Up_Y_Border = 33
Board_Down_Y_Boarder = 172

	;RANDOM data
	RndCurrentPos dw start
	
	;GRAPHICS data
	matrix dw ?
	
	;BMP FILE data
	FileName 	db 'FileName.bmp',0
	OpeningScreenFileName db  'OpenSC.bmp',0
	TutorialScreenFileName db 'TutoSc.bmp',0
	EndingScreenFileName db 'EndSC.bmp',0
	FullBlackLineEndScreen db 'BLEndSC.bmp',0
	BoardFileName db 'Board1.bmp',0
	NextPieceName db 0
	PieceFileName db 'A51.bmp',0;First digit = name of piece, Second digit = rotation, Third digit = style
	BlankPieceFileName db 'A5B.bmp',0;First digit = name of piece, Second digit = rotation
	SingleDigitFileName db 'D0C1.bmp',0;First digit = D(digit), Second digit = value, Third digit = color, Fourth digit = style. SIZE: 7*7
	SingleDigitEndScreenFileName db 'BigDES0.bmp',0;Big Digit (D) End Screen (ES) + last digit (seventh) = value
	BigPieceFileName db 'BigPA.bmp',0;Big piece + letter (name of piece)
	BlankSingleCubeMatrix db 637 dup (0);Black 7*7*13 matrix
	PieceBackgroundColor db 0
	FileHandle	dw ?
	Header 	    db 54 dup(0)
	Palette 	db 400h dup (0)
	BmpLeft    dw ?
	BmpTop     dw ?
	BmpColSize dw ?
	BmpRowSize dw ?
	ErrorFile  db 0
    ScrLine    db 320 dup (0)  ; One Color line read buffer
	
	
	;Movement
	CanMoveRightBool db 0
	CanMoveLeftBool db 0
	CanMoveDownBool db 0
	CanRotatePieceBool db 0
	
	x dw 0;Current piece's x pos
	y dw 0;Current piece's y pos
	preX dw 0;Previous piece's move's x pos
	preY dw 0;Previous piece's move's y pos
	
	EndGameBool db 0;1 = End game, 0 = Continue
	;Control
	RoundDelayTime  dw 0;Current round's delay time counter
	DelayTime db 0;Indicates how many times should the delay loop run in a round.
	
	;Delete rows
	DeleteRowsTotalCounter dw 0;Total counter of deleted rows
	DeleteRowsCounter db 0	;Number of rows to delete
	DeleteRowsArray db 4 dup (0)	;Each place represents the number of row to delete (0-19)
	
	RandomPieceArray db 'I','O','T','S','Z','L','J';Filled with the names of the pieces, used to choose the next random piece to spawn
	RandomPieceArrayPointer db 6;Indicates in how many more "picks" of pieces need to refill (Var+1) the array ("bag") + Var = place to switch (for function...)
	
	;Statistics
	TimeEachPieceWasUsed dw 7 dup (0);Order is: T, J, Z, O, S, L, I
	TopScoreFileName db 'TopSC.txt',0;Name of the file containing (only the number) of the top score. UPDATE AT END OF GAME.
	TopScoreBuffer db 6 dup (0);Read to here the top score (each byte = each digit)
	TopScore dw 2 dup (0);Top score (when the game started)
	CurrentScore dw 2 dup (0); Current score (of this game) {first word is most left digit, second word is rest of digits}
	CurrentLevel db 0;Current level
; Your variables here
; --------------------------

CODESEG
start:
	mov ax, @data
	mov ds, ax
; --------------------------
;Opening screen
	;SWITCH TO GRAPHIC MODE
	call SetGraphic
ShowOpeningScreenLabel:
	;Show opening screen
	call ShowOpeningScreen

CheckKeyOpeningScreen:
	;Check if key was pressed
	mov ah, 1
	int 16h	
	jz CheckKeyOpeningScreen;If key wasn't pressed --> return
	;Check which key was pressed
	push ax
	;Clear the keyboard buffer
	mov ah, 0Ch
	xor al, al;Ax = 0C00h
	int 21h	
	pop ax
	cmp ah, 17h;Check if 'I' was pressed --> show tutorial
	jz ShowTutorialScreenLabel
	cmp ah, 01h;Check if 'Escape' was pressed --> EXIT game
	jz JumpToExitLabel
	cmp ah, 1Ch;Check if 'Enter' was pressed --> start game
	jz SetupGame
	jmp CheckKeyOpeningScreen;If another key was pressed --> return
	
ShowTutorialScreenLabel:
	call ShowTutorialScreen
CheckKeyTutorialScreen:
	;Check if key was pressed
	mov ah, 1
	int 16h	
	jz CheckKeyTutorialScreen;If key wasn't pressed --> return
	;Clear the keyboard buffer
	push ax
	mov ah, 0Ch
	xor al, al;Ax = 0C00h
	int 21h	
	pop ax
	cmp ah, 01;Check if 'Escape' was pressed --> return to opening screen
	jz ShowOpeningScreenLabel
	jmp CheckKeyTutorialScreen;If other key was pressed --> return

;--->
JumpToExitLabel:
	;switch to text mode
	call SetText	
	;exit
	jmp exit

;--->


;Setup game	
SetupGame:
	call DrawBoard
	;Game = clean board until game over
	;New piece = board not necessarily clean, game not over and need new piece
	;Round = board not necessarily clean, game not over and not need new piece

;Start game	
StartGame:
	;Get piece from main single time --> next time get next piece as showed on screen
	;NEXT CALL TO GetNextPiece will be in procedure UpdateNextPiece
	call GetNextPiece;al = FileName
	mov [NextPieceName], al;[NextPieceName] = name of piece *BECAUSE OF UpdateNextPiece*
	call GetTopScore;Get top score (happens once in the start of the game)
	call PrintTopScore;Print top score (happens once in the start of the game)
	
;New Piece
NewPiece:

;If need to delete rows
DeleteRows:
	call CheckEveryRow
	;Clear the keyboard buffer
	mov ah, 0Ch
	xor al, al;Ax = 0C00h
	int 21h
	cmp [DeleteRowsCounter], 0;If 0 --> no need to delete any rows, continue
	jz AfterDeleteRows
	;If can delete rows
	call DeleteRowAnimation
	call LowerRows
	;Clear the keyboard buffer
	mov ah, 0Ch
	xor al, al;Ax = 0C00h
	int 21h	
	
;After checking (and deleting) rows
AfterDeleteRows:
	call UpdateNextPiece
	
;Setup round	
	call SetupFirstRound
	call UpdateDelayTime;Update round's delay time
	;CHECK IF CAN GENERATE PIECE
	call CanPieceGenerate;IF CAN'T GENERATE PIECE --> END GAME, ELSE --> CONTINUE
	cmp al, 0;If al = 0 --> piece can't generate
	jz EndGame;If can't generate piece --> end game
	;	If can generate piece
	mov al, [PieceFileName];Name of piece
	mov ah, [PieceFileName+1];'0' <-> Rotations
	call UpdateStatistics;Update stats (time of appearance) of piece
	call PrintHUD;Print HUD
	call SetupPiece
	call DrawPiece
	;In new piece need to reduce the delay time
	
;Start round
StartRound:
	call SetupRound
	;MidRound is the time between where the piece last moved down and the next time it moves down

;Delay round	
StartDelayRound:
	;Call delay
	mov cx, 10
DelayL:
	call DelayMiliSec
	loop DelayL
		;Check if delay of round COUNTER reached the round's delay time
	mov cx, [RoundDelayTime]
	inc cx

	cmp cl, [DelayTime];If current's round delay time is equal to the round's delay time --> end round
	jz EndRound
	mov [RoundDelayTime], cx;Increase [RoundDelayTime]

;Check keys	
	;Check if key was pressed
	mov ah, 1
	int 16h	
	jz ContDelayRound;If key wasn't pressed --> continue
	
	;If key was pressed
	call GameKeys
	
ContDelayRound:
	jmp StartDelayRound

;End round
EndRound:
	mov [RoundDelayTime], 0
	;If piece can't move down --> round ends
;Move piece down
	call CheckMoveDown
	mov al, [CanMoveDownBool]
	;If al = 1 --> piece can move down and round can continue, If al = 0 --> round is over
	cmp al, 1
	jnz NewPiece;If can't move down --> new piece
	;If can move down
	;Hide piece
	call SetupBlankPiece
	call DrawBlankPiece
	;Move piece
	call MoveDownPiece
	;Draw piece
	call DrawPiece
	
	jmp StartRound;Start new round
	
;End game
EndGame:
	;Update top score (if need)
	call UpdateTopScore
	;Show end screen
	call ShowEndScreen
	;Clear the keyboard buffer
	mov ah, 0Ch
	xor al, al;Ax = 0C00h
	int 21h
CheckKeyEndingScreen:
	;Check if key was pressed
	mov ah, 1
	int 16h	
	jz CheckKeyEndingScreen;If key wasn't pressed --> return
;Leave game
ExitGameLabel:
	call SetText
; --------------------------

exit:
	mov ax, 4c00h
	int 21h
	
	
;BIG TEXT GENERATOR (Stforek Text Art Generator)
;https://www.fancytextpro.com/BigTextGenerator/Stellar
;
; ___ _  _ __  _  ________ _  __  __  _   __  
;| __| || |  \| |/ _/_   _| |/__\|  \| |/' _/ 
;| _|| \/ | | ' | \__ | | | | \/ | | ' |`._`. 
;|_|  \__/|_|\__|\__/ |_| |_|\__/|_|\__||___/ 



; _____ _ __ __ ___ ___  
;|_   _| |  V  | __| _ \ 
;  | | | | \_/ | _|| v / 
;  |_| |_|_| |_|___|_|_\ 


;Delay milisecond (3000 cycle)
proc DelayMiliSec
	push cx
	mov cx, 3000
@@Self2:
	loop @@Self2
	pop cx
	ret
endp DelayMiliSec
 
 
;___  __  __  _ __   __  __ __  
;| _ \/  \|  \| | _\ /__\|  V  | 
;| v / /\ | | ' | v | \/ | \_/ | 
;|_|_\_||_|_|\__|__/ \__/|_| |_| 


; Description  : get RND between any bl and bh includs (max 0 -255)
; Input        : 1. Bl = min (from 0) , BH , Max (till 255)
; 			     2. RndCurrentPos a  word variable,   help to get good rnd number
; 				 	Declre it at DATASEG :  RndCurrentPos dw ,0
;				 3. EndOfCsLbl: is label at the end of the program one line above END start		
; Output:        Al - rnd num from bl to bh  (example 50 - 150)
; More Info:
; 	Bl must be less than Bh 
; 	in order to get good random value again and agin the Code segment size should be 
; 	at least the number of times the procedure called at the same second ... 
; 	for example - if you call to this proc 50 times at the same second  - 
; 	Make sure the cs size is 50 bytes or more 
; 	(if not, make it to be more) 
proc RandomByCs
    push es
	push si
	push di
	
	mov ax, 40h
	mov	es, ax
	
	sub bh,bl  ; we will make rnd number between 0 to the delta between bl and bh
			   ; Now bh holds only the delta
	cmp bh,0
	jz @@ExitP
 
	mov di, [word RndCurrentPos]
	call MakeMask ; will put in si the right mask according the delta (bh) (example for 28 will put 31)
	
RandLoop: ;  generate random number 
	mov ax, [es:06ch] ; read timer counter
	mov ah, [byte cs:di] ; read one byte from memory (from semi random byte at cs)
	xor al, ah ; xor memory and counter
	
	; Now inc di in order to get a different number next time
	inc di
	cmp di,(EndOfCsLbl - start - 1)
	jb @@Continue
	mov di, offset start
@@Continue:
	mov [word RndCurrentPos], di
	
	and ax, si ; filter result between 0 and si (the nask)
	cmp al,bh    ;do again if  above the delta
	ja RandLoop
	
	add al,bl  ; add the lower limit to the rnd num
		 
@@ExitP:	
	pop di
	pop si
	pop es
	ret
endp RandomByCs

; Description  : get RND between any bx and dx includs (max 0 - 65535)
; Input        : 1. BX = min (from 0) , DX, Max (till 64k -1)
; 			     2. RndCurrentPos a  word variable,   help to get good rnd number
; 				 	Declre it at DATASEG :  RndCurrentPos dw ,0
;				 3. EndOfCsLbl: is label at the end of the program one line above END start		
; Output:        AX - rnd num from bx to dx  (example 50 - 1550)
; More Info:
; 	BX  must be less than DX 
; 	in order to get good random value again and again the Code segment size should be 
; 	at least the number of times the procedure called at the same second ... 
; 	for example - if you call to this proc 50 times at the same second  - 
; 	Make sure the cs size is 50 bytes or more 
; 	(if not, make it to be more) 
proc RandomByCsWord
    push es
	push si
	push di
 
	
	mov ax, 40h
	mov	es, ax
	
	sub dx,bx  ; we will make rnd number between 0 to the delta between bx and dx
			   ; Now dx holds only the delta
	cmp dx,0
	jz @@ExitP
	
	push bx
	
	mov di, [word RndCurrentPos]
	call MakeMaskWord ; will put in si the right mask according the delta (bh) (example for 28 will put 31)
	
@@RandLoop: ;  generate random number 
	mov bx, [es:06ch] ; read timer counter
	
	mov ax, [word cs:di] ; read one word from memory (from semi random bytes at cs)
	xor ax, bx ; xor memory and counter
	
	; Now inc di in order to get a different number next time
	inc di
	inc di
	cmp di,(EndOfCsLbl - start - 2)
	jb @@Continue
	mov di, offset start
@@Continue:
	mov [word RndCurrentPos], di
	
	and ax, si ; filter result between 0 and si (the nask)
	
	cmp ax,dx    ;do again if  above the delta
	ja @@RandLoop
	pop bx
	add ax,bx  ; add the lower limit to the rnd num
		 
@@ExitP:
	
	pop di
	pop si
	pop es
	ret
endp RandomByCsWord

; make mask acording to bh size 
; output Si = mask put 1 in all bh range
; example  if bh 4 or 5 or 6 or 7 si will be 7
; 		   if Bh 64 till 127 si will be 127
Proc MakeMask    
    push bx

	mov si,1
    
@@again:
	shr bh,1
	cmp bh,0
	jz @@EndProc
	
	shl si,1 ; add 1 to si at right
	inc si
	
	jmp @@again
	
@@EndProc:
    pop bx
	ret
endp  MakeMask
Proc MakeMaskWord    
    push dx
	
	mov si,1
    
@@again:
	shr dx,1
	cmp dx,0
	jz @@EndProc
	
	shl si,1 ; add 1 to si at right
	inc si
	
	jmp @@again
	
@@EndProc:
    pop dx
	ret
endp  MakeMaskWord

;  ___ __  __  _ _____ ___  __  _      __  __  _ __    _  _______   __ __  
; / _//__\|  \| |_   _| _ \/__\| |    /  \|  \| | _\  | |/ / __\ `v' /' _/ 
;| \_| \/ | | ' | | | | v / \/ | |_  | /\ | | ' | v | |   <| _| `. .'`._`. 
; \__/\__/|_|\__| |_| |_|_\\__/|___| |_||_|_|\__|__/  |_|\_\___| !_! |___/ 
;---

;	DESCRIPTION: Open and show the opening screen using OpenShowBmp. shows the picture (320*200) at (0,0)
proc ShowOpeningScreen
	push dx
	
	mov dx, offset OpeningScreenFileName
	mov [BmpTop], 0
	mov [BmpLeft], 0
	mov [BmpRowSize], 200
	mov [BmpColSize], 320
	call OpenShowBmp
	
	pop dx
	ret
endp ShowOpeningScreen

;	DESCRIPTION: Open and show the tutorial screen using OpenShowBmp. shows the picture (320*200) at (0,0)
proc ShowTutorialScreen
	push dx
	
	mov dx, offset TutorialScreenFileName
	mov [BmpTop], 0
	mov [BmpLeft], 0
	mov [BmpRowSize], 200
	mov [BmpColSize], 320
	call OpenShowBmp
	
	pop dx
	ret
endp ShowTutorialScreen

;	DESCRIPTION: Draws end screen (including animation and score)
proc ShowEndScreen
	push ax
	push bx
	push cx
	push dx
	
	mov [BmpColSize], 320;width
	mov [BmpRowSize], 7;length
	mov [BmpTop], 199;y pos
	mov [BmpLeft], 0;x pos
	
	;DRAW ANIMATION
	mov cx, 28
@@ForEachRow:
	push cx;Save
	
	mov dx, [BmpTop]
	sub dx, 7
	mov [BmpTop], dx;y pos
	
	mov dx, offset FullBlackLineEndScreen 
	;Draw cube
@@DrawCube:
	call OpenShowBmp
	
	;Delay
	mov cx, 40
@@DelayLoopMidAnimation:
	call DelayMilisec
	loop @@DelayLoopMidAnimation
	
	pop cx;Restore
	loop @@ForEachRow
	
	mov [BmpTop], 0;y pos
	mov dx, offset FullBlackLineEndScreen 
	call OpenShowBmp;Draw cube
	
	;SHOW END SCREEN
	mov dx, offset EndingScreenFileName
	mov [BmpTop], 0
	mov [BmpLeft], 0
	mov [BmpColSize], 320
	mov [BmpRowSize], 200
	call OpenShowBmp
	
	;Print score -> from right to left
	mov [BmpColSize], 20;width
	mov [BmpRowSize],19;length
	mov [BmpLeft], 281;x pos
	mov [BmpTop], 99;y pos, stable
	
	;Get stats
	mov ax, [CurrentScore+2];Ax = Current score without first and second digits
	;Print each digit
	mov cx, 6;for each digit
@@ForEachDigit:
	push cx
	
	;Check if now 2 left digits
	;If cx = 2 --> already done 4 digits. Now print 2 left digits which are in [CurrentScore] second's byte
	cmp cx, 2
	jnz @@AfterGettingNumber
	;If cx = 2 --> move to ax the new number (2 left digits)
	mov ax, [CurrentScore];Ax = 2 left digits
	
@@AfterGettingNumber:
	;Get current digit
	xor dx, dx;Zero
	xor ch, ch;Zero
	mov cl, 10;Cx (Cl) = 10
	div cx;Ax = number without digit, Dx (Dl) = digit
	add dl, 30h;Turn value to ASCII
	mov [SingleDigitEndScreenFileName+6], dl;[SingleDigitEndScreenFileName+6] = current digit
	
	;Print digit
	push ax;save number
	mov dx, offset SingleDigitEndScreenFileName
	call OpenShowBmp;print digit
	pop ax;restore number

	mov bx, [BmpLeft];bx = x pos
	sub bx, 22;Bx = new x pos (more left than current pos = one digit left)
	mov [BmpLeft], bx;x pos
	
	pop Cx;Restore
	loop @@ForEachDigit

	pop dx
	pop cx
	pop bx
	pop ax
	ret
endp ShowEndScreen

;	DESCRIPTION: reset the variables that change each round. For example, reset [CanMoveRightBool] so the previous round won't affect this one
;	NOTE: THIS FUNCTION SUIT EVERY ROUND
proc SetupRound
	;Movement - RESET BECAUSE CHANGE EACH ROUND
	mov [CanMoveRightBool], 0
	mov [CanMoveLeftBool], 0
	mov [CanMoveDownBool], 0
	mov [CanRotatePieceBool], 0

	ret
endp SetupRound

;	DESCRIPTION: reset the variables that are different in the first round and aren't affected by previous ones
;	Reset the rotation to '0'
;	Declare the x and y pos of the piece
;	NOTE: THIS FUNCTION ONLY SUIT THE FIRST ROUND OF THE PIECE
proc SetupFirstRound
	;Setup rotation (0)
	;Setup x and y pos (Cx = x pos, Dx = y pos)
	;X AND Y POS IN CUBE SIZE
	; NOTE: the x and y pos on the first part are in relative to the board's x and y pos
	mov [PieceFileName+1], '0';Initial rotation
	mov al, [PieceFileName];Al = name of piece
	cmp al, 'I'
	jz @@PieceI
	cmp al, 'O'
	jz @@PieceO
	cmp al, 'T'
	jz @@PieceT
	cmp al, 'S'
	jz @@PieceS
	cmp al, 'Z'
	jz @@PieceZ
	cmp al, 'L'
	jz @@PieceL
	;cmp al, 'J'
	jmp @@PieceJ	
@@PieceI:
	mov cx, 4;X pos
	mov dx, -1;Y pos
	jmp @@Cont
@@PieceO:
	mov cx, 6;X pos
	mov dx, 0;Y pos
	jmp @@Cont
@@PieceT:
	mov cx, 5;X pos
	mov dx, 0;Y pos
	jmp @@Cont
@@PieceS:
	mov cx, 5;X pos
	mov dx, 0;Y pos
	jmp @@Cont
@@PieceZ:
	mov cx, 5;X pos
	mov dx, 0;Y pos
	jmp @@Cont
@@PieceL:
	mov cx, 5;X pos
	mov dx, 0;Y pos
	jmp @@Cont
@@PieceJ:
	mov cx, 5;X pos
	mov dx, -1;Y pos
	;jmp @@Cont
@@Cont:

	;DEBUG
	;add dx, 4
	
	
	;MULTIPLY THE X AND Y POS BY Cube_Size TO SUIT THE DIMENSIONS OF THE BOARD
		;Multiply x pos
	push dx;Save y pos
	xor dx, dx;Zero	
	mov ax, Cube_Size
	mul cx;Ax = x pos * Cube_Size
	add ax, Board_Left_X_Border;Ax = actual x pos
	mov [x], ax;x = x pos
	
		;Multiply y pos
	pop cx;Pop y pos
	xor dx, dx;Zero	
	mov ax, Cube_Size
	imul cx;Ax = y pos * Cube_Size
	add ax, Board_Up_Y_Border;Ax = actual y pos
	mov [y], ax;y = y pos
	
	;Setup other variables --> call SetupRound
	call SetupRound
	ret
endp SetupFirstRound

;	DESCRIPTION: setup x and y of blank piece (preX and preY)
proc SetupBlankPiece
	
	;CURRENT x and y pos move to previous x and y pos
		;X pos
	mov ax, [x];Current piece's x pos
	mov [preX], ax;Previous piece's move's x pos
	
		;Y pos
	mov ax, [y];Current piece's y pos
	mov [preY], ax;Previous piece's move's y pos
	ret
endp SetupBlankPiece

;	DESCRIPTION: check which key was pressed and calls the suit function
;	Control movement of piece: move left, right, down and rotate
proc GameKeys
	push ax
	
	;Check which key was pressed
	xor ah, ah;Zero
	int 16h
	
	;mov ah, 39h
	
	cmp ah, 4Dh;Right Arrow
	jz @@CheckMoveRightL
	cmp ah, 4Bh;Left Arrow
	jz @@CheckMoveLeftL
	cmp ah, 50h;Down arrow
	jz @@CheckMoveDownL	
	cmp ah, 39h;SpaceBar
	jz @@CheckRotateL
		;If other key was pressed --> go to @@EndFunc
	jmp @@JumpToEndFuncL
	
	;If right key was pressed: Check if can move piece right. If can --> move piece right, If can't --> don't move piece right
@@CheckMoveRightL:
	;Check if can move piece right
	call CheckMoveRight
	mov al, [CanMoveRightBool]
	cmp al, 1;If al = 1 --> piece can move, If al = 0 --> piece can't move
	jnz @@JumpToEndFuncL;If can't move piece --> go to @@EndFunc
	;If can move piece
		;Hide piece
	call SetupBlankPiece
	call DrawBlankPiece
		;Move piece
	call MoveRightPiece
		;Draw piece
	call DrawPiece
		;Reset bool
	mov [CanMoveRightBool], 0
	jmp @@JumpToEndFuncL
	;Because relative jump is too big --> jmp to here and then from here jump to @@EndProc
;--->
@@JumpToEndFuncL:
	jmp @@EndFunc
;--->
	;Because relative jump is too big --> jmp to here and then from here jump to @@EndGame
;--->
@@JumpToEndGameL:
	jmp @@EndGame
;--->

	
@@CheckMoveLeftL:
	;Check if can move piece left
	call CheckMoveLeft
	mov al, [CanMoveLeftBool]
	cmp al, 1;If al = 1 --> piece can move, If al = 0 --> piece can't move
	jnz @@JumpToEndFuncL;If can't move piece --> go to @@EndFunc
	;If can move piece
		;Hide piece
	call SetupBlankPiece
	call DrawBlankPiece
		;Move piece
	call MoveLeftPiece
		;Draw piece
	call DrawPiece
		;Reset bool
	mov [CanMoveLeftBool], 0
	jmp @@JumpToEndFuncL
	
@@CheckMoveDownL:
	;Check if can move piece down
	call CheckMoveDown
	mov al, [CanMoveDownBool]
	cmp al, 1;If al = 1 --> piece can move, If al = 0 --> piece can't move
	jnz @@JumpToEndFuncL;If can't move piece --> go to @@EndFunc
	;If can move piece
		;Hide piece
	call SetupBlankPiece
	call DrawBlankPiece
		;Move piece
	call MoveDownPiece
		;Draw piece
	call DrawPiece
		;Reset bool
	mov [CanMoveDownBool], 0
	jmp @@JumpToEndFuncL
	
@@CheckRotateL:
		;Hide piece
		;If piece is O - no need to check rotation...
	mov ah, [FileName]
	cmp ah, 'O'
	jz @@EndGame
	call SetupBlankPiece
	call DrawBlankPiece
	;Check which rotation next
	call ReturnWhichRotateNext;Al = ASCII number of wanted rotation
	;Check if can rotate piece
	call CheckRotatePiece
	mov ah, [CanRotatePieceBool]
	cmp ah, 1;If ah = 1 --> piece can rotate, If ah = 0 --> piece can't rotate
	jnz @@DrawPieceRotation;If can't rotate piece --> go to @@DrawPieceRotation
	;If can rotate piece
		;Rotate piece
	call RotatePiece
		;Draw piece
@@DrawPieceRotation:
	call DrawPiece
		;Reset bool
	mov [CanRotatePieceBool], 0
	jmp @@JumpToEndFuncL
@@EndGame:	
@@EndFunc:
	pop ax
	ret
endp GameKeys

;	DESCRIPTION: Setup the data and values of the piece
;	INPUT: al = Name of piece (by letter, I,O,T,L,J,S,Z), ah = ASCII number of rotation
proc SetupPiece
	;Insert name and rotation of piece to PieceFileName
	mov [PieceFileName], al;Name of piece
	mov [PieceFileName+1], ah;Position of piece
	cmp al, 'I'
	jz @@I
	cmp al, 'O'
	jz @@O
	cmp al, 'T'
	jz @@T
	cmp al, 'S'
	jz @@S
	cmp al, 'Z'
	jz @@Z
	cmp al, 'L'
	jz @@L
	;cmp al, 'J'
	jmp @@J
@@I:
	mov [BmpRowSize], 28
	mov [BmpColSize], 28
	jmp @@EndFunc

@@O:
	mov [BmpRowSize], 14
	mov [BmpColSize], 14
	jmp @@EndFunc

@@T:
	mov [BmpRowSize], 21
	mov [BmpColSize], 21
	jmp @@EndFunc

@@S:
	mov [BmpRowSize], 21
	mov [BmpColSize], 21
	jmp @@EndFunc

@@Z:
	mov [BmpRowSize], 21
	mov [BmpColSize], 21
	jmp @@EndFunc

@@L:
	mov [BmpRowSize], 21
	mov [BmpColSize], 21
	jmp @@EndFunc
	
@@J:
	mov [BmpRowSize], 21
	mov [BmpColSize], 21
	;jmp @@EndFunc

@@EndFunc:
	ret
endp SetupPiece

;	DESCRIPTION: Returns the name of the next piece to spawn
;	Works with the "7 Bag" function (similiar to the "Fisher Yates" function)
;	OUTPUT: al = name of next piece
proc GetNextPiece
	push bx
	push cx
	;Check if array's pointer is 0 (Random not working...)
	mov al, [RandomPieceArrayPointer];al = pointer
	cmp al, 0;If out of bounds --> put 6 in var. Else --> continue
	jnz @@Cont
		;If pointer is 0
	mov al, [RandomPieceArray];al = random piece
	mov [RandomPieceArrayPointer], 6;Reset
	jmp @@EndFunc
	
@@Cont:
	;Get random place in array
	mov bl, 0;Min place
	mov bh, [RandomPieceArrayPointer];Max place
	call RandomByCs;Al = random place
		;SWITCH PLACES between the random piece and the piece in place [RandomPieceArrayPointer]
	xor bh, bh;Zero
	mov bl, [RandomPieceArrayPointer];bx = pointer
	xor si, si;Zero
	xor ah, ah;Zero
	mov si, ax;si = place of random piece
	mov cl, [RandomPieceArray+si];cl = piece in random place
	mov ch, [RandomPieceArray+bx];ch = piece in place [RandomPieceArrayPointer]
	mov [RandomPieceArray+si], ch;Put piece in pointer in place of random piece
	mov [RandomPieceArray+bx], cl;Put random piece in place of pointer
	;Decrease pointer
	dec bl
	mov [RandomPieceArrayPointer], bl
	mov al, cl;al = random piece
@@EndFunc:
	pop cx
	pop bx
	ret
endp GetNextPiece

;	DESCRIPTION: checks if can generate current piece (check if can move down from one place up)
;	*WORKS ONLY ON FIRST ROUND (WHEN PIECE NEED TO BE GENERATED)
;	OUTPUT: al = 0 --> piece CAN NOT generate, al = 1 --> piece CAN generate
proc CanPieceGenerate
	push bx
;	sub [y], Cube_Size
	mov ax, [y]
	sub ax, Cube_Size
	mov [y], ax
	
	;Check if can move piece down
	call CheckMoveDown
	mov al, 1;Piece can move down
	mov ah, [CanMoveDownBool]
	cmp ah, 1;If ah = 1 --> piece can move, If ah = 0 --> piece can't move
	jz @@EndProc;If can move piece --> go to @@EndFunc
	
	;If can't move piece down
	mov al, 0;Piece can't move down
@@EndProc:
;	add [y], Cube_Size
	mov bx, [y]
	add bx, Cube_Size
	mov [y], bx
	pop bx
	ret
endp CanPieceGenerate

;	DESCRIPTION: Updates [DelayTime] which indicates how many times should the delay loop run in a round.
;	*UPDATES [DelayTime]*
;	Delay time chart (per level):
;━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;│ Level 0-15: Delay = 48 - (level*3)	│
;│ Level 16+: Delay = 1					│
;━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
proc UpdateDelayTime
	push ax
	push bx
	
	mov al, [CurrentLevel];al = current level
	cmp al, 16;If level 16+
	jae @@LevelSixteenPlus
;	Level under 16
	xor ah, ah;Ax = level
	mov bl, 3
	mul bl;Ax = [CurrentLevel] * 3
	mov bl, 48;bl = 48
	xor bh, bh;Bx = 48
	sub bx, ax;bl = delay time (48 - (level*3))
	jmp @@EndProc
	
;	Level above/equal 20
@@LevelSixteenPlus:
	mov bl, 1;bl = delay time (1)
	
@@EndProc:
	mov [DelayTime], bl;[DelayTime] = delay time
	pop bx
	pop ax
	ret
endp UpdateDelayTime
; __             __         
;|  \ _| _|_ _  |__)_     _ 
;|__/(-|(-|_(-  | \(_)\)/_) 

;	DESCRIPTION: Draws a black cube in (cx,dx)
;	INPUT: Ax = width, Cx = x pos, Dx = y pos
proc DrawDeleteCube
	push bp
	push bx
	push di
	push ax
	
	;Calculate di
	mov ax, 320
	mul dx;Ax = 320*y pos
	add ax, cx;Ax = starting byte position in screen
	mov di, ax;Di = starting byte position in screen
	
	mov cx, Cube_Size;Cx = length
	pop dx;Dx = width
	mov [matrix], offset BlankSingleCubeMatrix
	call putMatrixInScreen
	
	pop di
	pop bx
	pop bp
	ret
endp DrawDeleteCube

;	DESCRIPTION: Returns if the row of the (INPUT) number is full
;	CALLS UpdateLines TO UPDATE [DeleteRowsTotalCounter].
;	INPUT: ax = number of row (0 <-> Board_Length_By_Cube - 1)
;	OUTPUT: al = 1 --> Row is full. If al = 0 --> Row is not full.
proc IsRowFull
	push bp
	push bx
	push cx
	push dx
	
	;Get the y of row
	mov bl, Cube_Size
	mul bl;Ax = number of row * Cube_Size
	add ax, Board_Up_Y_Border
	inc ax;Ax = y pos of row
	mov dx, ax;Dx = y pos of row
	
	mov bx, Board_Left_X_Border;Bx = left x pos
	mov cx, Board_Width_By_Cube;Cx = amount of pixels to check (each pixel = each cube in width)
@@CheckCube:
	push cx;save
	
	mov cx, bx;Cx = x pos
	call ReadColor
	;Al = color of pixel
	cmp al, 0;If al = 0 --> pixel's color is black and row IS NOT full
	je @@IfRowIsNotFull;If row is not full
	add bx, Cube_Size;move to next cube
	
	pop cx;restore
	loop @@CheckCube

	;If row is full
	mov al, 1
	jmp @@EndProc
	
@@IfRowIsNotFull:
	pop cx;Pop so stack will be correct at the end of procedure
	mov al, 0
	jmp @@EndProc
	
@@EndProc:	
	pop dx
	pop cx
	pop bx
	pop bp
	ret
endp IsRowFull

;	DESCRIPTION: Checks every row in the board and updates [DeleteRowsCounter].
;	UPDATES [DeleteRowsArray]
;	*CALLS TO UpdateScore*
proc CheckEveryRow
	push ax
	push bx
	
	xor bx, bx;Bx = counter of rows to delete
	mov cx, 20;For every row
@@CheckRow:
	push cx
	
	mov ax, cx
	dec ax;Ax = number of row
	push ax;Number of row
	
	call IsRowFull
	
	pop dx;Dx = number of row
	
	;If row is full, DO NOT CONTINUE
	cmp al, 1
	jnz @@AfterCheckRow
	
	;If row is full
	mov [DeleteRowsArray+bx], dl;Put number of row in array
	inc bx;Increase number of rows to delete
	
@@AfterCheckRow:	
	pop cx
	loop @@CheckRow
	
	mov [DeleteRowsCounter], bl;Put in [DeleteRowsCounter] the number of rows to delete
	
	;Update score
	mov al, bl;Al = number of delete rows
	call UpdateScore;Update score
	;Update total number of deleted rows
	call UpdateLines;Add [DeleteRowsCounter] to [DeleteRowsTotalCounter]
	
	pop ax
	pop bx
	ret
endp CheckEveryRow

;	DESCRIPTION: Deletes the row by putting black cubes covering the row - each phase represents two black cubes, one from each side.
;	Allocates space in stack for 3 LOCAL VARIABLES. bool - points if now positive or negative phase, and both positive and negative x pos keeper.
;	Can delete between 1-4 rows.
;	INPUT: [DeleteRowsCounter] = Number of rows to delete.
;		   [DeleteRowsArray] = Numbers of rows to delete.
;
proc DeleteRowAnimation
	push bp
	mov bp, sp
	sub sp, 2;Allocate space for three variable
	;[BP] = x pos | BP-2 = width of matrix
	push ax
	push bx
	push cx
	push dx


;	Setup x pos and width
;	Setup x pos
	mov cx, Board_Left_X_Border
	add cx, 42;Cx = x pos
	mov [bp], cx
;	Setup width
	xor ax, ax
	mov al, Cube_Size
	mov [bp-2], ax
	
	
	mov cx, 7;Number of phases of the row animation.
@@StartRowPhase:
	push cx
;	For each row
@@PreEachRow:
	xor cx, cx;Zero
	mov cl, [DeleteRowsCounter];Cx = number of rows to delete.
@@ForEachRow:
	push cx;Save
	
	;Get y pos of row
	mov bx, cx;Bx = current number of row
	dec bx;Bx = offset of current row
	xor ax, ax;Zero
	mov al, [DeleteRowsArray+bx];Al = current number of row
	mov bl, Cube_Size
	mul bl;Ax = y pos of current row in board
	add ax, Board_Up_Y_Border
	inc ax;Ax = y pos of current row
	mov dx, ax;Dx = y pos of current row
	
	;Get x pos
	mov cx, [bp]
	;Get width
	mov ax, [bp-2]
	
@@DrawCube:
	call DrawDeleteCube

	;Delay
	mov cx, 100
@@DelayLoopMidAnimation:
	call DelayMilisec
	loop @@DelayLoopMidAnimation
	
	pop cx;Restore
	loop @@ForEachRow
	
	;After finishing phase, update x pos and width
	;x pos
	mov ax, [bp]
	sub ax, 7
	mov [bp], ax
	;width
	mov ax, Cube_Size
	shl ax, 1
	add [bp-2], ax
	
@@EndCurrentPhase:	
	;After finishing current phase of every row, start new phase
	pop cx;Restore
	loop @@StartRowPhase
	
@@EndProc:	
	pop dx
	pop cx
	pop bx
	pop ax
	add sp, 2
	pop bp
	
	ret
endp DeleteRowAnimation


;	DESCRIPTION: Lower the rows by copying them down from the top of the screen to the deleted row - The length is 1/2/3/4 rows. USING fast copy (movsb)
;	INPUT: Ax = Number of deleted rows, [DeleteRowsArray] = Number of row to copy to
proc DrawLowerRows	
	push bp
	sub sp, 2;Allocate space for 2 variables
	mov bp, sp
	;[bp] = Original pixel to copy to (deleted row)| [bp-2] Original pixel to copy from (above deleted row)
	push bx
	push cx
	push dx
	push ax;Save
	
	;Get deleted row left-lower y pos
	;Get number of row
	xor bx, bx;Zero
	mov al, [DeleteRowsArray];Al = number of row

	;Calculate pos of original pixel to copy to
	xor dx, dx;Zero
	xor ah, ah;Zero
	mov bl, Cube_Size
	mul bl;Ax = number of row * Cube_Size
	mov bx, 320
	mul bx;Ax = y pos of the pixel without the border	
	add ax, 10560;Ax = pixel's number of the row | 10560 = Board_Up_Y_Border * 320
	add ax, 2240;Ax = lower pixel of the cube's y pos (previous pixel + 6*320 + 320 [Piece is printed one row lower...])
	add ax, Board_Left_X_Border;Ax = left-lower pos = original pixel to copy to
	
	mov [bp], ax;[bp] = original pixel to copy to
	
	;Calculate pos of original pixel to copy from
	pop ax;restore	
	mov bl, Cube_Size
	mul bl;Ax = length in pixels between the original pixel to copy from, to the original pixel to copy to	
	xor dx, dx;Zero
	mov bx, 320
	mul bx;Ax = length (pixel) between the pixel to copy to from the pixel to copy from	
	mov bx, [bp];Bx = pos of pixel to copy to
	sub bx, ax;Bx = pos of pixel to copy from
	mov [bp-2], bx;[bp-2] = original pixel to copy from

	;Loop for every length's pixel - Number of deleted row is the number of rows to copy --> multiply by 7 (Cube_Size)
	xor ax, ax;Zero
	mov al, [DeleteRowsArray];Al = number of row	
	inc al
	sub al, [DeleteRowsCounter];Al = number of rows to copy
	mov bl, Cube_Size
	mul bl;Ax = number of pixels rows to copy
	mov cx, ax;Cx = number of pixels rows to copy
@@ForEveryRow:
	push cx

	;Calculate board width
	xor ax, ax;Zero
	mov al, Board_Width_By_Cube
	mov bl, Cube_Size
	mul bl;Ax = Board_Width_By_Cube * Cube_Size = Number of pixels in a row
	mov cx, ax;Cx = Number of pixels in a row
	
@@CopySingleRow:
	;Fast Copy - from pixel to copy from to pixel to copy to. If row ended --> go one row upper (Both pos - 320)
	mov ax, 0A000h
	mov es, ax;Es = 0A000h
	push ds;Save DS
	mov ds, ax;DS = 0A000h
	mov si, [bp-2];Si = pixel to copy from
	mov di, [bp];Di = pixel to copy to
	cld;Copy rightway
	rep movsb;Cx = number of pixels to copy (whole inboard row)
	pop ds;Restore ds
	
		;DEBUG
;--->
	;mov [byte ptr es:si], 255
	;mov [byte ptr es:di], 50
@@Freeze:
	;mov cx, 10
@@TempDebugDelay:
	;call DelayMilisec
	;loop @@TempDebugDelay
;--->

	;Update pos
	;lower pos of pixel
	mov ax, [bp]
	sub ax, 320
	mov [bp], ax
	
	;lower pos of pixel
	mov ax, [bp-2]
	sub ax, 320
	mov [bp-2], ax
	
	pop cx
	loop @@ForEveryRow
	
	
	pop dx
	pop cx
	pop bx
	add sp, 2;Restore space
	pop bp
	ret
endp DrawLowerRows

;	DESCRIPTION: Management of the row's lowering. Calls DrawLowerRows
proc LowerRows
	push bp
	push ax
	push bx
	push cx
	push dx

@@CheckLength:

	;Calculate width
	xor cl, cl;Cl = zero (counter of rows to delete)
	mov al, [DeleteRowsCounter];Al = number of rows to delete
	cmp al, 1;If single row to delete --> length is 1
	jz @@LengthIs1
	cmp al, 4;Is 4 rows to delete --> length is 4
	jz @@LengthIs4
	cmp al, 2
	jz @@CheckIf2RowsToDelete
	;cmp al, 3 (for sure until here al = 3...)
	jmp @@CheckIf3RowsToDelete
	
@@CheckIf2RowsToDelete:
	mov al, [DeleteRowsArray]
	mov ah, [DeleteRowsArray+1]
	sub al, ah
	cmp al, 1;If al is 1 --> rows are paired (length is 2), otherwise length is 1
	jz @@LengthIs2
	;Otherwise...
	jmp @@LengthIs1
@@CheckIf3RowsToDelete:
	mov al, [DeleteRowsArray]
	mov ah, [DeleteRowsArray+1]
	sub al, ah
	cmp al, 1;If al is not 1 --> rows are not paired (length is 1), otherwise length is 2/3
	jnz @@LengthIs1
	mov al, [DeleteRowsArray+1]
	mov ah, [DeleteRowsArray+2]
	sub al, ah
	cmp al, 1;If al is not 1 --> rows are not paired (length is 2), otherwise length is 3
	jnz @@LengthIs2
	jmp @@LengthIs3;If got until here --> Length is 3

;	[DeleteRowsArray] = number of lowest row
@@LengthIs1:
	mov ax, 1
	jmp @@CallToDrawLowerRows
@@LengthIs2:
	mov ax, 2
	jmp @@CallToDrawLowerRows
@@LengthIs3:
	mov ax, 3
	jmp @@CallToDrawLowerRows
@@LengthIs4:
	mov ax, 4
	;jmp @@CallToDrawLowerRows
	
@@CallToDrawLowerRows:
	push ax;Ax = number of rows to delete
	
	;Draw lower rows
	call DrawLowerRows
	
	;Check if need to lower more rows
	pop ax;Ax = number of rows THAT WERE DELETED
	;Check if there are rows to lower that were not lower (Number of rows to lower - rows lowered = number of rows left to lower)
	mov bx, ax;Save (bx [bl]) = number of rows that WERE DELETED
	mov ah, [DeleteRowsCounter];Ah = number of rows to delete
	sub ah, al;Ah = number of rows left to delete
	cmp ah, 0;If ah = 0 --> no need to lower more rows
	jz @@AfterTotalLower
	
	;If need to lower more rows
	;The number of row to copy to (used for the DeleteRows procedure) is: [DeleteRowsArray+NumberOfDeletedRows]
	mov al, [DeleteRowsArray+bx];Al = number of row to delete NOW	
	add al, bl;Al = number of NEW row to delete NOW
	mov [DeleteRowsArray], al;[DeleteRowsArray] = number of row to delete NOW
	mov bh, [DeleteRowsCounter];Bh = TOTAL Number of rows to delete
	sub bh, bl;Bl = number of rows to delete NOW
	mov bl, bh
	xor bh, bh;Bx = number of rows to delete NOW
	mov ax, bx;Ax = number of rows to delete NOW

	;Draw lower rows
	call DrawLowerRows	
@@AfterTotalLower:
	;Check how many rows left to delete
	call CheckEveryRow
	;Check if there are more rows to delete, if there are --> call to draw lower rows
	mov al, [DeleteRowsCounter]
	cmp al, 0
	jz @@FinishProc
	;If more rows to lower
	jmp @@CheckLength

@@FinishProc:
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret
endp LowerRows
;---


;  __ ___  __  ___ _  _ _  ___  __  
; / _] _ \/  \| _,\ || | |/ _//' _/ 
;| [/\ v / /\ | v_/ >< | | \__`._`. 
; \__/_|_\_||_|_| |_||_|_|\__/|___/ 


;           __  
;|__| |  | |  \ 
;|  | \__/ |__/ 

proc PrintHUD
	;Print statistics
	call PrintStatistics
	;Print lines
	call PrintLines
	;Print score
	call PrintScore
	;Print next piece
	call PrintNextPiece
	;Print level
	call PrintLevel
	ret
endp PrintHUD

;	DESCRIPTION: Draw wanted digit in wanted position (With background! [navy blue])
;	BmpLeft = x, BmpTop = y (x,y)		
proc DrawSingleDigit
	;Get piece file name
	mov dx, offset SingleDigitFileName
	call OpenShowBmp
	ret
endp DrawSingleDigit

;	DESCRIPTION: Prints statistics (number of times each piece was used) in the left part of the screen. Print third digit, than second, than first (right to left)
proc PrintStatistics
	push ax
	push bx
	push cx
	push dx
	
	;Digits' length and width
	mov [BmpColSize], 7
	mov [BmpRowSize], 7
	
	;Digits' color
	mov [SingleDigitFileName+2], 'R';move color RED to [SingleDigitFileName+2]
	
	;x pos = 85 (pos of third digit)
	;y START (top piece stats) = 59 (each time next piece [piece lower] is previous y pos + 16)
	mov cx, 7;For each piece
	mov ax, 59;Ax = 59 (start y pos)
	
@@ForEachPiece:
	push cx;Save	
	mov [BmpTop], ax;y pos
	mov [BmpLeft], 85;x pos
	push ax;Save y pos
	mov dx, ax;dx = y pos
	
	;Get stats
	mov ax, cx;Ax = number of piece
	mov bx, 7;bx = Number of pieces
	sub bl, al;bx = Offset of current piece / 2
	shl bx, 1;Bx = offset of current piece
	mov ax, [TimeEachPieceWasUsed+bx];Al = current stats
	
	mov bx, [BmpLeft];bx = x pos
	mov cx, 3;For each digit
@@ForEachDigit:
	push cx;Save
	
	push dx;Save y pos
	
	;Get current digit
	xor dx, dx;Zero
	xor ch, ch;Zero
	mov cl, 10;Cx (Cl) = 10
	div cx;Ax = number without digit, Dx (Dl) = digit
	add dl, 30h;Turn value to ASCII
	mov [SingleDigitFileName+1], dl;[SingleDigitFileName+1] = Number of digit	
	
	;Get pos
	pop dx;Restore y pos
	mov [BmpLeft], bx;[BmpLeft] = x pos
	mov [BmpTop], dx;[BmpTop] = y pos
	
	push ax;Save Number
	
	;Print number
	call DrawSingleDigit;print digit

	pop ax;Restore numbers
	mov dx, [BmpTop];y pos
	mov bx, [BmpLeft];bx = x pos
	sub bx, 8;Bx = new x pos (more left than current pos = one digit left)
	
	pop Cx;Restore
	loop @@ForEachDigit

	;After print STATS OF WHOLE PIECE
	pop ax;Restore y pos
	add al, 16;Ax = new y pos
	pop cx;Restore
	loop @@ForEachPiece
	
	pop dx
	pop cx
	pop bx
	pop ax
	ret
endp PrintStatistics

;	DESCRIPTION: Updates statistics (number of times each piece was used) for a spesific piece. UPDATES [TimeEachPieceWasUsed].
;	INPUT: al = name of piece to increase stats
proc UpdateStatistics
;	Order of array [TimeEachPieceWasUsed] is: T, J, Z, O, S, L, I
@@IfT:
	cmp al, 'T'
	jnz @@IfJ
	inc [TimeEachPieceWasUsed];Increase stats of T
	jmp @@EndProc
@@IfJ:
	cmp al, 'J'
	jnz @@IfZ
	inc [TimeEachPieceWasUsed+2];Increase stats of J
	jmp @@EndProc
@@IfZ:
	cmp al, 'Z'
	jnz @@IfO
	inc [TimeEachPieceWasUsed+4];Increase stats of Z
	jmp @@EndProc
@@IfO:
	cmp al, 'O'
	jnz @@IfS
	inc [TimeEachPieceWasUsed+6];Increase stats of O
	jmp @@EndProc
@@IfS:
	cmp al, 'S'
	jnz @@IfL
	inc [TimeEachPieceWasUsed+8];Increase stats of S
	jmp @@EndProc
@@IfL:
	cmp al, 'L'
	jnz @@IfI
	inc [TimeEachPieceWasUsed+10];Increase stats of L
	jmp @@EndProc
@@IfI:
	inc [TimeEachPieceWasUsed+12];Increase stats of I
	;jmp @@EndProc
@@EndProc:
	ret
endp UpdateStatistics

;	DESCRIPTION: Prints lines (number of total cleared lines) in the top part of the screen. Print third digit, than second, than first (right to left)
proc PrintLines
	push ax
	push bx
	push cx
	push dx
	
	;Digits' length and width
	mov [BmpColSize], 7
	mov [BmpRowSize], 7
	
	;Digits' color
	mov [SingleDigitFileName+2], 'W';move color WHITE to [SingleDigitFileName+2]
	
	;x pos = 198 (pos of third digit)
	;y START = 10 (stable, doesn't change)
	mov [BmpTop], 10;y pos
	mov [BmpLeft], 198;x pos
	
	;Get stats
	mov ax, [DeleteRowsTotalCounter];Ax = TOTAL number of cleared lines
	
	mov bx, [BmpLeft];bx = x pos
	mov cx, 3;For each digit
@@ForEachDigit:
	push cx;Save
	
	;Get current digit
	xor dx, dx;Zero
	xor ch, ch;Zero
	mov cl, 10;Cx (Cl) = 10
	div cx;Ax = number without digit, Dx (Dl) = digit
	add dl, 30h;Turn value to ASCII
	mov [SingleDigitFileName+1], dl;[SingleDigitFileName+1] = Number of digit	
	
	;Get pos
	mov [BmpLeft], bx;[BmpLeft] = x pos
	
	push ax;Save Number
	
	;Print number
	call DrawSingleDigit;print digit

	pop ax;Restore numbers
	mov bx, [BmpLeft];bx = x pos
	sub bx, 9;Bx = new x pos (more left than current pos = one digit left)
	
	pop Cx;Restore
	loop @@ForEachDigit
	
	pop dx
	pop cx
	pop bx
	pop ax
	ret
endp PrintLines

;	DESCRIPTION: Updates lines (number of total cleared lines). UPDATES [DeleteRowsTotalCounter].
;	INPUT: [DeleteRowsCounter] = addition to [DeleteRowsTotalCounter]
proc UpdateLines
	push ax
	push bx
	
	xor ah, ah;Zero
	mov al, [DeleteRowsCounter];Ax = addition to [DeleteRowsTotalCounter]
	mov bx, [DeleteRowsTotalCounter];Bx = [DeleteRowsTotalCounter]
	add bx, ax;Bx = total number of deleted rows
	mov [DeleteRowsTotalCounter], bx;[DeleteRowsTotalCounter] = total number of deleted rows
	
	pop bx
	pop ax
	ret
endp UpdateLines

;	DESCRIPTION: Prints score (current score) in the right part of the screen. Print sixsth digit, than fifth... than first (right to left)
proc PrintScore
	push ax
	push bx
	push cx
	push dx
	
	;Digits' length and width
	mov [BmpColSize], 7
	mov [BmpRowSize], 7
	
	;Digits' color
	mov [SingleDigitFileName+2], 'W';move color WHITE to [SingleDigitFileName+2]
	
	;Print rest of digits
	;x pos = 262 (pos of sixth digit)
	;y START = 50 (stable, doesn't change)
	mov [BmpLeft], 262;x pos	
	mov [BmpTop], 50;y pos
	
	;Get stats
	mov ax, [CurrentScore+2];Ax = Current score without first and second digits
	
	mov bx, [BmpLeft];bx = x pos
	mov cx, 6;For each digit
@@ForEachDigit:
	push cx;Save
	
	;Check if now 2 left digits
	;If cx = 2 --> already done 4 digits. Now print 2 left digits which are in [CurrentScore] second's byte
	cmp cx, 2
	jnz @@AfterGettingNumber
	;If cx = 2 --> move to ax the new number (2 left digits)
	mov ax, [CurrentScore];Ax = 2 left digits
	
@@AfterGettingNumber:
	;Get current digit
	xor dx, dx;Zero
	xor ch, ch;Zero
	mov cl, 10;Cx (Cl) = 10
	div cx;Ax = number without digit, Dx (Dl) = digit
	add dl, 30h;Turn value to ASCII
	mov [SingleDigitFileName+1], dl;[SingleDigitFileName+1] = Number of digit	
	
	;Get pos
	mov [BmpLeft], bx;[BmpLeft] = x pos
	
	push ax;Save Number
	
	;Print number
	call DrawSingleDigit;print digit

	pop ax;Restore numbers
	mov bx, [BmpLeft];bx = x pos
	sub bx, 8;Bx = new x pos (more left than current pos = one digit left)
	
	pop Cx;Restore
	loop @@ForEachDigit
	
	pop dx
	pop cx
	pop bx
	pop ax
	ret
endp PrintScore

;	DESCRIPTION: Updates score (current score). UPDATES [CurrentScore].
;	INPUT: al = number of cleared lines
proc UpdateScore
	push bx
	push cx
	push dx
	
	xor ah, ah;Zero
	;Check how many lines deleted
	cmp al, 0
	jz @@EndProc
	cmp al, 1
	jz @@Single
	cmp al, 2
	jz @@Double
	cmp al, 3
	jz @@Triple
	;al = 4
	jmp @@Tetris
@@Single:;1 line
	mov al, 40
	jmp @@MulByLevel
@@Double:;2 lines
	mov al, 100
	jmp @@MulByLevel
@@Triple:; 3 lines
	mov ax, 300
	jmp @@MulByLevel
@@Tetris:;4 lines
	mov ax, 1200
;	jmp @@MulByLevel
;	Mul ax by level
@@MulByLevel:
	mov bl, [CurrentLevel];bl - current level
	xor bh, bh;Zero
	inc bl;Bx = current level + 1
	xor dx, dx;Zero
	mul bx;Dx:Ax = addition to score
	
	;Add left word addition [CurrentScore]
	mov cx, [CurrentScore]
	add cx, dx
	mov [CurrentScore], cx;Add current left and right digit score to left right digit score
	
	;Add right word addition [CurrentScore+2]
	mov cx, [currentscore+2]
	add cx, ax
	mov [currentscore+2], cx;Add current right digits' score to right digits' score
	
	;Check if need to increase 2 left digits
	cmp cx, 10000;If cx >= 10000 --> there was an addition so score needs to increase second [or also first] digit (EXAMPLE: 9987 + 40 --> 10027)
	jae @@NeedToIncCurrentScore;Need to increase current score 2 left digits
	jmp @@EndProc;No need to increase current score 2 left digits
	
@@NeedToIncCurrentScore: 
;	Increase 2 left digitss
	sub cx, 10000
	mov [currentscore+2], cx;right digits' score after subtraction
	mov cx, [CurrentScore]
	inc cx
	mov [CurrentScore], cx
@@EndProc:
	pop dx
	pop cx
	pop bx
	ret
endp UpdateScore

;	DESCRIPTION: Prints top score (start game's top score) in the right part of the screen. Print sixsth digit, than fifth... than first (right to left)
proc PrintTopScore
	push ax
	push bx
	push cx
	push dx
	
	;Digits' length and width
	mov [BmpColSize], 7
	mov [BmpRowSize], 7
	
	;Digits' color
	mov [SingleDigitFileName+2], 'W';move color WHITE to [SingleDigitFileName+2]
	
	;Print rest of digits
	;x pos = 262 (pos of sixth digit)
	;y START = 26 (stable, doesn't change)
	mov [BmpLeft], 262;x pos	
	mov [BmpTop], 26;y pos
	
	;Get stats
	mov ax, [TopScore+2];Ax = top score without first and second digits
	
	mov bx, [BmpLeft];bx = x pos
	mov cx, 6;For each digit
@@ForEachDigit:
	push cx;Save
	push bx;save x pos
@@AfterGettingNumber:
	;Get current digit
	mov bx, cx
	dec bl;bx = offset of current digit
	mov dl, [TopScoreBuffer+bx];dl = current digit (ASCII)
	mov [SingleDigitFileName+1], dl;[SingleDigitFileName+1] = Number of digit	
	
	;Get pos
	pop bx;restore x pos
	mov [BmpLeft], bx;[BmpLeft] = x pos
		
	;Print number
	call DrawSingleDigit;print digit

	mov bx, [BmpLeft];bx = x pos
	sub bx, 8;Bx = new x pos (more left than current pos = one digit left)
	
	pop Cx;Restore
	loop @@ForEachDigit
	
	pop dx
	pop cx
	pop bx
	pop ax
	ret
endp PrintTopScore

;	DESCRIPTION: Reads from TopSC.txt to [TopScoreBuffer] and converts to [TopScore]
proc GetTopScore
	push ax
	push bx
	push cx
	push dx
	
;	Open file
	xor al, al;Zero
	mov ah, 3Dh
	mov dx, offset TopScoreFileName;Dx = name of top score's file
	int 21h
	jc @@ErrorAtOpen
	mov [FileHandle], ax

;	Read file
	mov ah, 3Fh
	mov bx, [FileHandle];Bx = file handle
	mov cx, 6;Cx = number of bytes to read
	mov dx, offset TopScoreBuffer;Dx = offset of [TopScoreBuffer]
	int 21h
	jc @@ErrorAtOpen
	
;	Close file
	mov ah, 3Eh
	mov bx, [FileHandle];Bx = file handle
	int 21h
	jc @@ErrorAtOpen

;	Convert to double-word score
;	First: Get the value of the number (get left dig, lower by 30h to turn from ASCII to value, mul by 10 and repeat)

	;Get the value of the left word (2 left digits)
	xor ax, ax;Zero
	mov al, [TopScoreBuffer];Al = first digit ASCII
	sub al, 30h;Al = first digit
	mov bl, 10;bl = 10
	mul bl;Al = first digit*10
	mov bl, [TopScoreBuffer+1];bl = second digit ASCII
	sub bl, 30h;bl = second digit value
	add al, bl;al = 2 left digits value
	mov [TopScore], ax;[TopScore] = 2 left digits
	
	
	mov cx, 4;For each digit - from left to right
	xor dx, dx;Zero
	xor ax, ax;Zero
@@TurnDigToVal:
	push cx
	
	mov bx, 10;bx = 10
	mul bx;Ax (Dx:Ax) = current value	
	mov bx, 6
	sub bx, cx;Bx = current offset of digit
	mov cl, [TopScoreBuffer+bx];Cl = current digit ASCII
	sub cl, 30h;cl = current value of digit
	xor ch, ch;Cx = current value of digit
	add ax, cx;Ax = previous value plus value of current digit

	pop cx
	loop @@TurnDigToVal
	
	mov [TopScore+2], ax;[TopScore+2] = 4 right digits

@@EndProc:
	pop dx
	pop cx
	pop bx
	pop ax
	ret
@@ErrorAtOpen:
	mov [ErrorFile],1
	jmp @@EndProc
endp GetTopScore

;	DESCRIPTION: Updates top score. *UPDATES TopSC.txt
;	To check if current score is bigger than top score, we can comapare the first word of each (two left digits) and then the second (four right digits)
proc UpdateTopScore
	push ax
	push bx
	
	;Compare 2 left digits
	mov ax, [CurrentScore];Ax = 2 left digits of current score
	mov bx, [TopScore];Bx = 2 left digits of top score
	cmp bx, ax;check if top score bigger than current score
	ja @@EndProc;If top score bigger than current score
	jb @@TopScoreLowerThanCurrent;If top score lower than current score
	
	;Compare 4 right digits
	mov ax, [CurrentScore+2];Ax = 4 right digits of current score
	mov bx, [TopScore+2];Bx = 4 right digits of top score
	cmp bx, ax;check if top score bigger than current score
	jae @@EndProc;If top score bigger or equal than current score
	;jb @@TopScoreLowerThanCurrent;If top score lower than current score
	
@@TopScoreLowerThanCurrent:
	;NEW TOP SCORE --> Update TopSC.txt
	xor ax, ax;Zero
	mov ax, [CurrentScore+2];ax = 4 right digits
	;If cx = 2 --> work on the left word [right word is already done, 4 right digits completed --> now 2 left digitss]
	mov cx, 6
@@ForEachDigit:
	push cx;save
	;If now need to work on left word
	cmp cx, 2
	jne @@AxHasTheNumber
	;If need to work on left word
	mov ax, [CurrentScore];ax = left word of [TopScore]
	
@@AxHasTheNumber:
	xor dx, dx;Zero
	mov bx, 10
	div bx;dx = current digit, ax = rest of number
	add dl, 30h;dl = current ASCII digit
	pop cx;restore
	mov bx, cx
	dec bx;bx = current offset of digit
	mov [TopScoreBuffer+bx], dl;[TopScoreBuffer+bx] = current digit ASCII
	loop @@ForEachDigit	
	
	;After [TopScoreBuffer] is ready
	;Open file
	mov ah, 3Dh
	mov al, 1
	mov dx, offset TopScoreFileName;Dx = name of top score's file
	int 21h
	mov [FileHandle], ax
	;Write to file
	mov ah, 40h
	mov bx, [FileHandle];Bx = file handle
	mov cx, 6;Cx = number of bytes to write
	mov dx, offset TopScoreBuffer;Dx = offset of TopScoreBuffer
	int 21h
	;Close file
	mov ah, 3Eh
	mov bx, [FileHandle]
	int 21h
@@EndProc:
	pop bx
	pop ax
	ret
endp UpdateTopScore

;	DESCRIPTION: Prints level (current level) in the right part of the screen. Print second digit, than first (right to left)
;	*CALLS TO UpdateLevel*
proc PrintLevel
	push ax
	push bx
	push cx
	push dx
	
	;UpdateLevel
	call UpdateLevel
	
	;Digits' length and width
	mov [BmpColSize], 7
	mov [BmpRowSize], 7
	
	;Digits' color
	mov [SingleDigitFileName+2], 'W';move color WHITE to [SingleDigitFileName+2]
	
	;Print rest of digits
	;x pos = 246 (pos of second digit)
	;y START = 152 (stable, doesn't change)
	mov [BmpLeft], 246;x pos	
	mov [BmpTop], 152;y pos
	
	;Get stats
	mov al, [CurrentLevel];Ax = Current level
	
	mov bx, [BmpLeft];bx = x pos
	mov cx, 2;For each digit
@@ForEachDigit:
	push cx;Save
	
	;Get current digit
	xor ah, ah;Zero
	mov cl, 10;cl = 10
	div cl;Al = number without digit, Ah = digit
	mov dl, ah;Dl = digit
	add dl, 30h;Turn value to ASCII
	mov [SingleDigitFileName+1], dl;[SingleDigitFileName+1] = Number of digit	
	
	;Get pos
	mov [BmpLeft], bx;[BmpLeft] = x pos
	
	push ax;Save Number
	
	;Print number
	call DrawSingleDigit;print digit

	pop ax;Restore numbers
	mov bx, [BmpLeft];bx = x pos
	sub bx, 8;Bx = new x pos (more left than current pos = one digit left)
	
	pop Cx;Restore
	loop @@ForEachDigit
	
	pop dx
	pop cx
	pop bx
	pop ax
	ret
endp PrintLevel

;	DESCRIPTION: Updates level (current level). UPDATES [CurrentLevel]. level = NumberOfClearedLines / 10
proc UpdateLevel
	push ax
	push bx
	push dx

	mov ax, [DeleteRowsTotalCounter];Ax = total number of deleted rows
	xor bh, bh;Zero
	mov bl, 10;bl = 10
	xor dx, dx;Zero
	div bx;Al = level/10
	mov [CurrentLevel], al;[CurrentLevel] = level

	pop dx
	pop bx
	pop ax
	ret
endp UpdateLevel

;	DESCRIPTION: Prints next piece (from [NextPieceName]) in the right part of the screen.
proc PrintNextPiece
	push ax
	push dx
	
	;Big piece' length and width
	mov [BmpColSize], 33;widths
	mov [BmpRowSize], 15;length
	
	;Big piece' name
	mov al, [NextPieceName];al = name of next piece
	mov [BigPieceFileName+4], al;[BigPieceFileName+4] = name of next piece
	
	;Get pos
	mov [BmpLeft], 221;x pos = 221
	mov [BmpTop], 103;y pos = 103

	;Print big piece
	mov dx, offset BigPieceFileName
	call OpenShowBmp;print digit

	pop dx
	pop ax
	ret
endp PrintNextPiece

;	DESCRIPTION: Updates next piece (and current piece). UPDATES [NextPieceName] AND [PieceFileName].
proc UpdateNextPiece
	push ax
	
	;Get current pieces
	mov al, [NextPieceName];Previous next piece (current piece)
	mov [PieceFileName], al;[PieceFileName] = CURRENT piece
	
	;Get new pieces
	call GetNextPiece;al = FileName
	mov [NextPieceName], al;[NextPieceName] = name of NEXT piece

	pop ax
	ret
endp UpdateNextPiece

; in dx how many cols 
; in cx how many rows
; in matrix - the bytes
; in di start byte in screen (0 64000 -1)
proc putMatrixInScreen
	push es
	push ax
	push si
	
	mov ax, 0A000h
	mov es, ax
	cld
	
	push dx
	mov ax,cx
	mul dx
	mov bp,ax
	pop dx
	
	
	mov si,[matrix]
	
NextRow:	
	push cx
	
	mov cx, dx
	rep movsb ; Copy line to the screen
	sub di,dx
	add di, 320
	
	
	pop cx
	loop NextRow
	
	
endProc:	
	
	pop si
	pop ax
	pop es
    ret
endp putMatrixInScreen
; Open, show and close the image
; input dx filename to open
proc OpenShowBmp
	 
	call OpenBmpFile
	cmp [ErrorFile],1
	je @@ExitProc
	
	call ReadBmpHeader
	
	call ReadBmpPalette
	
	call CopyBmpPalette
	
	call  ShowBmp
	 
	call CloseBmpFile

@@ExitProc:
	ret
endp OpenShowBmp
; Open and show the image
; input dx filename to open
proc OpenBmpFile	near						 
	mov ah, 3Dh
	xor al, al
	int 21h
	jc @@ErrorAtOpen
	mov [FileHandle], ax
	jmp @@ExitProc
	
@@ErrorAtOpen:
	mov [ErrorFile],1
@@ExitProc:	
	ret
endp OpenBmpFile
; Read 54 bytes the Header
proc ReadBmpHeader	near					
	push cx
	push dx
	
	mov ah,3fh
	mov bx, [FileHandle]
	mov cx,54
	mov dx,offset Header
	int 21h
	
	pop dx
	pop cx
	ret
endp ReadBmpHeader
; Read BMP file color palette, 256 colors * 4 bytes (400h)
proc ReadBmpPalette near 
						 ; 4 bytes for each color BGR + null)			
	push cx
	push dx
	
	mov ah,3fh
	mov cx,400h
	mov dx,offset Palette
	int 21h
	
	pop dx
	pop cx
	
	ret
endp ReadBmpPalette
; Will move out to screen memory the colors
; video ports are 3C8h for number of first color
; and 3C9h for all rest
proc CopyBmpPalette		near					
										
	push cx
	push dx
	
	mov si,offset Palette
	mov cx,256
	mov dx,3C8h
	mov al,0  ; black first							
	out dx,al ;3C8h
	inc dx	  ;3C9h
CopyNextColor:
	mov al,[si+2] 		; Red				
	shr al,2 			; divide by 4 Max (cos max is 63 and we have here max 255 ) (loosing color resolution).				
	out dx,al 						
	mov al,[si+1] 		; Green.				
	shr al,2            
	out dx,al 							
	mov al,[si] 		; Blue.				
	shr al,2            
	out dx,al 							
	add si,4 			; Point to next color.  (4 bytes for each color BGR + null)				
								
	loop CopyNextColor
	
	pop dx
	pop cx
	
	ret
endp CopyBmpPalette
;	Show the picture
proc ShowBMP 
; BMP graphics are saved upside-down.
; Read the graphic line by line (BmpRowSize lines in VGA format),
; displaying the lines from bottom to top.
	push cx
	
	mov ax, 0A000h
	mov es, ax
	
	mov cx,[BmpRowSize]
	
 
	mov ax,[BmpColSize] ; row size must dived by 4 so if it less we must calculate the extra padding bytes
	xor dx,dx
	mov si,4
	div si
	cmp dx,0
	mov bp,0
	jz @@row_ok
	mov bp,4
	sub bp,dx

@@row_ok:	
	mov dx,[BmpLeft]
	
@@NextLine:
	push cx
	push dx
	
	mov di,cx  ; Current Row at the small bmp (each time -1)
	add di,[BmpTop] ; add the Y on entire screen
	
 
	; next 5 lines  di will be  = cx*320 + dx , point to the correct screen line
	mov cx,di
	shl cx,6
	shl di,8
	add di,cx
	add di,dx
	 
	; small Read one line
	mov ah,3fh
	mov cx,[BmpColSize]  
	add cx,bp  ; extra  bytes to each row must be divided by 4
	mov dx,offset ScrLine
	int 21h
	; Copy one line into video memory
	cld ; Clear direction flag, for movsb
	mov cx,[BmpColSize]  
	mov si,offset ScrLine
	rep movsb ; Copy line to the screen
	
	pop dx
	pop cx
	 
	loop @@NextLine
	
	pop cx
	ret
endp ShowBMP 

; Close the file
proc CloseBmpFile near
	mov ah,3Eh
	mov bx, [FileHandle]
	int 21h
	ret
endp CloseBmpFile

; Print the bmp without background (number under @@Copying)
proc ShowBmpTransperent
; BMP graphics are saved upside-down.
; Read the graphic line by line (BmpRowSize lines in VGA format),
; displaying the lines from bottom to top.
	push bp
	push ax
	push bx
	push cx
	push dx
	
	mov ax, 0A000h
	mov es, ax
	
	mov cx,[BmpRowSize]
	
 
	mov ax,[BmpColSize] ; row size must dived by 4 so if it less we must calculate the extra padding bytes
	xor dx,dx
	mov si,4
	div si
	cmp dx,0
	mov bp,0
	jz @@row_ok
	mov bp,4
	sub bp,dx

@@row_ok:	
	mov dx,[BmpLeft]
	
@@NextLine:
	push cx
	push dx
	
	mov di,cx  ; Current Row at the small bmp (each time -1)
	add di,[BmpTop] ; add the Y on entire screen
	
 
	; next 5 lines  di will be  = cx*320 + dx , point to the correct screen line
	mov cx,di
	shl cx,6
	shl di,8
	add di,cx
	add di,dx
	 
	; small Read one line
	mov ah,3fh
	mov cx,[BmpColSize]  
	add cx,bp  ; extra  bytes to each row must be divided by 4
	mov dx,offset ScrLine
	int 21h
	; Copy one line into video memory
	cld ; Clear direction flag, for movsb
	mov cx,[BmpColSize]  
	mov si,offset ScrLine

@@Copying:
	mov al, [PieceBackgroundColor]
	cmp [byte ds:si], al
	je @@Transperant
	jmp @@MovsbLabel
	
@@Transperant:
	inc si
	inc di
	jmp @@LoopLabel

@@MovsbLabel:
	movsb ; Copy line to the screen
		;mov [es:di], [ds:si]
		;inc si
		;inc di
@@LoopLabel:
	loop @@copying

	
	pop dx
	pop cx
	 
	loop @@NextLine
	
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret

endp ShowBmpTransperent


;	DESCRIPTION: draw a row of the color pallete in (0,0)
proc DrawPallete
	push bp
	push ax
	push bx
	push cx
	push dx
	
	;For each color
	mov cx, 255;For each color
	mov al, 0;Color
@@LoopRect:
	push cx;Save
	push ax;Save
	
	
	;Print pixel
	mov dx, 0;y pos
	xor ah, ah;Zero
	mov cx, ax;x pos
	mov bh, 0
	mov ah, 0Ch
	int 10h
	
	pop ax;Restore
	inc ax
	pop cx;Restore
	loop @@LoopRect
	
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret
endp DrawPallete

; Switch to graphic mode
proc SetGraphic
	mov ax,13h   ; 320 X 200 
				 ;Mode 13h is an IBM VGA BIOS mode. It is the specific standard 256-color mode 
	int 10h
	ret
endp 	SetGraphic
	;Switch to text mode
proc SetText
	mov ax, 2
	int 10h
	ret
endp SetText

;	DESCRIPTION: Draw board
proc DrawBoard
	;Scale
	mov [BmpColSize], 320
	mov [BmpRowSize], 200
	;Position
	mov [BmpTop], 0
	mov [BmpLeft], 0
	mov dx, offset BoardFileName
	call OpenShowBmp
	ret
endp DrawBoard

;	DESCRIPTION: Draw wanted piece in wanted position
;	BmpLeft = x, BmpTop = y (x,y)		
proc DrawPiece
	;Get piece file name
	mov dx, offset PieceFileName;Input for OpenShowBmp
	;Setup x
	mov ax, [x]
	mov [BmpLeft], ax
	;Setup y
	mov ax, [y]
	mov [BmpTop], ax
	call OpenBmpFile
	cmp [ErrorFile],1
	je @@ExitProc
	
	call ReadBmpHeader
	
	call ReadBmpPalette
	
	call CopyBmpPalette
	
	mov [PieceBackgroundColor], 1;background color = 255
	call  ShowBmpTransperent;Draw piece without background
	 
	call CloseBmpFile

@@ExitProc:
	ret
endp DrawPiece

;	DESCRIPTION: Draw wanted piece in blank (black) version - SEEMS like there is no piece in ([x],[y])
;	BmpLeft = x, BmpTop = y (x,y)		
proc DrawBlankPiece
	;Setup BlankPieceFileName
		;Copy name of piece
	mov al, [PieceFileName];Name of piece
	mov [BlankPieceFileName], al;Copy name to BlankPieceFileName
	
		;Copy rotation of piece
	mov al, [PieceFileName+1];Rotation of piece
	mov [BlankPieceFileName+1], al;Copy rotation to BlankPieceFileName
		
	;Get blank piece file name
	mov dx, offset BlankPieceFileName;Input for OpenShowBmp
	;Setup x
	mov ax, [preX]
	mov [BmpLeft], ax
	;Setup y
	mov ax, [preY]
	mov [BmpTop], ax
	call OpenBmpFile
	cmp [ErrorFile],1
	je @@ExitProc
	
	call ReadBmpHeader
	
	call ReadBmpPalette
	
	call CopyBmpPalette
	
	mov [PieceBackgroundColor], 1;background color = 255
	call  ShowBmpTransperent;Draw blank piece without background
	 
	call CloseBmpFile

@@ExitProc:
	ret
endp DrawBlankPiece

;	DESCRIPTION: Returns in al the color of the pixel
;	INPUT: cx = x, dx = y (x,y)
;	OUTPUT: al = color of pixel
;	*The color depending on the palette
;
;
;
proc ReadColor
	mov ah, 0Dh
	mov bh, 0
	
	;DrawPixel
	;push cx
	;push dx
	;DrawPixel
	
	;Cx = x, Dx = y
	int 10h
	;Al = color of pixel read
	
	;DrawPixel
	;pop dx
	;pop cx
	;mov bh, 0
	;push ax
	;mov ah, 0Ch
	;mov al, 57
	;int 10h
	;pop ax
	;DrawPixel

	ret
endp ReadColor
;---


; __ __  __   _   _  ___ __ __ ___ __  _ _____  
;|  V  |/__\ | \ / || __|  V  | __|  \| |_   _| 
;| \_/ | \/ |`\ V /'| _|| \_/ | _|| | ' | | |   
;|_| |_|\__/   \_/  |___|_| |_|___|_|\__| |_|   

;---
;	DESCRIPTION: Move right current piece
proc MoveRightPiece
	;Move right current piece one Cube_Size
	add [x], Cube_Size
	ret
endp MoveRightPiece

;	CHECK MOVE RIGHT
	;DESCRIPTION: Check if can move piece right. If [CanMoveRightBool] = 1 --> PIECE CAN MOVE RIGHT. If [CanMoveRightBool] = 0 --> PIECE CAN'T MOVE RIGHT  
	;	Only updates [CanMoveRightBool]
	;	Calls sub-procedure depends on the piece and rotation	
	; 	Check if a single pixel in the right of the piece is in the background's color (BLACK) (No piece/border) or not (There is piece/border)
proc CheckMoveRight
	push bp
	push ax
	push bx
	push cx
	push dx

	;Check which piece is it currently
	mov al, [PieceFileName]
	cmp al, 'I'
	jz @@CallI
	cmp al, 'O'
	jz @@CallO
	cmp al, 'T'
	jz @@CallT
	cmp al, 'S'
	jz @@CallS
	cmp al, 'Z'
	jz @@CallZ
	cmp al, 'L'
	jz @@CallL
	cmp al, 'J'
	jz @@CallJ
	
@@CallI:
	call CheckMoveIRight
	jmp @@Cont
@@CallO:
	call CheckMoveORight
	jmp @@Cont
@@CallT:
	call CheckMoveTRight
	jmp @@Cont
@@CallS:
	call CheckMoveSRight
	jmp @@Cont
@@CallZ:
	call CheckMoveZRight
	jmp @@Cont
@@CallL:
	call CheckMoveLRight
	jmp @@Cont
@@CallJ:
	call CheckMoveJRight
	;jmp @@Cont
	
@@Cont:
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret
endp CheckMoveRight

	;DESCRIPTION: Check if can move I piece right
proc CheckMoveIRight
	mov al, [PieceFileName+1];Al = dir
	cmp al, '0'
	jz @@Dir_0_2
	cmp al, '2'
	jz @@Dir_0_2
	;If got until here --> direction must be 1/3
	jmp @@Dir_1_3
@@Dir_0_2:
	call CheckRightI0_2
	jmp @@EndProc
@@Dir_1_3:
	call CheckRightI1_3
@@EndProc:
	ret
endp CheckMoveIRight
proc CheckRightI0_2;Piece: I, Dir: Right, Rotation: 0/2.
;	Length #1	
	mov cx, [x];Cx = current x pos
	mov ax, Cube_Size;Ax = cube size
	shl ax, 2;Ax = Addition to current x = location of the object that is on the right of the piece (if there is an object there...)
	add cx, ax;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	shr ax, 1;Ax = 2 * Cube size
	add dx, ax;Dx = y pos of the object that is possibly on the right of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	;IF CAN MOVE RIGHT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveRightBool], 1

@@EndProc:
	ret
endp CheckRightI0_2
proc CheckRightI1_3;Piece: I, Dir: Right, Rotation: 1/3.
;	Length #1	
	mov cx, [x];Cx = current x pos
	mov ax, Cube_Size;Ax = cube size
	shl ax, 1;Ax = Addition to current x = location of the object that is on the right of the piece (if there is an object there...)
	add cx, ax;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	
	mov bx, cx;Bx = x pos of the object that is possibly on the right of the cube
	mov cx, 4;For each cube in the length
@@ForILength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the object that is possibly on the right of the cube
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 4
	jnz @@ContLoop
	sub dx, Cube_Size
	
@@ContLoop:
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the right of the cube
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForILength
	;IF CAN MOVE RIGHT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveRightBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckRightI1_3

	;DESCRIPTION: Check if can move O piece right
proc CheckMoveORight
	call CheckRightO
	ret
endp CheckMoveORight
proc CheckRightO;Piece: O, Dir: Right, Rotation: 0/1/2/3.
;	For EVERY DIRECTION (all the rotations are the same)	
;	Length #1
	mov cx, 2
@@CheckRightPixel:
	push cx
	mov bx, cx
	mov cx, [x];Cx = current x pos
	mov ax, Cube_Size;Ax = cube size
	shl ax, 1;Ax = Addition to current x = location of the object that is on the right of the piece (if there is an object there...)
	add cx, ax;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	
	;SINCE THE LENGTH IS 2 CUBES LONG, WE NEED TO CHECK EACH CUBE - THE NEXT 3 LINES MAKE SURE WE CHECK EACH CUBE ONCE
	cmp bx, 2
	jnz @@Cont
	add dx, Cube_Size
@@Cont:
	;Dx = y pos of the object that is possibly on the right of the cube	
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndCheckRightPixel
	
	pop cx
	loop @@CheckRightPixel
	
	;IF CAN MOVE RIGHT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveRightBool], 1
	
	jmp @@EndProc
@@EndCheckRightPixel:
	;To recover the pop that we missed - to make sure the value's pop are correct and the IP will be correct
	pop cx
@@EndProc:
	ret
endp CheckRightO

	;DESCRIPTION: Check if can move T piece right 
proc CheckMoveTRight
	mov al, [PieceFileName+1];Al = dir
	cmp al, '0'
	jz @@Dir_0
	cmp al, '1'
	jz @@Dir_1
	cmp al, '2'
	jz @@Dir_2
	;If got until here --> direction must be 4
	jmp @@Dir_3
@@Dir_0:
	call CheckRightT0
	jmp @@EndProc
@@Dir_1:
	call CheckRightT1
	jmp @@EndProc
@@Dir_2:
	call CheckRightT2
	jmp @@EndProc
@@Dir_3:
	call CheckRightT3
@@EndProc:
	ret
endp CheckMoveTRight
proc CheckRightT0;Piece: T, Dir: Right, Rotation: 0.	
	;Length #1
	mov cx, [x];Cx = current x pos
	mov ax, Cube_Size;Ax = cube size
	shl ax, 1;Ax = Addition to current x - cube size
	add ax, Cube_Size;Ax = Addition to current x = location of the object that is on the right of the piece (if there is an object there...)
	add cx, ax;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the object that is possibly on the right of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
	;Length #2
	mov cx, [x];Cx = current x pos
	mov ax, Cube_Size;Ax = cube size
	shl ax, 1;Ax = Addition to current x = location of the object that is on the right of the piece (if there is an object there...)
	add cx, ax;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the right of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
	;IF CAN MOVE RIGHT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveRightBool], 1

@@EndProc:
	ret
endp CheckRightT0
proc CheckRightT1;Piece: T, Dir: Right, Rotation: 1.
;	Length #1	
	mov cx, [x];Cx = current x pos
	mov ax, Cube_Size;Ax = cube size
	shl ax, 1;Ax = Addition to current x = location of the object that is on the right of the piece (if there is an object there...)
	add cx, ax;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	
	mov bx, cx;Bx = x pos of the object that is possibly on the right of the cube
	mov cx, 3;For each cube in the length
@@ForILength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the object that is possibly on the right of the cube
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 3
	jnz @@ContLoop
	sub dx, Cube_Size
	
@@ContLoop:
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the right of the cube
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForILength
	;IF CAN MOVE RIGHT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveRightBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckRightT1
proc CheckRightT2;Piece: T, Dir: Right, Rotation: 2.
	;Length #1
	mov cx, [x];Cx = current x pos
	mov ax, Cube_Size;Ax = cube size
	shl ax, 1;Ax = Addition to current x = location of the object that is on the right of the piece (if there is an object there...)
	add cx, ax;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the right of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
	;Length #2
	mov cx, [x];Cx = current x pos
	mov ax, Cube_Size;Ax = cube size
	shl ax, 1;Ax = Addition to current x - cube size
	add cx, Cube_Size
	add cx, ax;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	add dx, ax;Ax = 2 * Cube_Size (Addition to current y = location of the object that is on the right of the piece (if there is an object there...))
	inc dx;Dx = y pos of the object that is possibly on the right of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
	
	;IF CAN MOVE RIGHT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveRightBool], 1
	
@@EndProc:
	ret
endp CheckRightT2
proc CheckRightT3;Piece: T, Dir: Right, Rotation: 3.

	;Length #1
	mov cx, [x];Cx = current x pos
	mov ax, Cube_Size;Ax = cube size
	shl ax, 1;Ax = Addition to current x = location of the object that is on the right of the piece (if there is an object there...)
	add cx, ax;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
	;Length #2
	mov cx, [x];Cx = current x pos
	mov ax, Cube_Size;Ax = cube size
	shl ax, 1;Ax = Addition to current x - cube size
	add ax, Cube_Size;Ax = Addition to current x = location of the object that is on the right of the piece (if there is an object there...)
	add cx, ax;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	inc dx;Dx = y pos of the object that is possibly on the right of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
	;Length #3
	mov cx, [x];Cx = current x pos
	mov ax, Cube_Size;Ax = cube size
	shl ax, 1;Ax = Addition to current x = location of the object that is on the right of the piece (if there is an object there...)
	add cx, ax;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, ax;Dx = y pos of the object that is possibly on the right of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
	;IF CAN MOVE RIGHT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveRightBool], 1

@@EndProc:
	ret
endp CheckRightT3

	;DESCRIPTION: Check if can move S piece right 
proc CheckMoveSRight
	mov al, [PieceFileName+1];Al = dir
	cmp al, '0'
	jz @@Dir_0_2
	cmp al, '2'
	jz @@Dir_0_2
	;If got until here --> direction must be 1/3
	jmp @@Dir_1_3
@@Dir_0_2:
	call CheckRightS0_2
	jmp @@EndProc
@@Dir_1_3:
	call CheckRightS1_3
@@EndProc:
	ret
endp CheckMoveSRight
proc CheckRightS0_2;Piece: S, Dir: Right, Rotation: 0/2.
	;Length #1
	mov cx, [x];Cx = current x pos
	mov ax, Cube_Size;Ax = cube size
	shl ax, 1;Ax = Addition to current x - cube size
	add ax, Cube_Size;Ax = Addition to current x = location of the object that is on the right of the piece (if there is an object there...)
	add cx, ax;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the object that is possibly on the right of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
	;Length #2
	mov cx, [x];Cx = current x pos
	mov ax, Cube_Size;Ax = cube size
	shl ax, 1;Ax = Addition to current x = location of the object that is on the right of the piece (if there is an object there...)
	add cx, ax;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	inc dx;Dx = y pos of the object that is possibly on the right of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	;IF CAN MOVE RIGHT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveRightBool], 1

@@EndProc:
	ret
endp CheckRightS0_2
proc CheckRightS1_3;Piece: S, Dir: Right, Rotation: 1/3.
;	Length #1
	mov cx, [x];Cx = current x pos
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the object that is possibly on the right of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
	;Length #2
	mov cx, 2
@@CheckRightPixel:
	push cx
	xor ax, ax;Zero
	;SINCE THE LENGTH IS 2 CUBES LONG, WE NEED TO CHECK EACH CUBE - THE NEXT LINES MAKE SURE WE CHECK EACH CUBE ONCE
	cmp cx, 2
	jnz @@Cont
	mov ax, Cube_Size
@@Cont:
	mov dx, [y];Dx = y pos of the object that is possibly on the right of the cube	
	inc dx
	add dx, Cube_Size
	add dx, ax;dx = y pos of the object that is possibly on the right of the CURRENT cube
	
	mov cx, [x];Cx = current x pos
	add cx, Cube_Size
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the right of the cube


	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@ReturnThePop
	pop cx
	loop @@CheckRightPixel
	

	;IF CAN MOVE RIGHT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveRightBool], 1

	jmp @@EndProc
@@ReturnThePop:
	;Pop so IP return to its correct value
	pop cx
@@EndProc:
	ret
endp CheckRightS1_3

	;DESCRIPTION: Check if can move Z piece right
proc CheckMoveZRight
	mov al, [PieceFileName+1];Al = dir
	cmp al, '0'
	jz @@Dir_0_2
	cmp al, '2'
	jz @@Dir_0_2
	;If got until here --> direction must be 1/3
	jmp @@Dir_1_3
@@Dir_0_2:
	call CheckRightZ0_2
	jmp @@EndProc
@@Dir_1_3:
	call CheckRightZ1_3
@@EndProc:
	ret
endp CheckMoveZRight
proc CheckRightZ0_2;Piece: Z, Dir: Right, Rotation: 0/2.
	;Length #1
	mov cx, [x];Cx = current x pos
	mov ax, Cube_Size;Ax = cube size
	shl ax, 1;Ax = Addition to current x - cube size
	add cx, ax;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the object that is possibly on the right of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
	;Length #2
	mov cx, [x];Cx = current x pos
	mov ax, Cube_Size;Ax = cube size
	shl ax, 1;Ax = Addition to current x = location of the object that is on the right of the piece (if there is an object there...)
	add ax, Cube_Size;Ax = Addition to current x = location of the object that is on the right of the piece (if there is an object there...)
	add cx, ax;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	add dx, Cube_Size;Dx = y pos
	inc dx;Dx = y pos of the object that is possibly on the right of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	;IF CAN MOVE RIGHT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveRightBool], 1

@@EndProc:
	ret
endp CheckRightZ0_2
proc CheckRightZ1_3;Piece: Z, Dir: Right, Rotation: 1/3.
	;Length #1
	mov cx, 2
@@CheckRightPixel:
	push cx
	xor ax, ax;Zero
	;SINCE THE LENGTH IS 2 CUBES LONG, WE NEED TO CHECK EACH CUBE - THE NEXT LINES MAKE SURE WE CHECK EACH CUBE ONCE
	cmp cx, 2
	jnz @@Cont
	mov ax, Cube_Size
@@Cont:
	mov dx, [y];Dx = y pos of the object that is possibly on the right of the cube	
	inc dx
	add dx, ax;dx = y pos of the object that is possibly on the right of the CURRENT cube
	
	mov cx, [x];Cx = current x pos
	add cx, Cube_Size
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the right of the cube

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@ReturnThePop
	pop cx
	loop @@CheckRightPixel
	
	;Length #2
	mov cx, [x];Cx = current x pos
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	add dx, Cube_Size	
	inc dx;Dx = y pos of the object that is possibly on the right of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	;IF CAN MOVE RIGHT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveRightBool], 1

	jmp @@EndProc
@@ReturnThePop:
	;Pop so IP return to its correct value
	pop cx
@@EndProc:
	ret
endp CheckRightZ1_3

	;DESCRIPTION: Check if can move L piece right
proc CheckMoveLRight
	mov al, [PieceFileName+1];Al = dir
	cmp al, '0'
	jz @@Dir_0
	cmp al, '1'
	jz @@Dir_1
	cmp al, '2'
	jz @@Dir_2
	;If got until here --> direction must be 4
	jmp @@Dir_3
@@Dir_0:
	call CheckRightL0
	jmp @@EndProc
@@Dir_1:
	call CheckRightL1
	jmp @@EndProc
@@Dir_2:
	call CheckRightL2
	jmp @@EndProc
@@Dir_3:
	call CheckRightL3
@@EndProc:
	ret
endp CheckMoveLRight
proc CheckRightL0;Piece: L, Dir: Right, Rotation: 0.
	;Length #1
	mov cx, [x];Cx = current x pos
	mov ax, Cube_Size
	shl ax, 1
	add cx, ax
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos of the object that is possibly on the right of the cube	
	inc dx;dx = y pos of the object that is possibly on the right of the CURRENT cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
;	Length #2
	mov cx, [x];Cx = current x pos
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the right of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	;IF CAN MOVE RIGHT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveRightBool], 1

@@EndProc:
	ret
endp CheckRightL0
proc CheckRightL1;Piece: L, Dir: Right, Rotation: 1.
;	Length #1	
	mov cx, [x];Cx = current x pos
	mov ax, Cube_Size;Ax = cube size
	shl ax, 1;Ax = Addition to current x = location of the object that is on the right of the piece (if there is an object there...)
	add cx, ax
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	
	mov bx, cx;Bx = x pos of the object that is possibly on the right of the cube
	mov cx, 3;For each cube in the length
@@ForILength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the object that is possibly on the right of the cube
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 3
	jnz @@ContLoop
	sub dx, Cube_Size
	
@@ContLoop:
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the right of the cube
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForILength
	;IF CAN MOVE RIGHT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveRightBool], 1

	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckRightL1
proc CheckRightL2;Piece: L, Dir: Right, Rotation: 2.
	;Length #1
	mov cx, 2
@@CheckRightPixel:
	push cx
	xor ax, ax;Zero
	;SINCE THE LENGTH IS 2 CUBES LONG, WE NEED TO CHECK EACH CUBE - THE NEXT LINES MAKE SURE WE CHECK EACH CUBE ONCE
	cmp cx, 2
	jnz @@Cont
	mov ax, Cube_Size
@@Cont:
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, ax;dx = y pos of the object that is possibly on the right of the CURRENT cube
	
	mov cx, [x];Cx = current x pos
	add cx, Cube_Size
	add cx, Cube_Size
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the right of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@ReturnThePop
	pop cx
	loop @@CheckRightPixel

	;IF CAN MOVE RIGHT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveRightBool], 1

	jmp @@EndProc
@@ReturnThePop:
	;Pop so IP return to its correct value
	pop cx
@@EndProc:
	ret
endp CheckRightL2
proc CheckRightL3;Piece: L, Dir: Right, Rotation: 3.
	;Length #1
	mov cx, 2
@@CheckRightPixel:
	push cx
	xor ax, ax;Zero
	;SINCE THE LENGTH IS 2 CUBES LONG, WE NEED TO CHECK EACH CUBE - THE NEXT LINES MAKE SURE WE CHECK EACH CUBE ONCE
	cmp cx, 2
	jnz @@Cont
	mov ax, Cube_Size
@@Cont:
	mov dx, [y];Dx = y pos of the object that is possibly on the right of the cube	
	inc dx
	add dx, ax;dx = y pos of the object that is possibly on the right of the CURRENT cube
	
	mov cx, [x];Cx = current x pos
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the right of the cube

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@ReturnThePop
	pop cx
	loop @@CheckRightPixel
	
;	Length #2
	mov cx, [x];Cx = current x pos
	mov ax, Cube_Size;Ax = cube size
	shl ax, 1;Ax = Addition to current x = location of the object that is on the right of the piece (if there is an object there...)
	add cx, ax;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	add dx, ax
	inc dx;Dx = y pos of the object that is possibly on the right of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	;IF CAN MOVE RIGHT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveRightBool], 1

	jmp @@EndProc
@@ReturnThePop:
	;Pop so IP return to its correct value
	pop cx
@@EndProc:
	ret
endp CheckRightL3

	;DESCRIPTION: Check if can move J piece right 
proc CheckMoveJRight
	mov al, [PieceFileName+1];Al = dir
	cmp al, '0'
	jz @@Dir_0
	cmp al, '1'
	jz @@Dir_1
	cmp al, '2'
	jz @@Dir_2
	;If got until here --> direction must be 4
	jmp @@Dir_3
@@Dir_0:
	call CheckRightJ0
	jmp @@EndProc
@@Dir_1:
	call CheckRightJ1
	jmp @@EndProc
@@Dir_2:
	call CheckRightJ2
	jmp @@EndProc
@@Dir_3:
	call CheckRightJ3
@@EndProc:
	ret
endp CheckMoveJRight
proc CheckRightJ0;Piece: J, Dir: Right, Rotation: 0.
	;Length #1
	mov cx, 2
@@CheckRightPixel:
	push cx
	xor ax, ax;Zero
	;SINCE THE LENGTH IS 2 CUBES LONG, WE NEED TO CHECK EACH CUBE - THE NEXT LINES MAKE SURE WE CHECK EACH CUBE ONCE
	cmp cx, 2
	jnz @@Cont
	mov ax, Cube_Size
@@Cont:
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, ax;dx = y pos of the object that is possibly on the right of the CURRENT cube
	
	mov cx, [x];Cx = current x pos
	add cx, Cube_Size
	add cx, Cube_Size
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the right of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@ReturnThePop
	pop cx
	loop @@CheckRightPixel

	;IF CAN MOVE RIGHT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveRightBool], 1

	jmp @@EndProc
@@ReturnThePop:
	;Pop so IP return to its correct value
	pop cx
@@EndProc:
	ret
endp CheckRightJ0
proc CheckRightJ1;Piece: J, Dir: Right, Rotation: 1.
	;Length #1
	mov cx, 2
@@CheckRightPixel:
	push cx
	xor ax, ax;Zero
	;SINCE THE LENGTH IS 2 CUBES LONG, WE NEED TO CHECK EACH CUBE - THE NEXT LINES MAKE SURE WE CHECK EACH CUBE ONCE
	cmp cx, 2
	jnz @@Cont
	mov ax, Cube_Size
@@Cont:
	mov dx, [y];Dx = y pos of the object that is possibly on the right of the cube	
	inc dx
	add dx, ax;dx = y pos of the object that is possibly on the right of the CURRENT cube
	
	mov cx, [x];Cx = x pos
	mov ax, Cube_Size
	shl ax, 1;Ax = Addition to current x = location of the object that is on the right of the piece (if there is an object there...)
	add cx, ax;Cx = x pos of the object that is possibly on the right of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@ReturnThePop
	pop cx
	loop @@CheckRightPixel
	
;	Length #2
	mov cx, [x];Cx = current x pos
	mov ax, Cube_Size;Ax = cube size
	shl ax, 1;Ax = Addition to current x = location of the object that is on the right of the piece (if there is an object there...)
	add cx, ax;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	add dx, ax
	inc dx;Dx = y pos of the object that is possibly on the right of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	;IF CAN MOVE RIGHT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveRightBool], 1

	jmp @@EndProc
@@ReturnThePop:
	;Pop so IP return to its correct value
	pop cx
@@EndProc:
	ret
endp CheckRightJ1
proc CheckRightJ2;Piece: J, Dir: Right, Rotation: 2.
	;Length #1
	mov cx, [x];Cx = current x pos
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos of the object that is possibly on the right of the cube	
	inc dx;dx = y pos of the object that is possibly on the right of the CURRENT cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
;	Length #2
	mov cx, [x];Cx = current x pos
	add cx, Cube_Size
	add cx, Cube_Size
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the right of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	;IF CAN MOVE RIGHT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveRightBool], 1

@@EndProc:
	ret
endp CheckRightJ2
proc CheckRightJ3;Piece: J, Dir: Right, Rotation: 3.
	
;	Length #1
	mov cx, [x];Cx = current x pos
	add cx, Cube_Size
	add cx, Cube_Size
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the right of the cube
	
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the object that is possibly on the right of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	;Length #2
	mov cx, 2
@@CheckRightPixel:
	push cx
	
	xor ax, ax;Zero
	;SINCE THE LENGTH IS 2 CUBES LONG, WE NEED TO CHECK EACH CUBE - THE NEXT LINES MAKE SURE WE CHECK EACH CUBE ONCE
	cmp cx, 2
	jnz @@Cont
	mov ax, Cube_Size
@@Cont:
	mov dx, [y];Dx = y pos of the object that is possibly on the right of the cube	
	inc dx
	add dx, Cube_Size
	add dx, ax;dx = y pos of the object that is possibly on the right of the CURRENT cube
	
	mov cx, [x];Cx = current x pos
	add cx, Cube_Size
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the right of the cube

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@ReturnThePop
	
	pop cx
	loop @@CheckRightPixel
	
	;IF CAN MOVE RIGHT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveRightBool], 1

	jmp @@EndProc
@@ReturnThePop:
	;Pop so IP return to its correct value
	pop cx
@@EndProc:
	ret
endp CheckRightJ3



;	DESCRIPTION: Move left current piece
proc MoveLeftPiece
	;Move left current piece one Cube_Size
	sub [x], Cube_Size
	ret
endp MoveLeftPiece

;	CHECK MOVE LEFT
	;DESCRIPTION: Check if can move piece left. If [CanMoveLeftBool] = 1 --> PIECE CAN MOVE LEFT. If [CanMoveLeftBool] = 0 --> PIECE CAN'T MOVE LEFT  
	;	Only updates [CanMoveLeftBool]
	;	Calls sub-procedure depends on the piece and rotation	
	; 	Check if a single pixel in the left of the piece is in the background's color (BLACK) (No piece/border) or not (There is piece/border)
proc CheckMoveLeft
	push bp
	push ax
	push bx
	push cx
	push dx

	;Check which piece is it currently
	mov al, [PieceFileName]
	cmp al, 'I'
	jz @@CallI
	cmp al, 'O'
	jz @@CallO
	cmp al, 'T'
	jz @@CallT
	cmp al, 'S'
	jz @@CallS
	cmp al, 'Z'
	jz @@CallZ
	cmp al, 'L'
	jz @@CallL
	cmp al, 'J'
	jz @@CallJ
	
@@CallI:
	call CheckMoveILeft
	jmp @@Cont
@@CallO:
	call CheckMoveOLeft
	jmp @@Cont
@@CallT:
	call CheckMoveTLeft
	jmp @@Cont
@@CallS:
	call CheckMoveSLeft
	jmp @@Cont
@@CallZ:
	call CheckMoveZLeft
	jmp @@Cont
@@CallL:
	call CheckMoveLLeft
	jmp @@Cont
@@CallJ:
	call CheckMoveJLeft
	;jmp @@Cont
	
@@Cont:
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret
endp CheckMoveLeft

	;DESCRIPTION: Check if can move I piece left (if can!), if can't move piece left (blocked) --> not moving 
proc CheckMoveILeft
	mov al, [PieceFileName+1];Al = dir
	cmp al, '0'
	jz @@Dir_0_2
	cmp al, '2'
	jz @@Dir_0_2
	;If got until here --> direction must be 1/3
	jmp @@Dir_1_3
@@Dir_0_2:
	call CheckLeftI0_2
	jmp @@EndProc
@@Dir_1_3:
	call CheckLeftI1_3
@@EndProc:
	ret
endp CheckMoveILeft
proc CheckLeftI0_2;Piece: I, Dir: Left, Rotation: 0/2.
;	Length #1	
	mov cx, [x];Cx = current x pos
	dec cx;Cx = x pos of the object that is possibly on the left of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the left of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	;IF CAN MOVE LEFT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveLeftBool], 1

@@EndProc:
	ret
endp CheckLeftI0_2
proc CheckLeftI1_3;Piece: I, Dir: Left, Rotation: 1/3.
;	Length #1	
	mov cx, [x];Cx = x pos of the object that is possibly on the left of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	
	mov bx, cx;Bx = x pos of the object that is possibly on the left of the cube
	mov cx, 4;For each cube in the length
@@ForILength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the object that is possibly on the left of the cube
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 4
	jnz @@ContLoop
	sub dx, Cube_Size
	
@@ContLoop:
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the left of the cube
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForILength
	;IF CAN MOVE LEFT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveLeftBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckLeftI1_3

	;DESCRIPTION: Check if can move O piece left (if can!), if can't move piece left (blocked) --> not moving 
proc CheckMoveOLeft
	call CheckLeftO
	ret
endp CheckMoveOLeft
proc CheckLeftO;Piece: O, Dir: Left, Rotation: 0/1/2/3.
;	For EVERY DIRECTION (all the rotations are the same)	
;	Length #1
	mov cx, 2
@@CheckLeftPixel:
	push cx
	mov bx, cx
	mov cx, [x];Cx = current x pos
	dec cx;Cx = x pos of the object that is possibly on the left of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	
	;SINCE THE LENGTH IS 2 CUBES LONG, WE NEED TO CHECK EACH CUBE - THE NEXT 3 LINES MAKE SURE WE CHECK EACH CUBE ONCE
	cmp bx, 2
	jnz @@Cont
	add dx, Cube_Size
@@Cont:
	;Dx = y pos of the object that is possibly on the left of the cube	
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndCheckLeftPixel
	
	pop cx
	loop @@CheckLeftPixel
	
	;IF CAN MOVE LEFT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveLeftBool], 1
	
	jmp @@EndProc
@@EndCheckLeftPixel:
	;To recover the pop that we missed - to make sure the value's pop are correct and the IP will be correct
	pop cx
@@EndProc:
	ret
endp CheckLeftO

	;DESCRIPTION: Check if can move T piece left (if can!), if can't move piece left (blocked) --> not moving 
proc CheckMoveTLeft
	mov al, [PieceFileName+1];Al = dir
	cmp al, '0'
	jz @@Dir_0
	cmp al, '1'
	jz @@Dir_1
	cmp al, '2'
	jz @@Dir_2
	;If got until here --> direction must be 4
	jmp @@Dir_3
@@Dir_0:
	call CheckLeftT0
	jmp @@EndProc
@@Dir_1:
	call CheckLeftT1
	jmp @@EndProc
@@Dir_2:
	call CheckLeftT2
	jmp @@EndProc
@@Dir_3:
	call CheckLeftT3
@@EndProc:
	ret
endp CheckMoveTLeft
proc CheckLeftT0;Piece: T, Dir: Left, Rotation: 0.
	;Length #1
	mov cx, [x];Cx = current x pos
	dec cx;Cx = x pos of the object that is possibly on the left of the cube
	
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the object that is possibly on the left of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
	;Length #2
	mov cx, [x];Cx = current x pos
	inc cx;Cx = x pos of the object that is possibly on the left of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the left of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
	;IF CAN MOVE LEFT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveLeftBool], 1

@@EndProc:
	ret
endp CheckLeftT0
proc CheckLeftT1;Piece: T, Dir: Left, Rotation: 1.
;	Length #1	
	mov cx, [x];Cx = x pos of the object that is possibly on the left of the cube
	
	mov dx, [y];Dx = y pos of the object that is possibly on the left of the cube
	inc dx
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
;	Length #2	
	mov cx, [x]
	dec cx;Cx = x pos of the object that is possibly on the left of the cube
	mov dx, [y];Dx = y pos of the object that is possibly on the left of the cube
	add dx, Cube_Size
	inc dx
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
;	Length #3	
	mov cx, [x];Cx = x pos of the object that is possibly on the left of the cube
	
	mov dx, [y]
	add dx, Cube_Size
	add dx, Cube_Size	
	inc dx;Dx = y pos of the object that is possibly on the left of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc	

	;IF CAN MOVE LEFT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveLeftBool], 1
	
	jmp @@EndProc
@@EndProc:
	ret
endp CheckLeftT1
proc CheckLeftT2;Piece: T, Dir: Left, Rotation: 2.
	;Length #1
	mov cx, [x];Cx = x pos of the object that is possibly on the left of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the left of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
	;Length #2
	mov cx, [x];Cx = current x pos
	dec cx;Cx = x pos of the object that is possibly on the left of the cube
	
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	add dx, Cube_Size
	inc dx;Dx = y pos of the object that is possibly on the left of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
	
	;IF CAN MOVE LEFT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveLeftBool], 1
	
@@EndProc:
	ret
endp CheckLeftT2
proc CheckLeftT3;Piece: T, Dir: Left, Rotation: 3.

;	Length #1	
	mov cx, [x];Cx = x pos of the object that is possibly on the left of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	
	mov bx, cx;Bx = x pos of the object that is possibly on the left of the cube
	mov cx, 3;For each cube in the length
@@ForTLength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the object that is possibly on the left of the cube
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 3
	jnz @@ContLoop
	sub dx, Cube_Size
	
@@ContLoop:
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the left of the cube
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForTLength
	;IF CAN MOVE LEFT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveLeftBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckLeftT3

	;DESCRIPTION: Check if can move S piece left (if can!), if can't move piece left (blocked) --> not moving 
proc CheckMoveSLeft
	mov al, [PieceFileName+1];Al = dir
	cmp al, '0'
	jz @@Dir_0_2
	cmp al, '2'
	jz @@Dir_0_2
	;If got until here --> direction must be 1/3
	jmp @@Dir_1_3
@@Dir_0_2:
	call CheckLeftS0_2
	jmp @@EndProc
@@Dir_1_3:
	call CheckLeftS1_3
@@EndProc:
	ret
endp CheckMoveSLeft
proc CheckLeftS0_2;Piece: S, Dir: Left, Rotation: 0/2.
	;Length #1
	mov cx, [x];Cx = x pos of the object that is possibly on the left of the cube
	
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the object that is possibly on the left of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
	;Length #2
	mov cx, [x];Cx = current x pos
	sub cx, Cube_Size;Cx = x pos of the object that is possibly on the left of the cube
	
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	inc dx;Dx = y pos of the object that is possibly on the left of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	;IF CAN MOVE LEFT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveLeftBool], 1

@@EndProc:
	ret
endp CheckLeftS0_2
proc CheckLeftS1_3;Piece: S, Dir: Left, Rotation: 1/3.

	;Length #1
	mov cx, 2
@@CheckLeftPixel:
	push cx
	xor ax, ax;Zero
	;SINCE THE LENGTH IS 2 CUBES LONG, WE NEED TO CHECK EACH CUBE - THE NEXT LINES MAKE SURE WE CHECK EACH CUBE ONCE
	cmp cx, 2
	jnz @@Cont
	mov ax, Cube_Size
@@Cont:
	mov dx, [y];Dx = y pos of the object that is possibly on the left of the cube	
	inc dx
	add dx, ax;dx = y pos of the object that is possibly on the left of the CURRENT cube
	
	mov cx, [x];Cx = current x pos
	dec cx;Cx = x pos of the object that is possibly on the left of the cube

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@ReturnThePop
	pop cx
	loop @@CheckLeftPixel
	
;	Length #2
	mov cx, [x];Cx = x pos of the object that is possibly on the left of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the left of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	;IF CAN MOVE LEFT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveLeftBool], 1

	jmp @@EndProc
@@ReturnThePop:
	;Pop so IP return to its correct value
	pop cx
@@EndProc:
	ret
endp CheckLeftS1_3

	;DESCRIPTION: Check if can move Z piece left (if can!), if can't move piece left (blocked) --> not moving 
proc CheckMoveZLeft
	mov al, [PieceFileName+1];Al = dir
	cmp al, '0'
	jz @@Dir_0_2
	cmp al, '2'
	jz @@Dir_0_2
	;If got until here --> direction must be 1/3
	jmp @@Dir_1_3
@@Dir_0_2:
	call CheckLeftZ0_2
	jmp @@EndProc
@@Dir_1_3:
	call CheckLeftZ1_3
@@EndProc:
	ret
endp CheckMoveZLeft
proc CheckLeftZ0_2;Piece: Z, Dir: Left, Rotation: 0/2.
	;Length #1
	mov cx, [x];Cx = current x pos
	dec cx;Cx = x pos of the object that is possibly on the left of the cube
	
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the object that is possibly on the left of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
	;Length #2
	mov cx, [x];Cx = x pos of the object that is possibly on the left of the cube
	
	mov dx, [y];Dx = y pos
	add dx, Cube_Size;Dx = y pos
	inc dx;Dx = y pos of the object that is possibly on the left of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	;IF CAN MOVE LEFT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveLeftBool], 1

@@EndProc:
	ret
endp CheckLeftZ0_2
proc CheckLeftZ1_3;Piece: Z, Dir: Left, Rotation: 1/3.
	
	;Length #1
	mov cx, [x];Cx = x pos of the object that is possibly on the left of the cube
	
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the object that is possibly on the left of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	;Length #2
	mov cx, 2
@@CheckLeftPixel:
	push cx
	xor ax, ax;Zero
	;SINCE THE LENGTH IS 2 CUBES LONG, WE NEED TO CHECK EACH CUBE - THE NEXT LINES MAKE SURE WE CHECK EACH CUBE ONCE
	cmp cx, 2
	jnz @@Cont
	mov ax, Cube_Size
@@Cont:
	mov dx, [y];Dx = y pos of the object that is possibly on the left of the cube	
	inc dx
	add dx, Cube_Size
	add dx, ax;dx = y pos of the object that is possibly on the left of the CURRENT cube
	
	mov cx, [x];Cx = current x pos
	dec cx;Cx = x pos of the object that is possibly on the left of the cube

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@ReturnThePop
	pop cx
	loop @@CheckLeftPixel

	;IF CAN MOVE LEFT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveLeftBool], 1

	jmp @@EndProc
@@ReturnThePop:
	;Pop so IP return to its correct value
	pop cx
@@EndProc:
	ret
endp CheckLeftZ1_3

	;DESCRIPTION: Check if can move L piece left (if can!), if can't move piece left (blocked) --> not moving 
proc CheckMoveLLeft
	mov al, [PieceFileName+1];Al = dir
	cmp al, '0'
	jz @@Dir_0
	cmp al, '1'
	jz @@Dir_1
	cmp al, '2'
	jz @@Dir_2
	;If got until here --> direction must be 4
	jmp @@Dir_3
@@Dir_0:
	call CheckLeftL0
	jmp @@EndProc
@@Dir_1:
	call CheckLeftL1
	jmp @@EndProc
@@Dir_2:
	call CheckLeftL2
	jmp @@EndProc
@@Dir_3:
	call CheckLeftL3
@@EndProc:
	ret
endp CheckMoveLLeft
proc CheckLeftL0;Piece: L, Dir: Left, Rotation: 0.

	;Length #1
	mov cx, 2
@@CheckLeftPixel:
	push cx
	xor ax, ax;Zero
	;SINCE THE LENGTH IS 2 CUBES LONG, WE NEED TO CHECK EACH CUBE - THE NEXT LINES MAKE SURE WE CHECK EACH CUBE ONCE
	cmp cx, 2
	jnz @@Cont
	mov ax, Cube_Size
@@Cont:
	mov dx, [y];Dx = y pos of the object that is possibly on the left of the cube	
	inc dx
	add dx, ax;dx = y pos of the object that is possibly on the left of the CURRENT cube
	
	mov cx, [x];Cx = current x pos
	dec cx;Cx = x pos of the object that is possibly on the left of the cube

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@ReturnThePop
	pop cx
	loop @@CheckLeftPixel

	;IF CAN MOVE LEFT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveLeftBool], 1
	
	jmp @@EndProc
@@ReturnThePop:
	;Pop so IP return to its correct value
	pop cx
	
@@EndProc:
	ret
endp CheckLeftL0
proc CheckLeftL1;Piece: L, Dir: Left, Rotation: 1.
	
	;Length #1
	mov cx, [x];Cx = x pos of the object that is possibly on the left of the cube
	
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the object that is possibly on the left of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	;Length #2
	mov cx, 2
@@CheckLeftPixel:
	push cx
	xor ax, ax;Zero
	;SINCE THE LENGTH IS 2 CUBES LONG, WE NEED TO CHECK EACH CUBE - THE NEXT LINES MAKE SURE WE CHECK EACH CUBE ONCE
	cmp cx, 2
	jnz @@Cont
	mov ax, Cube_Size
@@Cont:
	mov dx, [y];Dx = y pos of the object that is possibly on the left of the cube	
	inc dx
	add dx, Cube_Size
	add dx, ax;dx = y pos of the object that is possibly on the left of the CURRENT cube
	
	mov cx, [x];Cx = current x pos
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the left of the cube

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@ReturnThePop
	pop cx
	loop @@CheckLeftPixel

	;IF CAN MOVE LEFT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveLeftBool], 1

	jmp @@EndProc
@@ReturnThePop:
	;Pop so IP return to its correct value
	pop cx
@@EndProc:
	ret
endp CheckLeftL1
proc CheckLeftL2;Piece: L, Dir: Left, Rotation: 2.
	
	;Length #1
	mov cx, [x]
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the left of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the left of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
	;Length #2
	mov cx, [x]
	dec cx;Cx = x pos of the object that is possibly on the left of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the left of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
	
	;IF CAN MOVE LEFT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveLeftBool], 1

@@EndProc:
	ret
endp CheckLeftL2
proc CheckLeftL3;Piece: L, Dir: Left, Rotation: 3.
;	Length #1	
	mov cx, [x]
	dec cx;Cx = x pos of the object that is possibly on the left of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	
	mov bx, cx;Bx = x pos of the object that is possibly on the left of the cube
	mov cx, 3;For each cube in the length
@@ForILength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the object that is possibly on the left of the cube
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 3
	jnz @@ContLoop
	sub dx, Cube_Size
	
@@ContLoop:
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the left of the cube
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForILength
	;IF CAN MOVE LEFT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveLeftBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckLeftL3

	;DESCRIPTION: Check if can move J piece left (if can!), if can't move piece left (blocked) --> not moving 
proc CheckMoveJLeft
	mov al, [PieceFileName+1];Al = dir
	cmp al, '0'
	jz @@Dir_0
	cmp al, '1'
	jz @@Dir_1
	cmp al, '2'
	jz @@Dir_2
	;If got until here --> direction must be 4
	jmp @@Dir_3
@@Dir_0:
	call CheckLeftJ0
	jmp @@EndProc
@@Dir_1:
	call CheckLeftJ1
	jmp @@EndProc
@@Dir_2:
	call CheckLeftJ2
	jmp @@EndProc
@@Dir_3:
	call CheckLeftJ3
@@EndProc:
	ret
endp CheckMoveJLeft
proc CheckLeftJ0;Piece: J, Dir: Left, Rotation: 0.
	
	;Length #1
	mov cx, [x]
	dec cx;Cx = x pos of the object that is possibly on the left of the cube\
	
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	inc dx;Dx = y pos of the object that is possibly on the left of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	;Length #2
	mov cx, [x]
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the left of the cube\
	
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	add dx, Cube_Size
	inc dx;Dx = y pos of the object that is possibly on the left of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc	
	
	;IF CAN MOVE LEFT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveLeftBool], 1

@@EndProc:
	ret
endp CheckLeftJ0
proc CheckLeftJ1;Piece: J, Dir: Left, Rotation: 1.
	
	;Length #1
	mov cx, 2
@@CheckLeftPixel:
	push cx
	xor ax, ax;Zero
	;SINCE THE LENGTH IS 2 CUBES LONG, WE NEED TO CHECK EACH CUBE - THE NEXT LINES MAKE SURE WE CHECK EACH CUBE ONCE
	cmp cx, 2
	jnz @@Cont
	mov ax, Cube_Size
@@Cont:
	mov dx, [y];Dx = y pos of the object that is possibly on the left of the cube	
	inc dx
	add dx, ax;dx = y pos of the object that is possibly on the left of the CURRENT cube
	
	mov cx, [x];Cx = x pos of the object that is possibly on the left of the cube

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@ReturnThePop
	pop cx
	loop @@CheckLeftPixel

	;Length #2
	mov cx, [x]
	dec cx;Cx = x pos of the object that is possibly on the left of the cube
	
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	add dx, Cube_Size
	inc dx;Dx = y pos of the object that is possibly on the left of the cube
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	;IF CAN MOVE LEFT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveLeftBool], 1

	jmp @@EndProc
@@ReturnThePop:
	;Pop so IP return to its correct value
	pop cx
@@EndProc:
	ret
endp CheckLeftJ1
proc CheckLeftJ2;Piece: J, Dir: Left, Rotation: 2.
	
	;Length #1
	mov cx, 2
@@CheckLeftPixel:
	push cx
	xor ax, ax;Zero
	;SINCE THE LENGTH IS 2 CUBES LONG, WE NEED TO CHECK EACH CUBE - THE NEXT LINES MAKE SURE WE CHECK EACH CUBE ONCE
	cmp cx, 2
	jnz @@Cont
	mov ax, Cube_Size
@@Cont:
	mov dx, [y];Dx = y pos of the object that is possibly on the left of the cube	
	inc dx
	add dx, ax;dx = y pos of the object that is possibly on the left of the CURRENT cube
	
	mov cx, [x]
	dec cx;Cx = x pos of the object that is possibly on the left of the cube

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@ReturnThePop
	pop cx
	loop @@CheckLeftPixel

	;IF CAN MOVE LEFT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveLeftBool], 1

	jmp @@EndProc
@@ReturnThePop:
	;Pop so IP return to its correct value
	pop cx
@@EndProc:
	ret
endp CheckLeftJ2
proc CheckLeftJ3;Piece: J, Dir: Left, Rotation: 3.
;	Length #1	
	mov cx, [x];Cx = x pos of the object that is possibly on the left of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	
	mov bx, cx;Bx = x pos of the object that is possibly on the left of the cube
	mov cx, 3;For each cube in the length
@@ForILength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the object that is possibly on the left of the cube
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 3
	jnz @@ContLoop
	sub dx, Cube_Size
	
@@ContLoop:
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the left of the cube
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForILength
	;IF CAN MOVE LEFT = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveLeftBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckLeftJ3



;	DESCRIPTION: Move down current piece
proc MoveDownPiece
	;Move down current piece one Cube_Size
	add [y], Cube_Size
	ret
endp MoveDownPiece

;	CHECK MOVE DOWN
	;DESCRIPTION: Check if can move piece down. If [CanMoveDownBool] = 1 --> PIECE CAN MOVE DOWN. If [CanMoveDownBool] = 0 --> PIECE CAN'T MOVE DOWN  
	;	Only updates [CanMoveDownBool]
	;	Calls sub-procedure depends on the piece and rotation	
	; 	Check if a single pixel in the down of the piece is in the background's color (BLACK) (No piece/border) or not (There is piece/border)
proc CheckMoveDown
	push bp
	push ax
	push bx
	push cx
	push dx

	;Check which piece is it currently
	mov al, [PieceFileName]
	cmp al, 'I'
	jz @@CallI
	cmp al, 'O'
	jz @@CallO
	cmp al, 'T'
	jz @@CallT
	cmp al, 'S'
	jz @@CallS
	cmp al, 'Z'
	jz @@CallZ
	cmp al, 'L'
	jz @@CallL
	cmp al, 'J'
	jz @@CallJ
	
@@CallI:
	call CheckMoveIDown
	jmp @@Cont
@@CallO:
	call CheckMoveODown
	jmp @@Cont
@@CallT:
	call CheckMoveTDown
	jmp @@Cont
@@CallS:
	call CheckMoveSDown
	jmp @@Cont
@@CallZ:
	call CheckMoveZDown
	jmp @@Cont
@@CallL:
	call CheckMoveLDown
	jmp @@Cont
@@CallJ:
	call CheckMoveJDown
	;jmp @@Cont
	
@@Cont:
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret
endp CheckMoveDown

	;DESCRIPTION: Check if can move I piece down
proc CheckMoveIDown
	mov al, [PieceFileName+1];Al = dir
	cmp al, '0'
	jz @@Dir_0_2
	cmp al, '2'
	jz @@Dir_0_2
	;If got until here --> direction must be 1/3
	jmp @@Dir_1_3
@@Dir_0_2:
	call CheckDownI0_2
	jmp @@EndProc
@@Dir_1_3:
	call CheckDownI1_3
@@EndProc:
	ret
endp CheckMoveIDown
proc CheckDownI0_2;Piece: I, Dir: Down, Rotation: 0/2.

;	Length #1	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the down of the cube

	mov cx, [x];Cx = x pos of the object that is possibly on the down of the cube
	
	
	mov bx, cx;Bx = x pos of the object that is possibly on the down of the cube
	mov cx, 4;For each cube in the length
@@ForILength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the object that is possibly on the down of the cube
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 4
	jnz @@ContLoop
	sub cx, Cube_Size
	
@@ContLoop:
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the down of the cube
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForILength
	
	;IF CAN MOVE DOWN = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveDownBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckDownI0_2
proc CheckDownI1_3;Piece: I, Dir: Down, Rotation: 1/3.

;	Length #1	
	mov cx, [x];Cx = current x pos
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	mov ax, Cube_Size
	shl ax, 2;Ax = 4*Cube_Size
	add dx, ax;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
	;IF CAN MOVE DOWN = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveDownBool], 1

@@EndProc:
	ret
endp CheckDownI1_3

	;DESCRIPTION: Check if can move O piece down
proc CheckMoveODown
	call CheckDownO
	ret
endp CheckMoveODown
proc CheckDownO;Piece: O, Dir: Down, Rotation: 0/1/2/3.
;	For EVERY DIRECTION (all the rotations are the same)	

;	Length #1	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the down of the cube

	mov cx, [x];Cx = x pos of the object that is possibly on the down of the cube
	
	
	mov bx, cx;Bx = x pos of the object that is possibly on the down of the cube
	mov cx, 2;For each cube in the length
@@ForILength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the object that is possibly on the down of the cube
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 2
	jnz @@ContLoop
	sub cx, Cube_Size
	
@@ContLoop:
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the down of the cube
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForILength
	
	;IF CAN MOVE DOWN = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveDownBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckDownO

	;DESCRIPTION: Check if can move T piece down
proc CheckMoveTDown
	mov al, [PieceFileName+1];Al = dir
	cmp al, '0'
	jz @@Dir_0
	cmp al, '1'
	jz @@Dir_1
	cmp al, '2'
	jz @@Dir_2
	;If got until here --> direction must be 4
	jmp @@Dir_3
@@Dir_0:
	call CheckDownT0
	jmp @@EndProc
@@Dir_1:
	call CheckDownT1
	jmp @@EndProc
@@Dir_2:
	call CheckDownT2
	jmp @@EndProc
@@Dir_3:
	call CheckDownT3
@@EndProc:
	ret
endp CheckMoveTDown
proc CheckDownT0;Piece: T, Dir: Down, Rotation: 0.

;	Length #1	
	mov cx, [x];Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

;	Length #2	
	mov cx, [x]
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

;	Length #3	
	mov cx, [x]
	add cx, Cube_Size
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
	;IF CAN MOVE DOWN = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveDownBool], 1

@@EndProc:
	ret
endp CheckDownT0
proc CheckDownT1;Piece: T, Dir: Down, Rotation: 1.

;	Length #1	
	mov cx, [x];Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

;	Length #2	
	mov cx, [x]
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	
	;IF CAN MOVE DOWN = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveDownBool], 1

@@EndProc:
	ret
endp CheckDownT1
proc CheckDownT2;Piece: T, Dir: Down, Rotation: 2.

;	Length #1	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the down of the cube

	mov cx, [x];Cx = x pos of the object that is possibly on the down of the cube
	
	mov bx, cx;Bx = x pos of the object that is possibly on the down of the cube
	mov cx, 3;For each cube in the length
@@ForILength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the object that is possibly on the down of the cube
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 3
	jnz @@ContLoop
	sub cx, Cube_Size
	
@@ContLoop:
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the down of the cube
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForILength
	
	;IF CAN MOVE DOWN = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveDownBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckDownT2
proc CheckDownT3;Piece: T, Dir: Down, Rotation: 3.

;	Length #1	
	mov cx, [x]
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
;	Length #2	
	mov cx, [x]
	add cx, Cube_Size
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	
	;IF CAN MOVE DOWN = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveDownBool], 1

@@EndProc:
	ret
endp CheckDownT3

	;DESCRIPTION: Check if can move S piece down
proc CheckMoveSDown
	mov al, [PieceFileName+1];Al = dir
	cmp al, '0'
	jz @@Dir_0_2
	cmp al, '2'
	jz @@Dir_0_2
	;If got until here --> direction must be 1/3
	jmp @@Dir_1_3
@@Dir_0_2:
	call CheckDownS0_2
	jmp @@EndProc
@@Dir_1_3:
	call CheckDownS1_3
@@EndProc:
	ret
endp CheckMoveSDown
proc CheckDownS0_2;Piece: S, Dir: Down, Rotation: 0/2.

;	Length #1	
	mov cx, [x];Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

;	Length #2	
	mov cx, [x]
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

;	Length #3	
	mov cx, [x]
	add cx, Cube_Size
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	
	;IF CAN MOVE DOWN = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveDownBool], 1
	
@@EndProc:
	ret
endp CheckDownS0_2
proc CheckDownS1_3;Piece: S, Dir: Down, Rotation: 1/3.

;	Length #1	
	mov cx, [x];Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

;	Length #2	
	mov cx, [x]
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	
	;IF CAN MOVE DOWN = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveDownBool], 1
	
@@EndProc:
	ret
endp CheckDownS1_3

	;DESCRIPTION: Check if can move Z piece down
proc CheckMoveZDown
	mov al, [PieceFileName+1];Al = dir
	cmp al, '0'
	jz @@Dir_0_2
	cmp al, '2'
	jz @@Dir_0_2
	;If got until here --> direction must be 1/3
	jmp @@Dir_1_3
@@Dir_0_2:
	call CheckDownZ0_2
	jmp @@EndProc
@@Dir_1_3:
	call CheckDownZ1_3
@@EndProc:
	ret
endp CheckMoveZDown
proc CheckDownZ0_2;Piece: Z, Dir: Down, Rotation: 0/2.

;	Length #1	
	mov cx, [x];Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
;	Length #2	
	mov cx, [x]
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the Down of the cube
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

;	Length #3	
	mov cx, [x]
	add cx, Cube_Size
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	
	;IF CAN MOVE DOWN = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveDownBool], 1
	
@@EndProc:
	ret
endp CheckDownZ0_2
proc CheckDownZ1_3;Piece: Z, Dir: Down, Rotation: 1/3.

;	Length #1	
	mov cx, [x];Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
;	Length #2	
	mov cx, [x]
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the Down of the cube
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	
	;IF CAN MOVE DOWN = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveDownBool], 1
	
@@EndProc:
	ret
endp CheckDownZ1_3

	;DESCRIPTION: Check if can move L piece down
proc CheckMoveLDown
	mov al, [PieceFileName+1];Al = dir
	cmp al, '0'
	jz @@Dir_0
	cmp al, '1'
	jz @@Dir_1
	cmp al, '2'
	jz @@Dir_2
	;If got until here --> direction must be 4
	jmp @@Dir_3
@@Dir_0:
	call CheckDownL0
	jmp @@EndProc
@@Dir_1:
	call CheckDownL1
	jmp @@EndProc
@@Dir_2:
	call CheckDownL2
	jmp @@EndProc
@@Dir_3:
	call CheckDownL3
@@EndProc:
	ret
endp CheckMoveLDown
proc CheckDownL0;Piece: L, Dir: Down, Rotation: 0.

;	Length #1	
	mov cx, [x];Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
;	Length #2	
	mov cx, [x]
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the Down of the cube
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

;	Length #3	
	mov cx, [x]
	add cx, Cube_Size
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	
	;IF CAN MOVE DOWN = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveDownBool], 1
	
@@EndProc:
	ret
endp CheckDownL0
proc CheckDownL1;Piece: L, Dir: Down, Rotation: 1.

;	Length #1	
	mov cx, [x]
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc
	
;	Length #2	
	mov cx, [x]
	add cx, Cube_Size
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the Down of the cube
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	
	;IF CAN MOVE DOWN = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveDownBool], 1
	
@@EndProc:
	ret
endp CheckDownL1
proc CheckDownL2;Piece: L, Dir: Down, Rotation: 2.

;	Length #1	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the down of the cube

	mov cx, [x];Cx = x pos of the object that is possibly on the down of the cube
	
	
	mov bx, cx;Bx = x pos of the object that is possibly on the down of the cube
	mov cx, 3;For each cube in the length
@@ForILength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the object that is possibly on the down of the cube
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 3
	jnz @@ContLoop
	sub cx, Cube_Size
	
@@ContLoop:
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the down of the cube
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForILength
	
	;IF CAN MOVE DOWN = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveDownBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckDownL2
proc CheckDownL3;Piece: L, Dir: Down, Rotation: 3.

;	Length #1	
	mov cx, [x];Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

;	Length #2	
	mov cx, [x]
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	
	;IF CAN MOVE DOWN = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveDownBool], 1
	
@@EndProc:
	ret
endp CheckDownL3

	;DESCRIPTION: Check if can move J piece down
proc CheckMoveJDown
	mov al, [PieceFileName+1];Al = dir
	cmp al, '0'
	jz @@Dir_0
	cmp al, '1'
	jz @@Dir_1
	cmp al, '2'
	jz @@Dir_2
	;If got until here --> direction must be 4
	jmp @@Dir_3
@@Dir_0:
	call CheckDownJ0
	jmp @@EndProc
@@Dir_1:
	call CheckDownJ1
	jmp @@EndProc
@@Dir_2:
	call CheckDownJ2
	jmp @@EndProc
@@Dir_3:
	call CheckDownJ3
@@EndProc:
	ret
endp CheckMoveJDown
proc CheckDownJ0;Piece: J, Dir: Down, Rotation: 0.

;	Length #1	
	mov cx, [x];Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

;	Length #2	
	mov cx, [x]
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc	
	
;	Length #3	
	mov cx, [x]
	add cx, Cube_Size
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the Down of the cube
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	
	;IF CAN MOVE DOWN = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveDownBool], 1
	
@@EndProc:
	ret
endp CheckDownJ0
proc CheckDownJ1;Piece: J, Dir: Down, Rotation: 1.

;	Length #1	
	mov cx, [x];Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

;	Length #2	
	mov cx, [x]
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc	

	
	;IF CAN MOVE DOWN = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveDownBool], 1
	
@@EndProc:
	ret
endp CheckDownJ1
proc CheckDownJ2;Piece: J, Dir: Down, Rotation: 2.

;	Length #1	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the down of the cube

	mov cx, [x];Cx = x pos of the object that is possibly on the down of the cube
	
	mov bx, cx;Bx = x pos of the object that is possibly on the down of the cube
	mov cx, 3;For each cube in the length
@@ForILength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the object that is possibly on the down of the cube
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 3
	jnz @@ContLoop
	sub cx, Cube_Size
	
@@ContLoop:
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the down of the cube
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForILength
	
	;IF CAN MOVE DOWN = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveDownBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckDownJ2
proc CheckDownJ3;Piece: J, Dir: Down, Rotation: 3.

;	Length #1	
	mov cx, [x]
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

;	Length #2	
	mov cx, [x]
	add cx, Cube_Size
	add cx, Cube_Size;Cx = x pos of the object that is possibly on the Down of the cube
	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size;Dx = y pos of the object that is possibly on the Down of the cube
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> don't update the values
	jnz @@EndProc

	
	;IF CAN MOVE DOWN = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanMoveDownBool], 1
	
@@EndProc:
	ret
endp CheckDownJ3


;	DESCRIPTION: Rotate current piece to wanted rotation
proc RotatePiece
	push ax
	;Check which rotate next
	call ReturnWhichRotateNext
	
	;Insert rotation number in PieceFileName
	mov [PieceFileName+1], al
	pop ax
	ret
endp RotatePiece

;	CHECK ROTATE PIECE
	;DESCRIPTION: Check if can rotate piece. If [CanRotatePieceBool] = 1 --> PIECE CAN ROTATE. If [CanRotatePieceBool] = 0 --> PIECE CAN'T ROTATE 
	;	Only updates [CanRotatePieceBool]
	;	Calls sub-procedure depends on the piece and rotation	
	; 	Check if a series of pixel in the place of the new rotation are in the background's color (BLACK) (No piece/border) or not (There is piece/border)
	;	INPUT: al = ASCII number of wanted rotation (0-3)
proc CheckRotatePiece 
	push bp
	push ax
	push bx
	push cx
	push dx

	;Check which piece is it currently
	mov ah, [PieceFileName]
	cmp ah, 'I'
	jz @@CallI
	cmp ah, 'O'
	jz @@CallO
	cmp ah, 'T'
	jz @@CallT
	cmp ah, 'S'
	jz @@CallS
	cmp ah, 'Z'
	jz @@CallZ
	cmp ah, 'L'
	jz @@CallL
	cmp ah, 'J'
	jz @@CallJ
	
@@CallI:
	call CheckRotateI
	jmp @@Cont
@@CallO:
	call CheckRotateO
	jmp @@Cont
@@CallT:
	call CheckRotateT
	jmp @@Cont
@@CallS:
	call CheckRotateS
	jmp @@Cont
@@CallZ:
	call CheckRotateZ
	jmp @@Cont
@@CallL:
	call CheckRotateL
	jmp @@Cont
@@CallJ:
	call CheckRotateJ
	;jmp @@Cont
	
@@Cont:
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret

endp CheckRotatePiece

	;DESCRIPTION: Check if can rotate I piece	
proc CheckRotateI
	cmp al, '0'
	jz @@Dir_0_2
	cmp al, '2'
	jz @@Dir_0_2
	;If got until here --> direction must be 1/3
	jmp @@Dir_1_3
@@Dir_0_2:
	call CheckRotateI0_2
	jmp @@EndProc
@@Dir_1_3:
	call CheckRotateI1_3
@@EndProc:
	ret
endp CheckRotateI
proc CheckRotateI0_2;Piece: I, Rotation: 0/2.

;	Set of cube #1	
	mov dx, [y];Dx = y pos
	inc dx
	add dx, Cube_Size
	add dx, Cube_Size;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos of the new rotated piece
		
	mov bx, cx;Bx = x pos of the new rotated piece
	mov cx, 4;For each cube in the length
@@ForEachCubeInLength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the new rotated piece
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 4
	jnz @@ContLoop
	sub cx, Cube_Size
	
@@ContLoop:
	add cx, Cube_Size;Cx = x pos of the new rotated piece
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForEachCubeInLength
	
	;IF CAN ROTATE = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanRotatePieceBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckRotateI0_2
proc CheckRotateI1_3;Piece: I, Rotation: 1/3.

;	Set of cube #1	
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = y pos
	add cx, Cube_Size;Cx = x pos of the new rotated piece
		
	mov bx, cx;Bx = x pos of the new rotated piece
	mov cx, 4;For each cube in the length
@@ForEachCubeInLength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the new rotated piece
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 4
	jnz @@ContLoop
	sub dx, Cube_Size
	
@@ContLoop:
	add dx, Cube_Size;Cx = x pos of the new rotated piece
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForEachCubeInLength
	
	;IF CAN ROTATE = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanRotatePieceBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckRotateI1_3

	;DESCRIPTION: Check if can rotate O piece	
proc CheckRotateO
	call CheckRotateOAll
	ret
endp CheckRotateO
proc CheckRotateOAll;Piece: O, Rotation: 0/1/2/3.

;	Cube #1
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc

;	Cube #2
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc

;	Cube #3
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = y pos
	add cx, Cube_Size;Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc

;	Cube #4
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = y pos
	add cx, Cube_Size;Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc	
	
	;IF CAN ROTATE = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanRotatePieceBool], 1
	
	jmp @@EndProc

@@EndProc:
	ret
endp CheckRotateOAll

	;DESCRIPTION: Check if can rotate T piece	
proc CheckRotateT
	cmp al, '0'
	jz @@Dir_0
	cmp al, '1'
	jz @@Dir_1
	cmp al, '2'
	jz @@Dir_2
	;If got until here --> direction must be 4
	jmp @@Dir_3
@@Dir_0:
	call CheckRotateT0
	jmp @@EndProc
@@Dir_1:
	call CheckRotateT1
	jmp @@EndProc
@@Dir_2:
	call CheckRotateT2
	jmp @@EndProc
@@Dir_3:
	call CheckRotateT3
@@EndProc:
	ret
endp CheckRotateT
proc CheckRotateT0;Piece: T, Rotation: 0.

;	Set of cube #1	
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos of the new rotated piece
		
	mov bx, cx;Bx = x pos of the new rotated piece
	mov cx, 3;For each cube in the length
@@ForEachCubeInLength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the new rotated piece
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 3
	jnz @@ContLoop
	sub Cx, Cube_Size
	
@@ContLoop:
	add cx, Cube_Size;Cx = x pos of the new rotated piece
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForEachCubeInLength
	
;	Cube #4
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = y pos
	add cx, Cube_Size;Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc	
	
	;IF CAN ROTATE = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanRotatePieceBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckRotateT0
proc CheckRotateT1;Piece: T, Rotation: 1.

;	Set of cube #1	
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x]
	add cx, Cube_Size;Cx = x pos of the new rotated piece
	
	mov bx, cx;Bx = x pos of the new rotated piece
	mov cx, 3;For each cube in the length
@@ForEachCubeInLength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the new rotated piece
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 3
	jnz @@ContLoop
	sub dx, Cube_Size
	
@@ContLoop:
	add dx, Cube_Size;Cx = x pos of the new rotated piece
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForEachCubeInLength
	
;	Cube #4
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc	
	
	;IF CAN ROTATE = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanRotatePieceBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckRotateT1
proc CheckRotateT2;Piece: T, Rotation: 2.

;	Set of cube #1	
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos of the new rotated piece
	
	mov bx, cx;Bx = x pos of the new rotated piece
	mov cx, 3;For each cube in the length
@@ForEachCubeInLength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the new rotated piece
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 3
	jnz @@ContLoop
	sub cx, Cube_Size
	
@@ContLoop:
	add cx, Cube_Size;Cx = x pos of the new rotated piece
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForEachCubeInLength
	
;	Cube #4
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x]
	add cx, Cube_Size;Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc	
	
	;IF CAN ROTATE = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanRotatePieceBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckRotateT2
proc CheckRotateT3;Piece: T, Rotation: 3.

;	Set of cube #1	
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x]
	add cx, Cube_Size;Cx = x pos of the new rotated piece
	
	mov bx, cx;Bx = x pos of the new rotated piece
	mov cx, 3;For each cube in the length
@@ForEachCubeInLength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the new rotated piece
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 3
	jnz @@ContLoop
	sub dx, Cube_Size
	
@@ContLoop:
	add dx, Cube_Size;Cx = x pos of the new rotated piece
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForEachCubeInLength
	
;	Cube #4
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos
	add cx, Cube_Size
	add cx, Cube_Size;Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc	
	
	;IF CAN ROTATE = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanRotatePieceBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckRotateT3

	;DESCRIPTION: Check if can rotate S piece	
proc CheckRotateS
	cmp al, '0'
	jz @@Dir_0_2
	cmp al, '2'
	jz @@Dir_0_2
	;If got until here --> direction must be 1/3
	jmp @@Dir_1_3
@@Dir_0_2:
	call CheckRotateS0_2
	jmp @@EndProc
@@Dir_1_3:
	call CheckRotateS1_3
@@EndProc:
	ret
endp CheckRotateS
proc CheckRotateS0_2;Piece: S, Rotation: 0/2.

;	Cube #1
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos
	add cx, Cube_Size;Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc

;	Cube #2
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos
	add cx, Cube_Size
	add cx, Cube_Size;Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc

;	Cube #3
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc

;	Cube #4
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos
	add cx, Cube_Size;Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc	
	
	;IF CAN ROTATE = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanRotatePieceBool], 1
	
	jmp @@EndProc

@@EndProc:
	ret
endp CheckRotateS0_2
proc CheckRotateS1_3;Piece: S, Rotation: 1/3.

;	Cube #1
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc

;	Cube #2
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc

;	Cube #3
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos
	add cx, Cube_Size;Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc

;	Cube #4
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos
	add cx, Cube_Size;Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc	
	
	;IF CAN ROTATE = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanRotatePieceBool], 1
	
	jmp @@EndProc

@@EndProc:
	ret
endp CheckRotateS1_3

	;DESCRIPTION: Check if can rotate Z piece	
proc CheckRotateZ
	cmp al, '0'
	jz @@Dir_0_2
	cmp al, '2'
	jz @@Dir_0_2
	;If got until here --> direction must be 1/3
	jmp @@Dir_1_3
@@Dir_0_2:
	call CheckRotateZ0_2
	jmp @@EndProc
@@Dir_1_3:
	call CheckRotateZ1_3
@@EndProc:
	ret
endp CheckRotateZ
proc CheckRotateZ0_2;Piece: Z, Rotation: 0/2.

;	Cube #1
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc

;	Cube #2
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos
	add cx, Cube_Size;Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc

;	Cube #3
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos
	add cx, Cube_Size;Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc

;	Cube #4
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos
	add cx, Cube_Size
	add cx, Cube_Size;Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc	
	
	;IF CAN ROTATE = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanRotatePieceBool], 1
	
	jmp @@EndProc

@@EndProc:
	ret
endp CheckRotateZ0_2
proc CheckRotateZ1_3;Piece: Z, Rotation: 1/3.

;	Cube #1
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc

;	Cube #2
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc

;	Cube #3
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos
	add cx, Cube_Size;Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc

;	Cube #4
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos
	add cx, Cube_Size;Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc	
	
	;IF CAN ROTATE = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanRotatePieceBool], 1
	
	jmp @@EndProc

@@EndProc:
	ret
endp CheckRotateZ1_3

	;DESCRIPTION: Check if can rotate L piece	
proc CheckRotateL
	cmp al, '0'
	jz @@Dir_0
	cmp al, '1'
	jz @@Dir_1
	cmp al, '2'
	jz @@Dir_2
	;If got until here --> direction must be 4
	jmp @@Dir_3
@@Dir_0:
	call CheckRotateL0
	jmp @@EndProc
@@Dir_1:
	call CheckRotateL1
	jmp @@EndProc
@@Dir_2:
	call CheckRotateL2
	jmp @@EndProc
@@Dir_3:
	call CheckRotateL3
@@EndProc:
	ret
endp CheckRotateL
proc CheckRotateL0;Piece: L, Rotation: 0.

;	Set of cube #1	
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos of the new rotated piece
		
	mov bx, cx;Bx = x pos of the new rotated piece
	mov cx, 3;For each cube in the length
@@ForEachCubeInLength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the new rotated piece
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 3
	jnz @@ContLoop
	sub Cx, Cube_Size
	
@@ContLoop:
	add cx, Cube_Size;Cx = x pos of the new rotated piece
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForEachCubeInLength
	
;	Cube #4
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc	
	
	;IF CAN ROTATE = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanRotatePieceBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckRotateL0
proc CheckRotateL1;Piece: L, Rotation: 1.

;	Cube #1
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos
	add cx, Cube_Size;Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc
	
;	Set of cube #2	
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos
	add cx, Cube_Size
	add cx, Cube_Size;Cx = x pos of the new rotated piece
		
	mov bx, cx;Bx = x pos of the new rotated piece
	mov cx, 3;For each cube in the length
@@ForEachCubeInLength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the new rotated piece
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 3
	jnz @@ContLoop
	sub dx, Cube_Size
	
@@ContLoop:
	add dx, Cube_Size;Dx = y pos of the new rotated piece
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForEachCubeInLength
	
	
	;IF CAN ROTATE = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanRotatePieceBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckRotateL1
proc CheckRotateL2;Piece: L, Rotation: 2.

;	Cube #1
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos
	add cx, Cube_Size
	add cx, Cube_Size;Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc	
	
;	Set of cube #2	
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos of the new rotated piece
		
	mov bx, cx;Bx = x pos of the new rotated piece
	mov cx, 3;For each cube in the length
@@ForEachCubeInLength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the new rotated piece
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 3
	jnz @@ContLoop
	sub cx, Cube_Size
	
@@ContLoop:
	add cx, Cube_Size;Cx = x pos of the new rotated piece
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForEachCubeInLength
	
	
	;IF CAN ROTATE = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanRotatePieceBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckRotateL2
proc CheckRotateL3;Piece: L, Rotation: 3.

;	Set of cube #1	
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos of the new rotated piece
		
	mov bx, cx;Bx = x pos of the new rotated piece
	mov cx, 3;For each cube in the length
@@ForEachCubeInLength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the new rotated piece
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 3
	jnz @@ContLoop
	sub dx, Cube_Size
	
@@ContLoop:
	add dx, Cube_Size;Dx = y pos of the new rotated piece
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForEachCubeInLength
	
;	Cube #2
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos
	add cx, Cube_Size;Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc
	
	
	;IF CAN ROTATE = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanRotatePieceBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckRotateL3

	;DESCRIPTION: Check if can rotate J piece	
proc CheckRotateJ
	cmp al, '0'
	jz @@Dir_0
	cmp al, '1'
	jz @@Dir_1
	cmp al, '2'
	jz @@Dir_2
	;If got until here --> direction must be 4
	jmp @@Dir_3
@@Dir_0:
	call CheckRotateJ0
	jmp @@EndProc
@@Dir_1:
	call CheckRotateJ1
	jmp @@EndProc
@@Dir_2:
	call CheckRotateJ2
	jmp @@EndProc
@@Dir_3:
	call CheckRotateJ3
@@EndProc:
	ret
endp CheckRotateJ
proc CheckRotateJ0;Piece: J, Rotation: 0.

;	Set of cube #1	
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos of the new rotated piece
		
	mov bx, cx;Bx = x pos of the new rotated piece
	mov cx, 3;For each cube in the length
@@ForEachCubeInLength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the new rotated piece
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 3
	jnz @@ContLoop
	sub cx, Cube_Size
	
@@ContLoop:
	add cx, Cube_Size;Cx = x pos of the new rotated piece
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForEachCubeInLength
	
;	Cube #4
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos
	add cx, Cube_Size
	add cx, Cube_Size;Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc	
	
	;IF CAN ROTATE = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanRotatePieceBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckRotateJ0
proc CheckRotateJ1;Piece: J, Rotation: 1.

;	Cube #1
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc
	
;	Set of cube #2	
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos
	add cx, Cube_Size;Cx = x pos of the new rotated piece
		
	mov bx, cx;Bx = x pos of the new rotated piece
	mov cx, 3;For each cube in the length
@@ForEachCubeInLength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the new rotated piece
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 3
	jnz @@ContLoop
	sub dx, Cube_Size
	
@@ContLoop:
	add dx, Cube_Size;Dx = y pos of the new rotated piece
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForEachCubeInLength
	
	
	;IF CAN ROTATE = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanRotatePieceBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckRotateJ1
proc CheckRotateJ2;Piece: J, Rotation: 2.

;	Cube #1
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc	
	
;	Set of cube #2	
	mov dx, [y];Dx = y pos
	add dx, Cube_Size
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos of the new rotated piece
		
	mov bx, cx;Bx = x pos of the new rotated piece
	mov cx, 3;For each cube in the length
@@ForEachCubeInLength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the new rotated piece
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 3
	jnz @@ContLoop
	sub cx, Cube_Size
	
@@ContLoop:
	add cx, Cube_Size;Cx = x pos of the new rotated piece
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForEachCubeInLength
	
	
	;IF CAN ROTATE = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanRotatePieceBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckRotateJ2
proc CheckRotateJ3;Piece: J, Rotation: 3.

;	Set of cube #1	
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos
	add cx, Cube_Size;Cx = x pos of the new rotated piece
	
	mov bx, cx;Bx = x pos of the new rotated piece
	mov cx, 3;For each cube in the length
@@ForEachCubeInLength:
	push cx;[LOOP] Cx
	mov ax, cx;Ax = [LOOP] Cx
	mov cx, bx;Cx = x pos of the new rotated piece
	
	;To make sure that it checks every cube in the length (INCLUDING CUBE 0 - THE HIGHEST)
	cmp ax, 3
	jnz @@ContLoop
	sub dx, Cube_Size
	
@@ContLoop:
	add dx, Cube_Size;Dx = y pos of the new rotated piece
	push cx;Save x pos
	push dx;Save y pos
	
	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@RecoverPop
	
	pop dx;Restore y pos
	pop bx;Restore x pos
	
	pop cx
	loop @@ForEachCubeInLength
	
;	Cube #2
	mov dx, [y];Dx = y pos
	inc dx;Dx = y pos of the new rotated piece

	mov cx, [x];Cx = x pos
	add cx, Cube_Size
	add cx, Cube_Size;Cx = x pos of the new rotated piece

	call ReadColor;Read color in pixel (cx,dx)
	cmp al, 0;Check if pixel's color is black, if not --> can't rotate and don't update the value
	jnz @@EndProc
	
	
	;IF CAN ROTATE = UPDATE THE VALUE	
@@UpdateValue:
	mov [CanRotatePieceBool], 1
	
	jmp @@EndProc
@@RecoverPop:
	;To make sure that IP returns to its original value
	pop cx
	pop cx
	pop cx
@@EndProc:
	ret
endp CheckRotateJ3

;	DESCRIPTION: Returns which ASCII number of rotate is next (rotate to next rotation, last rotation returns to rotation zero)
;	OUTPUT: al = ASCII number of next rotate
proc ReturnWhichRotateNext
	;Move to bl current rotation ASCII number
	mov bl, [PieceFileName+1]
	
	;Check which piece is it currently
	mov ah, [PieceFileName]
	cmp ah, 'I'
	jz @@CheckI
	cmp ah, 'O'
	jz @@CheckO
	cmp ah, 'T'
	jz @@CheckT
	cmp ah, 'S'
	jz @@CheckS
	cmp ah, 'Z'
	jz @@CheckZ
	cmp ah, 'L'
	jz @@CheckL
	;ah must be 'J'
	jmp @@CheckJ
	
@@CheckI:
	cmp bl, '0'
	jz @@RotateFrom0I
	;bl = 1 (There are only two options for rotations, 0 or 1...)
	jmp @@RotateFrom1I
@@RotateFrom0I:
	;Change rotation to 1
	mov al, '1'
	jmp @@Cont
@@RotateFrom1I:
	;Change rotation to 0
	mov al, '0'
	jmp @@Cont
	
@@CheckO:
	;THERE IS A SINGLE ROTATION (0)
	mov al, '0'
	jmp @@Cont
	
@@CheckT:
	cmp bl, '0'
	jz @@RotateFrom0T
	cmp bl, '1'
	jz @@RotateFrom1T
	cmp bl, '2'
	jz @@RotateFrom2T
	;bl = 1 (There are only two options for rotations, 0 or 1...)
	jmp @@RotateFrom3T
@@RotateFrom0T:
	;Change rotation to 1
	mov al, '1'
	jmp @@Cont
@@RotateFrom1T:
	;Change rotation to 2
	mov al, '2'
	jmp @@Cont
@@RotateFrom2T:
	;Change rotation to 3
	mov al, '3'
	jmp @@Cont
@@RotateFrom3T:	
	;Change rotation to 0
	mov al, '0'
	jmp @@Cont
	
@@CheckS:
	cmp bl, '0'
	jz @@RotateFrom0S
	;bl = 1 (There are only two options for rotations, 0 or 1...)
	jmp @@RotateFrom1S
@@RotateFrom0S:
	;Change rotation to 1
	mov al, '1'
	jmp @@Cont
@@RotateFrom1S:	
	;Change rotation to 0
	mov al, '0'
	jmp @@Cont
	
@@CheckZ:
	cmp bl, '0'
	jz @@RotateFrom0Z
	;bl = 1 (There are only two options for rotations, 0 or 1...)
	jmp @@RotateFrom1Z
@@RotateFrom0Z:
	;Change rotation to 1
	mov al, '1'
	jmp @@Cont
@@RotateFrom1Z:	
	;Change rotation to 0
	mov al, '0'
	jmp @@Cont
	
@@CheckL:
	cmp bl, '0'
	jz @@RotateFrom0L
	cmp bl, '1'
	jz @@RotateFrom1L
	cmp bl, '2'
	jz @@RotateFrom2L
	;bl = 1 (There are only two options for rotations, 0 or 1...)
	jmp @@RotateFrom3L
@@RotateFrom0L:
	;Change rotation to 1
	mov al, '1'
	jmp @@Cont
@@RotateFrom1L:
	;Change rotation to 2
	mov al, '2'
	jmp @@Cont
@@RotateFrom2L:
	;Change rotation to 3
	mov al, '3'
	jmp @@Cont
@@RotateFrom3L:	
	;Change rotation to 0
	mov al, '0'
	jmp @@Cont
	
@@CheckJ:
	cmp bl, '0'
	jz @@RotateFrom0J
	cmp bl, '1'
	jz @@RotateFrom1J
	cmp bl, '2'
	jz @@RotateFrom2J
	;bl = 1 (There are only two options for rotations, 0 or 1...)
	jmp @@RotateFrom3J
@@RotateFrom0J:
	;Change rotation to 1
	mov al, '1'
	jmp @@Cont
@@RotateFrom1J:
	;Change rotation to 2
	mov al, '2'
	jmp @@Cont
@@RotateFrom2J:
	;Change rotation to 3
	mov al, '3'
	jmp @@Cont
@@RotateFrom3J:	
	;Change rotation to 0
	mov al, '0'
	;jmp @@Cont
	
@@Cont:
	ret
endp ReturnWhichRotateNext
;--


; __  ___ __ _  _  __  
;| _\| __|  \ || |/ _] 
;| v | _|| -< \/ | [/\ 
;|__/|___|__/\__/ \__/ 


; INPUT:
; Ax = wanted number to display
proc ShowAxDecimal
	push ax
	push bx
	push cx
	push dx

	 
	; check if negative
	test ax,08000h
	jz PositiveAx
		
	;  put '-' on the screen
	push ax
	mov dl,'-'
	mov ah,2
	int 21h
	pop ax

	neg ax ; make it positive
PositiveAx:
	mov cx,0   ; will count how many time we did push 
	mov bx,10  ; the divider

put_mode_to_stack:
	xor dx,dx
	div bx
	add dl,30h
	; dl is the current LSB digit 
	; we cant push only dl so we push all dx
	push dx    
	inc cx
	cmp ax,9   ; check if it is the last time to div
	jg put_mode_to_stack

	cmp ax,0
	jz pop_next  ; jump if ax was totally 0
	add al,30h  
	mov dl, al    
	mov ah, 2h
	int 21h        ; show first digit MSB
	   
pop_next: 
	pop ax    ; remove all rest LIFO (reverse) (MSB to LSB)
	mov dl, al
	mov ah, 2h
	int 21h        ; show all rest digits
	loop pop_next
	

	pop dx
	pop cx
	pop bx
	pop ax

	ret
endp ShowAxDecimal


EndOfCsLbl:
END start


