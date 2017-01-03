;  Kaylan Mettus 
;  CS 218 - Assignment #11
;  Functions Template

; ***********************************************************************
;  Data declarations
;	Note, the error message strings should NOT be changed.
;	All other variables may changed or ignored...

section	.data

; -----
;  Define standard constants.

LF		equ	10			; line feed
NULL		equ	0			; end of string
SPACE		equ	0x20			; space

TRUE		equ	1
FALSE		equ	0

SUCCESS		equ	0			; Successful operation
NOSUCCESS	equ	1			; Unsuccessful operation

STDIN		equ	0			; standard input
STDOUT		equ	1			; standard output
STDERR		equ	2			; standard error

SYS_read	equ	0			; system call code for read
SYS_write	equ	1			; system call code for write
SYS_open	equ	2			; system call code for file open
SYS_close	equ	3			; system call code for file close
SYS_fork	equ	57			; system call code for fork
SYS_exit	equ	60			; system call code for terminate
SYS_creat	equ	85			; system call code for file open/create
SYS_time	equ	201			; system call code for get time

O_CREAT		equ	0x40
O_TRUNC		equ	0x200
O_APPEND	equ	0x400

O_RDONLY	equ	000000q			; file permission - read only
O_WRONLY	equ	000001q			; file permission - write only
O_RDWR		equ	000002q			; file permission - read and write

S_IRUSR		equ	00400q
S_IWUSR		equ	00200q
S_IXUSR		equ	00100q

; -----
;  Define program specific constants.

GRAYSCALE	equ	1
BRIGHTEN	equ	2
DARKEN		equ	3

MIN_FILE_LEN	equ	5
BUFF_SIZE	equ	500000			; buffer size
;BUFF_SIZE	equ	3			; buffer size

; -----
;  Local variables for getOptions() procedure.

eof		db	FALSE

usageMsg	db	"Usage: ./image <-gr|-br|-dk> <inputFile.bmp> "
		db	"<outputFile.bmp>", LF, NULL
errIncomplete	db	"Error, incomplete command line arguments.", LF, NULL
errExtra	db	"Error, too many command line arguments.", LF, NULL
errOption	db	"Error, invalid image processing option.", LF, NULL
errReadSpec	db	"Error, invalid read specifier.", LF, NULL
errWriteSpec	db	"Error, invalid write specifier.", LF, NULL
errReadName	db	"Error, invalid source file name.  Must be '.bmp' file.", LF, NULL
errWriteName	db	"Error, invalid output file name.  Must be '.bmp' file.", LF, NULL
errReadFile	db	"Error, unable to open input file.", LF, NULL
errWriteFile	db	"Error, unable to open output file.", LF, NULL

; -----
;  Local variables for readHeader() procedure.

HEADER_SIZE	equ	54

errReadHdr	db	"Error, unable to read header from source image file."
		db	LF, NULL
errFileType	db	"Error, invalid file signature.", LF, NULL
errDepth	db	"Error, unsupported color depth.  Must be 24-bit color."
		db	LF, NULL
errCompType	db	"Error, only non-compressed images are supported."
		db	LF, NULL
errSize		db	"Error, bitmap block size inconsistant.", LF, NULL
errWriteHdr	db	"Error, unable to write header to output image file.", LF,
		db	"Program terminated.", LF, NULL

; -----
;  Local variables for getRow() procedure.

buffMax		dq	BUFF_SIZE
curr		dq	BUFF_SIZE
wasEOF		db	FALSE
pixelCount	dq	0

errRead		db	"Error, reading from source image file.", LF,
		db	"Program terminated.", LF, NULL

; -----
;  Local variables for writeRow() procedure.

errWrite	db	"Error, writting to output image file.", LF,
		db	"Program terminated.", LF, NULL


; ------------------------------------------------------------------------
;  Unitialized data

section	.bss

buffer		resb	BUFF_SIZE
header		resb	HEADER_SIZE


; ############################################################################

section	.text

extern	printString				; Utility print string function

; ***************************************************************
;  Routine to get arguments.
;	Verify files by atemptting to open the files (to make
;	sure they are valid and available).

;  Command Line format:
;	./image <-gr|-br|-dk> <inputFileName> <outputFileName>

; -----
;  Arguments:
;	argc (value)
;	argv table (address)
;	image option variable (address)
;	read file descriptor (address)
;	write file descriptor (address)
;  Returns:
;	SUCCESS or NOSUCCESS

global	getArguments
getArguments:
	
	push rbx
	push r12
	push r13
	push r14

; check if command args entered
; if argc == 1
	cmp rdi, 1
	je usageErr

; if argc < 4
	cmp rdi, 4
	jl lessThanErr
	
