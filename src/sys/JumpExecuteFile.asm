;@DOES Jump execution to an executable file
;@INPUT hl = file to execute
;@INPUT de = arguments
sys_JumpExecuteFile:
	push de,hl
	call sys_ExecuteFile
	pop hl,de
	ret
