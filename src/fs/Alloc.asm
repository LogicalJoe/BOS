;@DOES allocate space for a file
;@INPUT bool fs_Alloc(int len);
fs_Alloc:
	ld hl,-7
	call ti._frameset
	ld hl,(ix+6)
	call fs_CeilDivBySector

	ld (ix-4),l

	ld hl,fs_cluster_map_file
	push hl
	call fs_OpenFile
	pop bc
	jq c,.fail

	ld bc,$C
	add hl,bc
	ld hl,(hl)
	push hl
	call fs_GetSectorAddress
	pop bc
	ld (ix-3),hl
	ld bc,8192
	add hl,bc
	ld (ix-7),hl
	ld hl,(ix-3)
.search_loop_entry:
	ld a,$FF
	ld bc,(ix-7)
.search_loop:
	or a,a
	sbc hl,bc
	jq nc,.garbage_collect ;we've hit the end of the cluster map, and we need to do a garbage collect
	add hl,bc
	cp a,(hl)
	inc hl
	jq nz,.search_loop

	ld (ix-3),hl
	ld b,(ix-4)
	ld a,$FF
.len_loop:
	cp a,(hl)
	inc hl
	jq nz,.search_loop_entry ;area not long enough
	djnz .len_loop
;if we're here, we succeeded :D

	call sys_FlashUnlock

	ld de,(ix-3)
	ld b,(ix-4)
	ld a,$FE
.reserve_loop:
	push af,bc,de
	call sys_WriteFlashByteFull
	pop de,bc,af
	inc de
	djnz .reserve_loop

	call sys_FlashLock

	xor a,a
	db $06 ;ld b,...
.fail:
	scf
	ld sp,ix
	pop ix
	sbc a,a
	ret
.garbage_collect:=.fail ;TODO


