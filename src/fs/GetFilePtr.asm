;@DOES get a pointer to a file's data section
;@INPUT void *fs_GetFilePtr(const char *path);
;@OUTPUT HL = file data pointer, BC = file data length, A = file flags, Cf set and HL = -1 if failed
fs_GetFilePtr:
	pop bc,hl
	push hl,bc,hl
	call fs_OpenFile
	pop bc
	ret c
	ld bc,$B
	add hl,bc
	ld a,(hl)
	inc hl
	push af
	ld de,(hl)
	push hl,de
	call fs_GetSectorAddress
	ex hl,de
	pop hl,hl
	inc hl
	inc hl
	ld c,(hl)
	inc hl
	ld b,(hl)
	ex hl,de
	pop af
	ret