; if argc > 4
	cmp rdi, 4
	jg greaterThanErr
	
; check argv[1]
	mov rbx, qword [rsi + 8]
	cmp byte [rbx], '-'
	jne imageSpecErr
;cmp "-gr"
	cmp byte [rbx + 1], 'g'
	jne check2
	cmp byte [rbx + 2], 'r'
	je nullCheck
;cmp "-br"
check2:
	cmp byte [rbx + 1], 'b'
	jne check3
	cmp byte [rbx + 2], 'r'
	je nullCheck
;cmp "-dk"
check3:
	cmp byte [rbx + 1], 'd'
	jne imageSpecErr
	cmp byte [rbx + 2], 'k'
	jne imageSpecErr
nullCheck:
	cmp byte [rbx + 3], NULL
	jne imageSpecErr
mov qword [rdx], rbx ; save image option


;check argv[2]
;cmp file name
	mov rbx, [rsi + 16]
	mov r10, 0
	inFileLp:
		inc r10
		cmp byte [rbx + r10], NULL
		jne inFileLp ; find end of string
	cmp r10, 5
	jl inTypeErr
	dec r10
	cmp byte [rbx + r10], 'p' ; check last 4 char for .bmp
	jne inTypeErr
	dec r10
	cmp byte [rbx + r10], 'm'
	jne inTypeErr
	dec r10
	cmp byte [rbx + r10], 'b'
	jne inTypeErr
	dec r10
	cmp byte [rbx + r10], '.'
	jne inTypeErr	
	;try to open file
	mov r12, rsi ; save registers
	mov r13, rdx
	mov r14, rcx
	mov rax, SYS_open
	mov rdi, qword [rsi + 16]
	mov rsi, O_RDONLY
	syscall
	mov rsi, r12
	mov rdx, r13
	mov rcx, r14
	;check if successful
	cmp rax, 0
	jl invalidInFile
	mov qword [rcx], rax ; save descriptor	

;check argv[3]
;cmp file name
	mov rbx, [rsi + 24]
	mov r10, 0
	outFileLp:
		inc r10
		cmp byte [rbx + r10], NULL
		jne outFileLp ; find end of string
	cmp r10, 5
	jl outTypeErr
	dec r10
	cmp byte [rbx + r10], 'p' ; check last 4 char for .bmp
	jne outTypeErr
	dec r10
	cmp byte [rbx + r10], 'm'
	jne outTypeErr
	dec r10
	cmp byte [rbx + r10], 'b'
	jne outTypeErr
	dec r10
	cmp byte [rbx + r10], '.'
	jne outTypeErr	
;try to open file
	mov r12, rsi ; save registers
	mov r13, rdx
	mov r14, rcx
	mov rax, SYS_creat
	mov rdi, qword [rsi + 24]
	mov rsi, S_IRUSR | S_IWUSR
	syscall
	mov rsi, r12
	mov rdx, r13
	mov rcx, r14
	;check if successful
	cmp rax, 0
	jl invalidOutFile
	mov qword [r8], rax ; save descriptor

	jmp valid ; all args correct and saved
	
; print errors
; error for only program name entered
usageErr:
	mov rdi, usageMsg
	call printString
	jmp notValid

; too many args
greaterThanErr:
	mov rdi, errExtra
	call printString
	jmp notValid

; too few args
lessThanErr:
	mov rdi, errIncomplete
	call printString
	jmp notValid
	
; incorrect image manipulation specifier
imageSpecErr:
	mov rdi, errOption
	call printString
	jmp notValid

; invalid input file type
inTypeErr:
	mov rdi, errReadName
	call printString
	jmp notValid

; invalid input file name
invalidInFile:
	mov rdi, errReadFile
	call printString
	jmp notValid

; invalid output file type
outTypeErr:
	mov rdi, errWriteName
	call printString
	jmp notValid

; invalid output file name
invalidOutFile:
	mov rdi, errWriteFile
	call printString
	jmp notValid

notValid:
	mov eax, NOSUCCESS
	jmp argsDone
valid:
	mov eax, SUCCESS
argsDone:

	pop r14
	pop r13
	pop r12
	pop rbx
	ret

; ***************************************************************
;  Read and verify header information
;	status = readHeader(readFileDesc, writeFileDesc,
;				fileSize, picWidth, picHeight)

; -----
;  2 -> BM				(+0)
;  4 file size				(+2)
;  4 skip				(+6)
;  4 header size			(+10)
;  4 skip				(+14)
;  4 width				(+18)
;  4 height				(+22)
;  2 skip				(+26)
;  2 depth (16/24/32)			(+28)
;  4 compression method code		(+30)
;  4 bytes of pixel data		(+34)
;  skip remaing header entries

