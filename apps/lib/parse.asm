; *** Code ***

; Parse the hex char at A and extract it's 0-15 numerical value. Put the result
; in A.
;
; On success, the carry flag is reset. On error, it is set.
parseHex:
	; First, let's see if we have an easy 0-9 case

	add 	a, 0xc6	; maps '0'-'9' onto 0xf6-0xff
	sub 	0xf6	; maps to 0-9 and carries if not a digit
	ret	nc

	and 	0xdf		; converts lowercase to uppercase
	add	a, 0xe9		; map 0x11-x017 onto 0xFA - 0xFF
	sub 	0xfa		; map onto 0-6
	ret 	c
	; we have an A-F digit
	add	a, 10		; C is clear, map back to 0xA-0xF
	ret


; Parses 2 characters of the string pointed to by HL and returns the numerical
; value in A. If the second character is a "special" character (<0x21) we don't
; error out: the result will be the one from the first char only.
; HL is set to point to the last char of the pair.
;
; On success, the carry flag is reset. On error, it is set.
parseHexPair:
	push	bc

	ld	a, (hl)
	call	parseHex
	jr	c, .end		; error? goto end, keeping the C flag on
	rla \ rla \ rla \ rla	; let's push this in MSB
	ld	b, a
	inc	hl
	ld	a, (hl)
	cp	0x21
	jr	c, .single	; special char? single digit
	call	parseHex
	jr	c, .end		; error?
	or	b		; join left-shifted + new. we're done!
	; C flag was set on parseHex and is necessarily clear at this point
	jr	.end

.single:
	; If we have a single digit, our result is already stored in B, but
	; we have to right-shift it back.
	ld	a, b
	and	0xf0
	rra \ rra \ rra \ rra
	dec	hl

.end:
	pop	bc
	ret

; Parse the decimal char at A and extract it's 0-9 numerical value. Put the
; result in A.
;
; On success, the carry flag is reset. On error, it is set.
; Also, zero flag set if '0'
; parseDecimalDigit has been replaced with the following code inline:
;	add	a, 0xff-'9'	; maps '0'-'9' onto 0xf6-0xff
;	sub	0xff-9		; maps to 0-9 and carries if not a digit

; Parse string at (HL) as a decimal value and return value in IX under the
; same conditions as parseLiteral.
; Sets Z on success, unset on error.
; To parse successfully, all characters following HL must be digits and those
; digits must form a number that fits in 16 bits. To end the number, both \0
; and whitespaces (0x20 and 0x09) are accepted. There must be at least one
; digit in the string.

parseDecimal:
	push 	hl

	ld	a, (hl)
	add	a, 0xff-'9'	; maps '0'-'9' onto 0xf6-0xff
	sub	0xff-9		; maps to 0-9 and carries if not a digit
	jr	c, .error	; not a digit on first char? error
	exx		; preserve bc, hl, de
	ld	h, 0
	ld	l, a	; load first digit in without multiplying
	ld	b, 3	; Carries can only occur for decimals >=5 in length

.loop:
	exx
	inc hl
	ld a, (hl)
	exx

	; inline parseDecimalDigit
	add	a, 0xff-'9'	; maps '0'-'9' onto 0xf6-0xff
	sub	0xff-9		; maps to 0-9 and carries if not a digit
	jr	c, .end

	add	hl, hl	; x2
	ld	d, h
	ld	e, l		; de is x2
	add	hl, hl	; x4
	add	hl, hl	; x8
	add	hl, de	; x10
	ld	d, 0
	ld	e, a
	add	hl, de
	jr	c, .end	; if hl was 0x1999, it may carry here
	djnz	.loop


	inc 	b	; so loop only executes once more
	; only numbers >0x1999 can carry when multiplied by 10.
	ld	de, 0xE666
	ex	de, hl
	add	hl, de
	ex	de, hl
	jr	nc, .loop	; if it doesn't carry, it's small enough

	exx
	inc 	hl
	ld 	a, (hl)
	exx
	add 	a, 0xd0	; the next line expects a null to be mapped to 0xd0
.end:
	; Because of the add and sub in parseDecimalDigit, null is mapped
	; to 0x00+(0xff-'9')-(0xff-9)=-0x30=0xd0
	sub 	0xd0	; if a is null, set Z
			; a is checked for null before any errors
	push	hl \ pop ix
	exx	; restore original de and bc
	pop	hl
	ret	z
	; A is not 0? Ok, but if it's a space, we're happy too.
	jp	isSep
.error:
	pop	hl
	jp	unsetZ