; -----
;   Arguments:
;	read file descriptor (value)
;	write file descriptor (value)
;	file size (address)
;	image width (address)
;	image height (address)

;  Returns:
;	file size (via reference)
;	image width (via reference)
;	image height (via reference)
;	SUCCESS or NOSUCCESS

global	readHeader
readHeader:

	push r12
	push r13
	
	;save args
	mov r12, rdi
	mov r13, rsi
	;read file
	mov rax, SYS_read
	;read file desc already in rdi
	mov rsi, header ; chars read will go here
	mov rdx, HEADER_SIZE ;header is 54 bytes
	syscall
	mov rdi, r12
	mov rsi, r13
	cmp rax, HEADER_SIZE ;if read failed
	jne readErr
	
	;if successful read, start to verify header
	;check file sig
	cmp byte [header], 'B'
	jne sigErr
	cmp byte [header + 1], 'M'
	jne sigErr
	
	mov r10d, dword [header + 2] ;file size
	
	;check color depth
	cmp word [header + 28], 24
	jne colorDepthErr
	
	;check compression
	cmp dword [header + 30], 0
	jne compressionErr
	
	;check file size
	mov r11d, dword [header + 34] ; image size
	add r11d, HEADER_SIZE ;header size + image size
	cmp r11d, r10d ; cmp against file size
	jne fileSizeErr
	
	;save args
	mov r12, rdi
	mov r13, rsi
	;write header to output file
	mov rax, SYS_write
	mov rdi, rsi ;write file desc
	mov rsi, header ; header data
	mov rdx, HEADER_SIZE ; header data is 54 bytes
	syscall
	mov rdi, r12
	mov rsi, r13
	cmp rax, 0 ;if write failed
	jl writeErr
	jmp goodHeader
	
	;print errors
	;couldn't read file
	readErr:
		mov rdi, errReadHdr
		call printString
		jmp badHeader
	
	; invalid signature
	sigErr:
		mov rdi, errFileType
		call printString
		jmp badHeader
	
	;invalid color depth
	colorDepthErr:
		mov rdi, errDepth
		call printString
		jmp badHeader
	
	;use of compression
	compressionErr:
		mov rdi, errCompType
		call printString
		jmp badHeader
	
	;incorrect file size
	fileSizeErr:
		mov rdi, errSize
		call printString
		jmp badHeader
		
	;couldn't write to file
	writeErr:
		mov rdi, errWriteHdr
		call printString
		jmp badHeader
	
	badHeader:
		mov rax, NOSUCCESS
		jmp headerDone
	goodHeader:
		mov edx, dword [header + 2] ;save file size
		mov ecx,dword [header + 18] ;save width
		mov r8d, dword [header + 22] ;save height
		mov rax, SUCCESS
	headerDone:
	
	pop r13
	pop r12
	pop rbx
	ret

; ***************************************************************
;  Return a row from read buffer
;	This routine performs all buffer management

; ----
;  HLL Call:
;	status = readRow(readFileDesc, picWidth, rowBuffer);

;   Arguments:
;	read file descriptor (value)
;	image width (value)
;	row buffer (address)
;  Returns:
;	SUCCESS or NOSUCCESS

; -----
;  This routine returns SUCCESS when row has been returned
;	and returns NOSUCCESS only if there is an
;	error on write (which would not normally occur).

;  The read buffer itself and some misc. variables are used
;  ONLY by this routine and as such are not passed.

global	getRow
getRow:

	push rbx
	push r12
	push r13
	push r14

	mov rbx, 0 ;i = 0
	getNextChr:
		;if (curr >= buffMax)
		cmp dword [curr], dword [buffMax]
		jl fillBuff
		;read file
		mov r13, rsi ;save args
		mov r14, rdx
		mov rax, SYS_read
		;file desc already in rdi
		mov rsi, buffer
		mov rdx, BUFF_SIZE
		syscall
		mov rsi, r13
		mov r14, rdx
		cmp rax, 0 ;if error
		jl badRead ;print errormsg/exit
		cmp rax, 0 ;if actual read == 0
		je EOF ;exit (no error)
		cmp rax, BUFF_SIZE ;if (actual < requested)
		jl notEOF
		mov byte [wasEOF], TRUE ;wasEOF = TRUE
	notEOF:
		mov dword [curr], 0 ;curr = 0
		
	fillBuff:
		mov r12b, byte [buffer + curr] ;chr = buffer[curr]
		mov byte [rdx + rbx], r12b ;rowBuff[i] = chr
		inc dword [curr] ;curr++
		inc rbx ;i++
		mov eax, rdi
		mov r10, 3
		imul r10d ; width * 3
		mov dword [pixelCount], eax ;move result in pixelCount
		mov dword [pixelCount + 4], edx ; check this
		cmp rbx, qword [pixelCount] ;if (i < width * 3)
		jl getNextChr
		
	badRead:
		mov rdi, errRead
		call printString
	EOF:
		mov rax, NOSUCCESS
		jmp readExit
		
	readDone:
		mov rax, SUCCESS
	readExit:

	pop r14
	pop r13
	pop r12
	pop rbx

	ret

; ***************************************************************
;  Write image row to output file.
;	Writes exactly (width*3) bytes to file.
;	No requirement to buffer here.

; -----
;  HLL Call:
;	status = writeRow(writeFileDesc, pciWidth, rowBuffer);

;  Arguments are:
;	write file descriptor (value)
;	image width (value)
;	row buffer (address)

;  Returns:
;	SUCCESS or NOSUCESS

; -----
;  This routine returns SUCCESS when row has been written
;	and returns NOSUCCESS only if there is an
;	error on write (which would not normally occur).

;  The read buffer itself and some misc. variables are used
;  ONLY by this routine and as such are not passed.

global	writeRow
writeRow:

	push rbx
	push r12
	
	mov eax, dword [rsi]
	mov rbx, 3 
	imul rbx ;write length = width * 3 bytes
	mov ebx, edx
	rol ebx, 32 ;check this part
	or ebx, eax

	;write to file
	mov r12, rdx ;save arg
	mov rax, SYS_write
	;file desc already in rdi
	mov rsi, rdx ;rowBuffer
	mov rdx, rbx ;write length
	syscall
	mov rdx, r12

	cmp rax, rbx ;if write failed
	jl badWrite
	mov rax, SUCCESS
	jmp writeDone

badWrite:
	;print error
	mov rdi, writeErr
	call printString
	mov rax, NOSUCCESS
writeDone:

	pop r12
	pop rbx
	ret

; ***************************************************************
;  Convert pixels to grayscale.

; -----
;  HLL Call:
;	status = imageCvtToBW(picWidth, rowBuffer);

;  Arguments are:
;	image width (value)
;	row buffer (address)
;  Returns:
;	updated row buffer (via reference)

global	imageCvtToBW
imageCvtToBW:

	push rbx

	mov rbx, rdx
	mov r10, 0 ;counter
	
greyLp:
	mov rax, 0
	;sum the 3 color values
	mov al, byte [rbx + r10]
	add al, byte [rbx + r10 + 1]
	add al, byte [rbx + r10 + 2]
	;divide by 3
	mov r11, 3
	idiv r11w
	;replace pixel with new value
	mov byte [rbx + r10], al
	mov byte [rbx + r10 + 1], al
	mov byte [rbx + r10 + 2], al
	add r10, 3 ;move to next 3 bytes
	dec rsi
	cmp rsi, 0 ;when entire buffer has been processed
	jg greyLp
	mov rdx, rbx ;save new buffer
	
	pop rbx
	ret

; ***************************************************************
;  Update pixels to increase brightness

; -----
;  HLL Call:
;	status = imageBrighten(picWidth, rowBuffer);

;  Arguments are:
;	image width (value)
;	row buffer (address)
;  Returns:
;	updated row buffer (via reference)

global	imageBrighten
imageBrighten:

	push rbx

	mov rbx, rdx
	mov r10, 0 ;counter
	
brightLp:
	mov rax, 0
	;find new color value
	movzx eax, byte [rbx + r10]
	mov r11, 2 ;divide by 2
	idiv r11d
	add ax, byte [rbx + r10] ; add initial color value
	cmp ax, 255
	jle noReset:
	mov rax, 255
noReset:
	mov byte [rbx + r10], al ;replace pixel with new value
	inc r10 ;move to next byte
	dec rsi
	cmp rsi, 0 ;when entire buffer has been processed
	jg brightLp
	mov rdx, rbx ;save new buffer

	pop rbx
	ret

; ***************************************************************
;  Update pixels to darken (decrease brightness)

; -----
;  HLL Call:
;	status = imageDarken(picWidth, rowBuffer);

;  Arguments are:
;	image width (value)
;	row buffer (address)
;  Returns:
;	updated row buffer (via reference)

global	imageDarken
imageDarken:

	push rbx

	mov rbx, rdx
	mov r10, 0 ;counter
	
darkLp:
	mov rax, 0
	;find new color value
	movzx ax, byte [rbx + r10]
	;divide by 2
	mov r11, 2
	idiv r11w
	mov byte [rbx + r10], al ;replace pixel with new value
	inc r10 ;move to next byte
	dec rsi
	cmp rsi, 0 ;when entire buffer has been processed
	jg darkLp
	mov rdx, rbx ;save new buffer

	pop rbx

	ret

; ***************************************************************
