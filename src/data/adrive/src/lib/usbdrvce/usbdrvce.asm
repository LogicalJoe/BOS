;-------------------------------------------------------------------------------
include '../include/library.inc'
;-------------------------------------------------------------------------------

library 'USBDRVCE', 0

;-------------------------------------------------------------------------------
; no dependencies
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; v0 functions (not final, subject to change!)
;-------------------------------------------------------------------------------
	export usb_Init
	export usb_Cleanup
	export usb_PollTransfers
	export usb_HandleEvents
	export usb_WaitForEvents
	export usb_WaitForInterrupt
	export usb_RefDevice
	export usb_UnrefDevice
	export usb_GetDeviceHub
	export usb_SetDeviceData
	export usb_GetDeviceData
	export usb_GetDeviceFlags
	export usb_FindDevice
	export usb_ResetDevice
	export usb_DisableDevice
	export usb_GetDeviceAddress
	export usb_GetDeviceSpeed
	export usb_GetConfigurationDescriptorTotalLength
	export usb_GetDescriptor
	export usb_SetDescriptor
	export usb_GetStringDescriptor
	export usb_SetStringDescriptor
	export usb_GetConfiguration
	export usb_SetConfiguration
	export usb_GetInterface
	export usb_SetInterface
	export usb_ClearEndpointHalt
	export usb_GetDeviceEndpoint
	export usb_GetEndpointDevice
	export usb_SetEndpointData
	export usb_GetEndpointData
	export usb_GetEndpointAddress
	export usb_GetEndpointTransferType
	export usb_GetEndpointMaxPacketSize
	export usb_SetEndpointFlags
	export usb_GetEndpointFlags
	export usb_GetRole
	export usb_GetFrameNumber
	export usb_ControlTransfer
	export usb_Transfer
	export usb_ScheduleControlTransfer
	export usb_ScheduleTransfer
	export usb_StartTimer
	export usb_RepeatTimer
	export usb_StartCycleTimer
	export usb_RepeatCycleTimer
	export usb_GetCycleCounter
	export usb_GetCycleCounterHigh

;-------------------------------------------------------------------------------
; macros
;-------------------------------------------------------------------------------
macro ?!
 macro assertpo2? value*
  local val
  val = value
  if ~val | val <> 1 shl bsr val
   err '"', `value, '" is not a power of two'
  end if
 end macro

 iterate op, bit, res, set
  macro op#msk? index*, value
   local idx, val, rest
   idx = index
   assertpo2 idx
   match @, value
    val equ value
   else
    val equ
    rest equ index
    while 1
     match car.cdr, rest
      match any, val
       val equ any.car
      else
       val equ car
      end match
      rest equ cdr
     else
      val equ (val)
      break
     end match
    end while
   end match
   match v, val
	op	bsr idx,v
   end match
  end macro
 end iterate

 macro struct? name*
  macro end?.struct?!
      iterate base, ., .base
       if defined base
        assert base+sizeof base=$
       end if
      end iterate
    end namespace
   end struc
   iterate <base,prefix>, 0,, ix-name,x, iy-name,y
    virtual at base
	prefix#name	name
    end virtual
   end iterate
   purge end?.struct?
  end macro
  struc name
   namespace .
 end macro

 purge ?
end macro

;-------------------------------------------------------------------------------
; memory structures
;-------------------------------------------------------------------------------
struct transfer			; transfer structure
	label .: 32
	next		rd 1	; pointer to next transfer structure
 namespace next
	dummy		:= 1 shl 0
 end namespace
	altNext		rd 1	; pointer to alternate next transfer structure
	status		rb 1	; transfer status
 namespace status
	active		:= 1 shl 7
	halted		:= 1 shl 6
	bufErr		:= 1 shl 5
	babble		:= 1 shl 4
	xactErr		:= 1 shl 3
	ufMiss		:= 1 shl 2
	split		:= 1 shl 1
	stall		:= 1 shl 0
 end namespace
	type		rb 1
 namespace type
	ioc		:= 1 shl 7
	cpage		:= 7 shl 4
	cerr		:= 3 shl 2
	pid		:= 3 shl 0
 end namespace
	remaining	rw 1	; transfer remaining length
 namespace remaining
	?dt		:= 1 shl 15
 end namespace
	label buffers: 20	; transfer buffers
			rl 1
	length		rl 1	; original transfer length
	callback	rd 1	; user callback
	data		rd 1	; user callback data
	endpoint	rd 1	; pointer to endpoint structure
	padding		rb 1
	fifo		rb 1	; associated fifo mask
end struct
struct endpoint			; endpoint structure
	label base: 64
	label .: 62 at $+2
	next		rl 1	; link to next endpoint structure
	prev		rb 1	; link to prev endpoint structure
	addr		rb 1	; device addr or cancel shl 7
	info		rb 1	; ep or speed shl 4 or dtc shl 6
 namespace info
	head		:= 1 shl 7
	dtc		:= 1 shl 6
	eps		:= 3 shl 4
	ep		:= $F
 end namespace
	maxPktLen	rw 1	; max packet length or c shl 15 or 1 shl 16
 namespace maxPktLen
	control		:= 1 shl 11
 end namespace
	smask		rb 1	; micro-frame s-mask
	cmask		rb 1	; micro-frame c-mask
	hubInfo		rw 1	; hub addr or port num shl 7 or mult shl 14
	cur		rd 1	; current transfer pointer
	overlay		transfer; current transfer
	type		rb 1	; transfer type
	dir		rb 1	; transfer dir
	flags		rb 1	; endpoint flags
	internalFlags	rb 1	; internal endpoint flags
	first		rl 1	; pointer to first scheduled transfer
	last		rl 1	; pointer to last dummy transfer
	data		rl 1	; user data
	device		rl 1	; pointer to device
end struct
struct device			; device structure
	label .: 32
	endpoints	rl 1	; pointer to array of endpoints
	find		rb 1	; find flags
	refcount	rl 1	; reference count
	hubPorts	rb 1	; number of ports in this hub
	sibling		rl 1	; next device connected to the same hub
	speed		rb 1	; device speed shl 4
	back		rl 1	; update pointer to next pointer to self
			rb 1	; padding
	addr		rb 1	; device addr and $7F
	child		rl 1	; first device connected to this hub
	hub		rl 1	; hub this device is connected to
	info		rw 1	; hub addr or port number shl 7 or 1 shl 14
	data		rl 1	; user data
			rd 1
end struct
struct setup
	label .: 8
	bmRequestType	rb 1
	bRequest	rb 1
	wValue		rw 1
	wIndex		rw 1
	wLength		rw 1
end struct
struct standardDescriptors
	local size
	label .: size
	device		rl 1
	configurations	rl 1
	langids		rl 1
	numStrings	rb 1
	strings		rl 1
	size := $-.
end struct
struct descriptor
	label .: 2
	bLength			rb 1
	bDescriptorType		rb 1
end struct
struct deviceDescriptor
	label .: 18
	descriptor		descriptor
	bcdUSB			rw 1
	bDeviceClass		rb 1
	bDeviceSubClass		rb 1
	bDeviceProtocol		rb 1
	bMaxPacketSize0		rb 1
	idVendor		rw 1
	idProduct		rw 1
	bcdDevice		rw 1
	iManufacturer		rb 1
	iProduct		rb 1
	iSerialNumber		rb 1
	bNumConfigurations	rb 1
end struct
struct deviceQualifierDescriptor
	label .: 10
	descriptor		descriptor
	bcdUSB			rw 1
	bDeviceClass		rb 1
	bDeviceSubClass		rb 1
	bDeviceProtocol		rb 1
	bMaxPacketSize0		rb 1
	bNumConfigurations	rb 1
	bReserved		rb 1
end struct
struct configurationDescriptor
	label .: 9
	descriptor		descriptor
	wTotalLength		rw 1
	bNumInterfaces		rb 1
	bConfigurationValue	rb 1
	iConfiguration		rb 1
	bmAttributes		rb 1
	bMaxPower		rb 1
end struct
otherSpeedConfigurationDescriptor equ configurationDescriptor
struct interfaceDescriptor
	label .: 9
	descriptor		descriptor
	bInterfaceNumber	rb 1
	bAlternateSetting	rb 1
	bNumEndpoints		rb 1
	bInterfaceClass		rb 1
	bInterfaceSubClass	rb 1
	bInterfaceProtocol	rb 1
	iInterface		rb 1
end struct
struct endpointDescriptor
	label .: 7
	descriptor		descriptor
	bEndpointType		rb 1
	bmAttributes		rb 1
	wMaxPacketSize		rw 1
	bInterval		rb 1
end struct
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; memory locations
;-------------------------------------------------------------------------------
virtual at (saveSScreen+$FFFF) and not $FFFF
	cHeap			dbx (saveSScreen+21945) and not $FF - $: ?
end virtual
virtual at usbArea
				rb (-$) and 7
	?setupPacket		setup
				rb (-$) and $1F
	?rootHub		device
				rb (-$) and $FFF
; FIXME: 0xD141B2 is used by GetCSC :(
	?periodicList		dbx $400: ?
	?usbMem			dbx usbInited and not $FF - $: ?
				rb (-$) and $FF
	?dummyHead		endpoint
				rb (-$) and $1F
	?usedAddresses		dbx 128/8: ?
	?eventCallback		rl 1
	?eventCallback.data	rl 1
	?currentDescriptors	rl 1
	?selectedConfiguration	rb 1
	?deviceStatus		rb 1
	?tempEndpointStatus	rw 1
	?currentRole		rb 1
	?freeList32Align32	rl 1
	?freeList64Align256	rl 1
assert $+1 = cleanupListReady
				rb 1 ; clobber
	?cleanupListReady	rb 1
assert cleanupListReady+1 = cleanupListPending
	?cleanupListPending	rb 1
assert cleanupListPending+1 = $
				rb 1 ; always -1
	assert $ <= usbInited
end virtual
virtual at (ramCodeTop+$FF) and not $FF
	osHeap			dbx heapTop and not $FF - $: ?
end virtual
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; usb constants
;-------------------------------------------------------------------------------
; enum usb_error
virtual at 0
	USB_SUCCESS		rb 1
	USB_IGNORE		rb 1
	USB_ERROR_SYSTEM	rb 1
	USB_ERROR_INVALID_PARAM	rb 1
	USB_ERROR_SCHEDULE_FULL	rb 1
	USB_ERROR_NO_DEVICE	rb 1
	USB_ERROR_NO_MEMORY	rb 1
	USB_ERROR_NOT_SUPPORTED	rb 1
	USB_ERROR_TIMEOUT	rb 1
	USB_ERROR_FAILED	rb 1
end virtual

; enum usb_transfer_status
?USB_TRANSFER_COMPLETED		:= 0
?USB_TRANSFER_STALLED		:= 1 shl 0
?USB_TRANSFER_NO_DEVICE		:= 1 shl 1
?USB_TRANSFER_HOST_ERROR		:= 1 shl 2
?USB_TRANSFER_ERROR		:= 1 shl 3
?USB_TRANSFER_OVERFLOW		:= 1 shl 4
?USB_TRANSFER_BUS_ERROR		:= 1 shl 5
?USB_TRANSFER_FAILED		:= 1 shl 6
?USB_TRANSFER_CANCELLED		:= 1 shl 7

; enum usb_event
virtual at 0
	USB_ROLE_CHANGED_EVENT					rb 1
	USB_DEVICE_DISCONNECTED_EVENT				rb 1
	USB_DEVICE_CONNECTED_EVENT				rb 1
	USB_DEVICE_DISABLED_EVENT				rb 1
	USB_DEVICE_ENABLED_EVENT				rb 1
	USB_DEVICE_OVERCURRENT_DEACTIVATED_EVENT		rb 1
	USB_DEVICE_OVERCURRENT_ACTIVATED_EVENT			rb 1
	USB_DEFAULT_SETUP_EVENT					rb 1
	USB_HOST_CONFIGURE_EVENT				rb 1
	; Temp debug events:
	USB_DEVICE_INTERRUPT					rb 1
	USB_DEVICE_CONTROL_INTERRUPT				rb 1
	USB_DEVICE_DEVICE_INTERRUPT				rb 1
	USB_OTG_INTERRUPT					rb 1
	USB_HOST_INTERRUPT					rb 1
	USB_CONTROL_ERROR_INTERRUPT				rb 1
	USB_CONTROL_ABORT_INTERRUPT				rb 1
	USB_FIFO0_SHORT_PACKET_INTERRUPT			rb 1
	USB_FIFO1_SHORT_PACKET_INTERRUPT			rb 1
	USB_FIFO2_SHORT_PACKET_INTERRUPT			rb 1
	USB_FIFO3_SHORT_PACKET_INTERRUPT			rb 1
	USB_DEVICE_SUSPEND_INTERRUPT				rb 1
	USB_DEVICE_RESUME_INTERRUPT				rb 1
	USB_DEVICE_ISOCHRONOUS_ERROR_INTERRUPT			rb 1
	USB_DEVICE_ISOCHRONOUS_ABORT_INTERRUPT			rb 1
	USB_DEVICE_DMA_FINISH_INTERRUPT				rb 1
	USB_DEVICE_DMA_ERROR_INTERRUPT				rb 1
	USB_DEVICE_IDLE_INTERRUPT				rb 1
	USB_DEVICE_WAKEUP_INTERRUPT				rb 1
	USB_B_SRP_COMPLETE_INTERRUPT				rb 1
	USB_A_SRP_DETECT_INTERRUPT				rb 1
	USB_A_VBUS_ERROR_INTERRUPT				rb 1
	USB_B_SESSION_END_INTERRUPT				rb 1
	USB_OVERCURRENT_INTERRUPT				rb 1
	USB_HOST_PORT_CONNECT_STATUS_CHANGE_INTERRUPT		rb 1
	USB_HOST_PORT_ENABLE_DISABLE_CHANGE_INTERRUPT		rb 1
	USB_HOST_PORT_OVERCURRENT_CHANGE_INTERRUPT		rb 1
	USB_HOST_PORT_FORCE_PORT_RESUME_INTERRUPT		rb 1
	USB_HOST_FRAME_LIST_ROLLOVER_INTERRUPT			rb 1
	USB_HOST_SYSTEM_ERROR_INTERRUPT				rb 1
end virtual

; enum usb_find_flag
?IS_NONE		:= 0
?IS_DISABLED		:= 1 shl 0
?IS_ENABLED		:= 1 shl 1
?IS_DEVICE		:= 1 shl 2
?IS_HUB			:= 1 shl 3
?IS_ATTACHED		:= 1 shl 4

; enum usb_endpoint_flag
?MANUAL_TERMINATE	:= 0 shl 0
?AUTO_TERMINATE		:= 1 shl 0

; enum usb_internal_endpoint_flag
?PO2_MPS		:= 1 shl 0

; enum usb_role
virtual at 0
	?ROLE_HOST				rb 1 shl 4
	?ROLE_DEVICE				rb 1 shl 4
end virtual
virtual at 0
	?ROLE_A					rb 1 shl 5
	?ROLE_B					rb 1 shl 5
end virtual

; enum usb_transfer_direction
virtual at 0
	?HOST_TO_DEVICE				rb 1 shl 7
	?DEVICE_TO_HOST				rb 1 shl 7
end virtual

; enum usb_request_type
virtual at 0
	?STANDARD_REQUEST			rb 1 shl 5
	?CLASS_REQUEST				rb 1 shl 5
	?VENDOR_REQUEST				rb 1 shl 5
end virtual

; enum usb_recipient
virtual at 0
	?RECIPIENT_DEVICE			rb 1 shl 0
	?RECIPIENT_INTERFACE			rb 1 shl 0
	?RECIPIENT_ENDPOINT			rb 1 shl 0
	?RECIPIENT_OTHER			rb 1 shl 0
end virtual

; enum usb_request
virtual at 0
	?GET_STATUS				rb 1
	?CLEAR_FEATURE				rb 1
						rb 1
	?SET_FEATURE				rb 1
						rb 1
	?SET_ADDRESS				rb 1
	?GET_DESCRIPTOR				rb 1
	?SET_DESCRIPTOR				rb 1
	?GET_CONFIGURATION			rb 1
	?SET_CONFIGURATION			rb 1
	?GET_INTERFACE				rb 1
	?SET_INTERFACE				rb 1
	?SYNC_FRAME				rb 1
end virtual

; enum usb_feature
virtual at 0
	?ENDPOINT_HALT				rb 1
	?DEVICE_REMOTE_WAKEUP			rb 1
	?TEST_MODE				rb 1
end virtual

; enum usb_descriptor_type
virtual at 1
	?DEVICE_DESCRIPTOR			rb 1
	?CONFIGURATION_DESCRIPTOR		rb 1
	?STRING_DESCRIPTOR			rb 1
	?INTERFACE_DESCRIPTOR			rb 1
	?ENDPOINT_DESCRIPTOR			rb 1
end virtual

; enum usb_transfer_type
virtual at 0
	?CONTROL_TRANSFER			rb 1
	?ISOCHRONOUS_TRANSFER			rb 1
	?BULK_TRANSFER				rb 1
	?INTERRUPT_TRANSFER			rb 1
end virtual

DEFAULT_RETRIES := 10
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
usb_Init:
	call	_usb_DisableTimer
;	call	_os_GetSystemInfo
;	ld	de,4
;	add	hl,de
;	bit	0,(hl)
;	jq	z,.84pce
;	ld	a,$60
;	ld	(_DefaultStandardDescriptors.device+deviceDescriptor.bcdDevice),a
;	ld	hl,_DefaultStandardDescriptors.string83
;	ld	(_DefaultStandardDescriptors.model),hl
;.84pce:
	ld	a,1 ; mark pointers as invalid
	call	_Init
	set	5,(hl)
	ld	hl,mpTmr2Load
	ld	c,12
	call	bos._MemClear
	ld	l,tmrCtrl+1
	set	bTmr2CountUp-8,(hl)
	dec	l;tmrCtrl
	res	bTmr2Crystal,(hl)
	res	bTmr2Overflow,(hl)
	set	bTmr2Enable,(hl)
	sbc	hl,hl
assert deviceStatus+1 = tempEndpointStatus
	ld	(deviceStatus),hl
	dec	hl
	ld	(cleanupListReady),hl
	inc	hl
	ld	(rootHub.addr),a
	ld	(rootHub.data),hl
	ld	de,usedAddresses+1
	ld	b,sizeof usedAddresses-1
.freeAddresses:
	ld	(de),a;0
	inc	de
	djnz	.freeAddresses
	ld	l,3
	add	hl,sp
;	ld	de,eventCallback;eventCallback.data,currentDescriptors
	ld	c,9
	ldir
	ld	e,(hl)
	dec	bc
	ld	hl,(currentDescriptors)
	add	hl,bc
	jq	c,.nonDefaultStandardDescriptors
	ld	hl,_DefaultStandardDescriptors
	ld	(currentDescriptors),hl
.nonDefaultStandardDescriptors:
	ld	hl,mpUsbFifo0Cfg
	ld	(hl),a;0
	inc	l;usbFifo1Cfg-$100
	inc	bc
	ld	(hl),bc;0
	ld	l,usbFifo0Map-$100
	ld	(hl),$01
	inc	l;usbFifo1Map-$100
	ld	bc,$040302
	ld	(hl),bc
	ld	l,usbEp1Map-$100
	ld	(hl),a;$00
	inc	l;usbEp2Map-$100
	ld	bc,$332211
	ld	(hl),bc
	ld	l,usbIdle-$100
	ld	(hl),7
	ld	l,h;usbDevCtrl+1-$100
	ld	(hl),bmUsbDevForceFullSpd shr 8
	dec	l;usbDevCtrl-$100
	ld	(hl),bmUsbDevReset or bmUsbDevEn or bmUsbGirqEn or bmUsbRemoteWake
	ld	l,usbPhyTmsr-$100
	ld	(hl),bmUsbUnplug
	ld	l,usbGimr-$100
	ld	(hl),a;0
	ld	l,usbCxImr-$100
	ld	(hl),a;0
	ld	l,usbFifoRxImr-$100
	ld	(hl),a;0
	ld	l,usbFifoTxImr-$100
	ld	(hl),bmUsbFifoTxInts
	ld	l,usbDevImr-$100
	ld	(hl),a;0
	inc	l;usbDevImr+1-$100
	ld	(hl),bmUsbIntDevIdle shr 8
	dec	h
	ld	l,usbOtgIer
	ld	(hl),bmUsbIntBSrpComplete or bmUsbIntASrpDetect or bmUsbIntAVbusErr ;or bmUsbIntBSessEnd
	inc	l;usbOtgIer+1
	ld	(hl),(bmUsbIntRoleChg or bmUsbIntIdChg or bmUsbIntOvercurr or bmUsbIntBPlugRemoved or bmUsbIntAPlugRemoved) shr 8
	ld	l,usbImr
	ld	(hl),usbIntLevelHigh
	call	_ResetHostControllerFromUnknown
	ld	(hl+endpoint.next),hl+endpoint.next
	ld	(hl+endpoint.next),endpoint
	ld	l,endpoint.prev
	ld	(hl),h
	ld	l,endpoint.info
	ld	(hl),endpoint.info.head
	ld	l,endpoint.overlay.status
	ld	(hl),endpoint.overlay.status.halted
	ld	hl,rootHub.find
	ld	(hl),IS_HUB or IS_ENABLED
	ld	l,a;(cHeap-$D10000) and $FF
	ld	h,a;(cHeap-$D10000) shr 8
	ld	b,sizeof cHeap shr 8
	rrc	e
	call	c,.initFreeList
iterate block, periodicList, usbMem, osHeap
	ld	h,(block-$D10000) shr 8
	ld	b,sizeof block shr 8
	rrc	e
	call	c,.initFreeList
end iterate
	ld	hl,USB_ERROR_INVALID_PARAM
	cp	a,c
	ret	nz
	ld	hl,mpUsbOtgIsr+1
	call	_HandleRoleChgInt
	ret	nz
	; TODO: disable disabled things
	scf
	or	a,a
	sbc	hl,hl
	ret
.initFreeList:
	call	_Free64Align256
	ld	a,32
.loop:
	add	a,32
	ld	l,a
	call	nz,_Free32Align32
	jq	nz,.loop
	inc	h
	djnz	.initFreeList
	ld	c,a
	ret

;-------------------------------------------------------------------------------
usb_Cleanup:
	ld	hl,mpUsbCmd
	call	_DisableSchedulesAndResetHostController.enter
;	xor	a,a
	ld	hl,mpUsbGimr
	ld	(hl),a
	ld	l,usbDevImr+1-$100
	ld	(hl),a
;	ld	hl,mpUsbDevIsr
;	ld	(hl),bmUsbIntDevResume or bmUsbIntDevSuspend
;	ld	l,usbDevImr+1-$100
;	set	bUsbIntDevDmaErr-8,(hl)
;	dec	l;usbDevImr-$100
;	set	bUsbIntDevDmaFin,(hl)
	ld	l,usbFifoRxImr-$100
	ld	(hl),bmUsbFifoRxInts
	ld	l,usbFifoTxImr-$100
	ld	(hl),bmUsbFifoTxInts
;	ld	l,a;usbDevCtrl-$100
;	set	bUsbDevReset,(hl)
;	res	bUsbDevReset,(hl)
;	ld	l,usbDevTest-$100
;	set	bUsbTstClrFifo,(hl)
;	ld	l,h;usbDevCtrl+1-$100
;	set	bUsbDevForceFullSpd-8,(hl)
;	dec	l;usbDevCtrl-$100
;	set	bUsbGirqEn,(hl)
;	set	bUsbDevEn,(hl)
;	set	7,(hl)
	call	_Init
	res	5,(hl)
	ret

;-------------------------------------------------------------------------------
usb_WaitForEvents.wait:
	ret	nz
usb_WaitForEvents:
	ld	hl,.wait
	push	hl
	jq	usb_WaitForInterrupt

;-------------------------------------------------------------------------------
usb_WaitForInterrupt:
	ld	hl,mpIntMask+1
	di
	set	bIntUsb-8,(hl)
	ei
	halt
	jq	usb_HandleEvents

;-------------------------------------------------------------------------------
usb_HandleEvents:
;	xor	a,a
;	ld	hl,mpUsbSts+1
;	bit	bUsbHcHalted-8,(hl)
;	jq	z,.notHalted
;	;jq	nz,.halted
;	;bit	bUsbRunStop,(hl)
;	;jq	nz,.notHalted
;;.halted:
;	; reset host controller (EHCI spec section 2.3)
;	ld	l,usbCmd
;	ld	(hl),2 shl bUsbFrameListSize
;	set	bUsbHcReset,(hl)
;	ld	b,(48000000*250/1000-.resetPreCycles+.resetCycles-1)/.resetCycles
;.resetPreCycles := 8
;.waitForReset:
;	bit	bUsbHcReset,(hl)	;12
;	jq	z,.reset		;+8
;.waitForReset.outer:
;	ld	c,a			;+(4
;.waitForReset.inner:
;	dec	c			;  +(4
;	jq	nz,.waitForReset.inner	;    +13)256-5
;	dec	a			;  +4
;	jq	nz,.waitForReset.outer	;  +13)256-5
;	djnz	.waitForReset		;+13
;.resetCycles := 12+8+(4+(4+13)*256-5+4+13)*256-5+13
;	inc	a ; zf = 0
;	jq	usb_Init.timeout
;.reset:
;
;	ld	(hl),bmUsbAsyncSchedEn or 2 shl bUsbFrameListSize or bmUsbRunStop; or bmUsbPeriodicSchedEn
;.notHalted:
	or	a,a
	sbc	hl,hl
	ld	a,(mpIntStat+1)
	and	a,intUsb shr 8
	ret	z
	ld	hl,mpUsbSts
	ld	a,(hl)
	ld	(_HandleHostInt.hack),a
	ld	l,usbIsr
iterate type, Dev, Host, Otg
	bit	bUsbInt#type,(hl)
	call	nz,_Handle#type#Int
	ret	nz
end iterate
	ld	a,intUsb shr 8
	ld	(mpIntAck+1),a
	ex	de,hl	; hl = 0
	or	a,a	; zf = 0
	ret

;-------------------------------------------------------------------------------
usb_RefDevice:
	pop	de
	ex	(sp),hl
	push	de
	inc	l
	dec	l
	ret	z
.enter:
	setmsk	device.refcount,hl
	ld	de,(hl)
	inc	de
	ld	(hl),de
	resmsk	device.refcount,hl
	ret

;-------------------------------------------------------------------------------
usb_UnrefDevice:
	pop	de
	ex	(sp),hl
	push	de
	inc	l
	dec	l
	ret	z
.enter:
	setmsk	device.refcount,hl
.refcount:
	ld	de,(hl)
	ex	de,hl
	add	hl,de
	scf
	sbc	hl,de
	ex	de,hl
	ld	(hl),de
	resmsk	device.refcount,hl
	call	z,_Free32Align32
	ld	de,mpUsbRange
.returnZero:
	or	a,a
.returnCarry:
	sbc	hl,hl
	ret

;-------------------------------------------------------------------------------
usb_GetDeviceHub:
	pop	de
	ex	(sp),ydevice
	push	de
	xor	a,a
	sbc	hl,hl
	cp	a,iyl
	ret	z
	ld	de,(ydevice.hub)
.returnDEIfValid:
	bit	0,de
	ret	nz
	ex	de,hl
	ret

;-------------------------------------------------------------------------------
usb_SetDeviceData:
	pop	de,ydevice
	ex	(sp),hl
	push	hl,de
	xor	a,a
	cp	a,iyl
	ret	z
	ld	(ydevice.data),hl
	ret

;-------------------------------------------------------------------------------
usb_GetDeviceData:
	pop	de
	ex	(sp),ydevice
	push	de
	xor	a,a
	sbc	hl,hl
	cp	a,iyl
	ret	z
	ld	hl,(ydevice.data)
	ret

;-------------------------------------------------------------------------------
usb_GetDeviceFlags:
	pop	de
	ex	(sp),ydevice
	push	de
	xor	a,a
	sbc	hl,hl
	cp	a,iyl
	ret	z
	ld	l,(ydevice.find)
	ret

;-------------------------------------------------------------------------------
usb_FindDevice:
	pop	de,hl,iy,bc
	push	bc,hl,hl,de
.enter:
	ld	de,-1
	add	iy,de
	inc	iy
	ex	de,hl
	jq	c,.child
	add	hl,de
	jq	c,.forceChild
	ld	iy,rootHub
	jq	.check
.child:
	bitmsk	IS_ATTACHED,c
	jq	nz,.sibling
.forceChild:
	bit	0,(ydevice.child)
	jq	nz,.sibling
	ld	iy,(ydevice.child)
	jq	.check
.check:
	ld	a,(ydevice.find)
	and	a,c
	jq	nz,.child
	lea	hl,iy
	ret
.hub:
	ld	iy,(ydevice.hub)
	lea	hl,iy
	ld	a,l
	rrca
	jq	c,usb_UnrefDevice.returnZero
	sbc	hl,de
	ret	z
.sibling:
	bit	0,(ydevice.sibling)
	jq	nz,.hub
	ld	iy,(ydevice.sibling)
	jq	.check

;-------------------------------------------------------------------------------
usb_ResetDevice:
	call	_Error.check
	ld	de,(ix+6)
	ld	a,e
	or	a,a
	jq	z,_Error.INVALID_PARAM
	ld	hl,(rootHub.child)
	sbc	hl,de
	jq	nz,_Error.NOT_SUPPORTED
	ld	a,12 ; WARNING: This assumes flash wait states port is 3, to get at least 100ms!
	call	_DelayTenTimesAms
	ld	hl,mpUsbPortStsCtrl+1
	set	bUsbPortReset-8,(hl)
	ld	a,6 ; WARNING: This assumes flash wait states port is 3, to get at least 50ms!
	call	_DelayTenTimesAms
	res	bUsbPortReset-8,(hl)
	ld	a,2 ; WARNING: This assumes flash wait states port is 3, to get at least 10ms!
	jq	_DelayTenTimesAms

;-------------------------------------------------------------------------------
usb_DisableDevice:
	call	_Error.check
	ld	de,(ix+6)
	ld	a,e
	or	a,a
	jq	z,_Error.INVALID_PARAM
	ld	hl,(rootHub.child)
	sbc	hl,de
	jq	z,_HandlePortPortEnInt.disable
	jq	_Error.NOT_SUPPORTED

;-------------------------------------------------------------------------------
usb_GetDeviceAddress:
	pop	hl
	ex	(sp),ydevice
	xor	a,a
	cp	a,iyl
	sbc	a,a
	and	a,(ydevice.addr)
	jp	(hl)

;-------------------------------------------------------------------------------
usb_GetDeviceSpeed:
	pop	hl
	ex	(sp),ydevice
	xor	a,a
	cp	a,iyl
	sbc	a,a
	cpl
	or	a,(ydevice.speed)
	jp	(hl)

;-------------------------------------------------------------------------------
usb_GetConfigurationDescriptorTotalLength:
	call	_Error.check
	call	_Alloc32Align32
	ret	nz
	push	hl,hl
	ld	(hl),a
	setmsk	4,hl
	ld	de,DEFAULT_RETRIES
	push	de,hl
	setmsk	12 xor 4,hl
	push	hl
	ld	c,(ix+9)
iterate value, DEVICE_TO_HOST or STANDARD_REQUEST or RECIPIENT_DEVICE, GET_DESCRIPTOR, c, CONFIGURATION_DESCRIPTOR, a, a, 4, a
	ld	(hl),value
 if % <> %%
	inc	l
 end if
end iterate
	ld	hl,(ix+6)
	call	usb_GetDeviceEndpoint.enter
	push	hl
	call	usb_ControlTransfer
	ld	iy,(ix-6)
	ld	a,(iy+0)
	ld	de,(iy+6)
	lea	hl,iy
	call	_Free32Align32
	ex.s	de,hl
	xor	a,4
	jq	z,usb_GetDescriptor.return
	sbc	hl,hl
	jq	usb_GetDescriptor.return

;-------------------------------------------------------------------------------
usb_GetDescriptor:
	call	_Error.check
	ld	c,GET_DESCRIPTOR
	ld	de,(ix+21)
	call	_Alloc32Align32
	ld	(hl),DEVICE_TO_HOST or STANDARD_REQUEST or RECIPIENT_DEVICE
.enter:
	jq	nz,_Error.NO_MEMORY
	push	hl,de
	ld	de,DEFAULT_RETRIES
	push	de
	ld	de,(ix+15)
	push	de,hl
	inc	l
	ld	(hl),c
	inc	l
	ld	c,(ix+12)
	ld	(hl),c
	inc	l
	ld	c,(ix+9)
	ld	(hl),c
	inc	l
	ld	(hl),a
	inc	l
	ld	(hl),a
.length:
	inc	l
	ld	de,(ix+18)
	ld	(hl),de
.endpoint:
	ld	hl,(ix+6)
	call	usb_GetDeviceEndpoint.enter
	push	hl
	call	usb_ControlTransfer
	ex	de,hl
	ld	hl,(ix-6)
	call	_Free32Align32
	ex	de,hl
.return:
	jq	usb_Transfer.return

;-------------------------------------------------------------------------------
usb_SetDescriptor:
	call	_Error.check
	ld	c,SET_DESCRIPTOR
	sbc	hl,hl
	ex	de,hl
	call	_Alloc32Align32
	ld	(hl),d;HOST_TO_DEVICE or STANDARD_REQUEST or RECIPIENT_DEVICE
	jq	usb_GetDescriptor.enter

;-------------------------------------------------------------------------------
usb_GetStringDescriptor:
	call	_Error.check
	ld	c,GET_DESCRIPTOR
	ld	de,(ix+21)
	call	_Alloc32Align32
	ld	(hl),DEVICE_TO_HOST or STANDARD_REQUEST or RECIPIENT_DEVICE
.enter:
	jq	nz,_Error.NO_MEMORY
	push	hl,de
	ld	de,DEFAULT_RETRIES
	push	de
	ld	de,(ix+15)
	push	de,hl
	inc	l
	ld	(hl),c
	inc	l
	ld	c,(ix+9)
	ld	(hl),c
	inc	l
	ld	(hl),STRING_DESCRIPTOR
	inc	l
	ld	de,(ix+12)
	ld	(hl),e
	inc	l
	ld	(hl),d
	jq	usb_GetDescriptor.length

;-------------------------------------------------------------------------------
usb_SetStringDescriptor:
	call	_Error.check
	ld	c,SET_DESCRIPTOR
	sbc	hl,hl
	ex	de,hl
	call	_Alloc32Align32
	ld	(hl),d;HOST_TO_DEVICE or STANDARD_REQUEST or RECIPIENT_DEVICE
	jq	usb_GetStringDescriptor.enter

;-------------------------------------------------------------------------------
usb_GetConfiguration:
	call	_Error.check
	sbc	hl,hl
	ex	de,hl
	call	_Alloc32Align32
	jq	nz,_Error.NO_MEMORY
	push	hl,de
	ld	e,DEFAULT_RETRIES
	push	de
	ld	de,(ix+9)
	push	de,hl
	ld	(hl),DEVICE_TO_HOST or STANDARD_REQUEST or RECIPIENT_DEVICE
	inc	l
	ld	(hl),GET_CONFIGURATION
repeat 3
	inc	l
	ld	(hl),a
end repeat
.length:
	inc	l
	ld	(hl),a
	inc	l
	ld	(hl),1
	inc	l
	ld	(hl),a
	jq	usb_GetDescriptor.endpoint

;-------------------------------------------------------------------------------
usb_SetConfiguration:
	call	_Error.check
	ld	de,(ix+12)
	ld	ydevice,(ix+6)
	push	ix
	ld	xconfigurationDescriptor,(ix+9)
assert xconfigurationDescriptor.bNumInterfaces+1 = xconfigurationDescriptor.bConfigurationValue
	ld	bc,(xconfigurationDescriptor.bNumInterfaces)
	push	bc
	ld	b,c
	call	_ParseInterfaceDescriptors.host
	pop	bc,ix
	jq	nz,_Error.INVALID_PARAM
	call	_Alloc32Align32
	jq	nz,_Error.NO_MEMORY
	ld	e,d
	push	hl,de
	ld	e,DEFAULT_RETRIES
	push	de,de,hl
	ld	(hl),d;HOST_TO_DEVICE or STANDARD_REQUEST or RECIPIENT_DEVICE
	inc	l
	ld	(hl),SET_CONFIGURATION
	inc	l
	ld	(hl),b
repeat 2
	inc	l
	ld	(hl),a
end repeat
.length:
repeat 3
	inc	l
	ld	(hl),a
end repeat
	jq	usb_GetDescriptor.endpoint

;-------------------------------------------------------------------------------
usb_GetInterface:
	call	_Error.check
	sbc	hl,hl
	ex	de,hl
	call	_Alloc32Align32
	jq	nz,_Error.NO_MEMORY
	push	hl,de
	ld	e,DEFAULT_RETRIES
	push	de
	ld	de,(ix+12)
	push	de,hl
	ld	(hl),DEVICE_TO_HOST or STANDARD_REQUEST or RECIPIENT_INTERFACE
	inc	l
	ld	(hl),GET_INTERFACE
repeat 2
	inc	l
	ld	(hl),a
end repeat
	inc	l
	ld	e,(ix+9)
	ld	(hl),e
	jq	usb_GetConfiguration.length

;-------------------------------------------------------------------------------
usb_SetInterface:
	call	_Error.check
	ld	de,(ix+12)
	ld	ydevice,(ix+6)
	push	ix
	ld	xconfigurationDescriptor,(ix+9)
assert xinterfaceDescriptor.bInterfaceNumber+1 = xinterfaceDescriptor.bAlternateSetting
	ld	bc,(xinterfaceDescriptor.bInterfaceNumber)
	push	bc
	ld	a,b
	ld	b,2
	call	_ParseInterfaceDescriptors.dec
	pop	bc,ix
	jq	nz,_Error.INVALID_PARAM
	call	_Alloc32Align32
	jq	nz,_Error.NO_MEMORY
	ld	e,d
	push	hl,de
	ld	e,DEFAULT_RETRIES
	push	de,de,hl
iterate value, HOST_TO_DEVICE or STANDARD_REQUEST or RECIPIENT_INTERFACE, SET_INTERFACE, b, a, c
	ld	(hl),value
 if % <> %%
	inc	l
 end if
end iterate
	jq	usb_SetConfiguration.length

;-------------------------------------------------------------------------------
usb_ClearEndpointHalt:
	call	_Error.check
	ld	yendpoint,(ix+6)
	ld	hl,(yendpoint.first)
	bitmsk	transfer.next.dummy,(hl+transfer.next)
	jq	z,_Error.NOT_SUPPORTED
	call	_Alloc32Align32
	jq	nz,_Error.NO_MEMORY
	call	usb_GetEndpointAddress.enter
	inc	de;0
	push	hl,de
	ld	e,DEFAULT_RETRIES
	push	de,hl,hl
assert ~ENDPOINT_HALT
iterate value, HOST_TO_DEVICE or STANDARD_REQUEST or RECIPIENT_ENDPOINT, CLEAR_FEATURE, d, d, a, d, d, d
	ld	(hl),value
 if % <> %%
	inc	l
 end if
end iterate
	xor	a,a
	ld	hl,(yendpoint.device+1)
	call	usb_GetDeviceEndpoint.enter
	push	hl
	call	usb_ControlTransfer
	ld	yendpoint,(ix+6)
	ex	de,hl
	ld	hl,(ix-6)
	call	_Free32Align32
	ex	de,hl
	resmsk	yendpoint.overlay.remaining.dt
	jq	usb_Transfer.return

;-------------------------------------------------------------------------------
usb_GetDeviceEndpoint:
	pop	de,hl,bc
	push	bc,hl,de
	inc	l
	dec	l
	ret	z
	ld	a,c
	and	a,$8F
.enter:
	ld	hl,(hl+device.endpoints)
	bit	0,hl
	jq	nz,.returnCarry
	rlca
	or	a,l
	ld	l,a
	ld	h,(hl)
	ld	l,endpoint
	ld	a,h
	inc	a
	ret	nz
.returnCarry:
	sbc	hl,hl
	ret

;-------------------------------------------------------------------------------
usb_GetEndpointDevice:
	pop	de
	ex	(sp),yendpoint
	push	de
	xor	a,a
	sbc	hl,hl
	cp	a,iyl
	ret	z
	ld	de,(yendpoint.device)
	jq	usb_GetDeviceHub.returnDEIfValid

;-------------------------------------------------------------------------------
usb_SetEndpointData:
	pop	de,yendpoint
	ex	(sp),hl
	push	hl,de
	xor	a,a
	cp	a,iyl
	ret	z
	ld	(yendpoint.data),hl
	ret

;-------------------------------------------------------------------------------
usb_GetEndpointData:
	pop	de
	ex	(sp),yendpoint
	push	de
	xor	a,a
	sbc	hl,hl
	cp	a,iyl
	ret	z
	ld	hl,(yendpoint.data)
	ret

;-------------------------------------------------------------------------------
usb_GetEndpointAddress:
	pop	hl
	ex	(sp),yendpoint
	push	hl
.enter:
	ld	de,-1
	add	yendpoint,de
	ld	a,e
	ret	nc
	ld	a,(yendpoint.dir+1)
	rrca
	ld	a,(yendpoint.info+1)
	rla
	rrca
	and	a,$8F
	ret

;-------------------------------------------------------------------------------
usb_GetEndpointTransferType:
	pop	hl
	ex	(sp),yendpoint
	xor	a,a
	cp	a,iyl
	sbc	a,a
	cpl
	or	a,(yendpoint.type)
	jp	(hl)

;-------------------------------------------------------------------------------
usb_GetEndpointMaxPacketSize:
	pop	de
	ex	(sp),yendpoint
	push	de
	xor	a,a
	cp	a,iyl
	ret	z
	ld	de,(yendpoint.maxPktLen)
	ld	a,d
	and	a,111b
	ld	d,a
	ex.s	de,hl
	ret

;-------------------------------------------------------------------------------
usb_SetEndpointFlags:
	pop	de,yendpoint
	ex	(sp),hl
	push	hl,de
	xor	a,a
	cp	a,iyl
	ret	z
	ld	(yendpoint.flags),l
	ret

;-------------------------------------------------------------------------------
usb_GetEndpointFlags:
	pop	hl
	ex	(sp),yendpoint
	xor	a,a
	cp	a,iyl
	sbc	a,a
	and	a,(yendpoint.flags)
	jp	(hl)

;-------------------------------------------------------------------------------
usb_GetRole:
	or	a,a
	sbc	hl,hl
	ld	a,(currentRole)
	ld	l,a
	ret

;-------------------------------------------------------------------------------
usb_GetFrameNumber:
	ld	hl,mpUsbOtgCsr+2
	bit	bUsbRole-16,(hl)
	ld	l,usbFrameIdx
	jq	z,.load
	ld	l,usbSofFrNum-$100
	inc	h
.load:
	ld	de,(hl)
	ld	a,(hl)
	cp	a,e
	jq	c,.load
	ld	e,a
	dec	h
	ex	de,hl
	ret	nz
repeat bsr 8
	add	hl,hl
end repeat
	ret

;-------------------------------------------------------------------------------
usb_ControlTransfer:
	ld	hl,usb_ScheduleControlTransfer.enter
	jq	usb_Transfer.enter

;-------------------------------------------------------------------------------
usb_Transfer:
	ld	hl,usb_ScheduleTransfer.enter
.enter:
	ld	(.dispatch),hl
	call	_Error.check
	ld	hl,(ix+15)
	push	hl
	ld	hl,(ix+18)
	push	hl
	sbc	hl,hl
	inc	l
	push	hl
	ld	hl,.callback
	ld	(ix+15),hl
	ld	(ix+18),ix
	call	0
label .dispatch at $-long
.wait:
	push	bc
	call	usb_WaitForEvents
	pop	bc
	add	hl,de
	or	a,a
	sbc	hl,de
	jq	nz,.return
	ld	l,(ix-12)
	dec	l
	jq	z,.wait
	inc	l
.return:
	ld	sp,ix
	pop	ix
	ret

.callback:
	ld	hl,12
	add	hl,sp
	ld	iy,(hl)
repeat long
	dec	hl
end repeat
	ld	bc,(hl)
repeat long
	dec	hl
end repeat
	ld	a,(hl)
	sbc	hl,hl
	or	a,a;USB_TRANSFER_COMPLETED
	jq	z,.complete
	and	a,USB_TRANSFER_CANCELLED or USB_TRANSFER_OVERFLOW or USB_TRANSFER_NO_DEVICE or USB_TRANSFER_STALLED
	ld	a,USB_ERROR_FAILED
	jq	nz,.complete
	ld	de,(iy-6)
	inc	l
	add	hl,de
	inc	l
	ret	c
	sbc	hl,hl
	dec	hl
	adc	hl,de
	ld	(iy-6),hl
	ld	hl,1
	ret	nz
assert USB_ERROR_TIMEOUT = USB_ERROR_FAILED-1
	dec	a;USB_ERROR_TIMEOUT
	dec	hl
	or	a,a
.complete:
	ld	(iy-12),a
	ld	de,(iy-9)
	adc	hl,de
	ret	z
	ld	(hl),bc
	sbc	hl,hl
	ret

;-------------------------------------------------------------------------------
usb_ScheduleControlTransfer.device:
	cp	a,a
usb_ScheduleControlTransfer.notControl:
	ld	ysetup,(ix+9)
	ld	bc,(ysetup.wLength)
	inc	bc
	dec.s	bc
	ld	de,(ix+12)
	ld	yendpoint,(ix+6)
	jq	nz,usb_ScheduleTransfer.notControl
usb_ScheduleTransfer.device:
	ld	hl,(setupPacket.wLength)
	inc	hl
	dec.s	hl
	sbc	hl,bc
	jq	nc,usb_ScheduleTransfer.device.notLess
	add	hl,bc
	push	hl
	pop	bc
usb_ScheduleTransfer.device.notLess:
	ld	a,c
	or	a,b
	jq	z,usb_ScheduleTransfer.device.zlp
	ld	a,(setupPacket.bmRequestType)
	rlca
	push	af
	ld	a,transfer.type.ioc shr 1
	rla
	call	_QueueTransfer
	pop	af
	ret	nc
	xor	a,a
	call	_ExecuteDma
	ret	nc
usb_ScheduleTransfer.device.return:
	jq	usb_Transfer.return
usb_ScheduleTransfer.device.zlp:
	ld	hl,mpUsbCxFifo
	ld	(hl),bmCxFifoFin
	ld	de,(ix+18)
	ld	hl,usb_Transfer.return
	push	yendpoint,bc,bc,de,hl
	ld	hl,(ix+15)
_DispatchEvent.dispatch:
	jp	(hl)
usb_ScheduleControlTransfer:
	call	_Error.check
.enter:
	call	.check
	ld	yendpoint,(ix+6)
	or	a,(yendpoint.type);CONTROL_TRANSFER
	jq	nz,.notControl
	ld	hl,currentRole
	bit	bUsbRole-16,(hl)
	jq	nz,.device
.control:
	ld	a,00001110b
	ld	bc,8
	ld	de,(ix+9)
	call	.queueStage
	ld	ysetup,(ix+9)
	ld	a,(ysetup.bmRequestType)
	and	a,1 shl 7
	ld	bc,(ysetup.wLength)
	inc.s	bc
	cpi.s
	ld	de,(ix+12)
	rlca
	push	af
	call	pe,_QueueTransfer
	pop	af
	xor	a,10001101b
	ld	bc,transfer.remaining.dt
	jq	.queueStage
.queueStage:
	call	_CreateDummyTransfer
assert (endpoint-1) and 1
	dec	yendpoint
	jq	z,_FillTransfer
	jq	_Error.NO_MEMORY
.check:
	ld	hl,(ix+9)
	add	hl,de
	or	a,a
	sbc	hl,de
.invalidParam:
	jq	z,_Error.INVALID_PARAM
usb_ScheduleTransfer.check:
	ld	hl,(ix+6)
	add	hl,de
	or	a,a
	sbc	hl,de
	jq	z,usb_ScheduleControlTransfer.invalidParam
	ld	l,endpoint.device
	ld	ydevice,(hl)
	bitmsk	IS_ENABLED,(ydevice.find)
	jq	z,_Error.NO_DEVICE
	ld	hl,(ix+15)
	add	hl,de
	or	a,a
	sbc	hl,de
	ret	nz
	ld	hl,_DefaultHandler
	ld	(ix+15),hl
	ret

;-------------------------------------------------------------------------------
usb_ScheduleTransfer.control:
	bit	bUsbRole-16,(hl)
	jq	nz,usb_ScheduleTransfer.device
	ld	ysetup,(ix+9)
	lea	de,ysetup+sizeof ysetup
	ld	(ix+12),de
	jq	usb_ScheduleControlTransfer.control
usb_ScheduleTransfer:
	call	_Error.check
.enter:
	call	.check
	ld	bc,(ix+12)
	ld	de,(ix+9)
	ld	yendpoint,(ix+6)
	ld	hl,currentRole
	or	a,(yendpoint.type);CONTROL_TRANSFER
	jq	z,.control
.notControl:
	cp	a,ISOCHRONOUS_TRANSFER-CONTROL_TRANSFER+1
	bit	bUsbRole-16,(hl)
	ld	a,(yendpoint.dir)
	jq	z,.host
	or	a,a
	jq	z,.out
	ld	a,(yendpoint.overlay.fifo)
	cpl
	ld	hl,mpUsbFifoTxImr
	and	a,(hl)
	ld	(hl),a
	ld	a,1
.host:
	jq	c,_Error.NOT_SUPPORTED
.out:
	or	a,transfer.type.ioc
	jq	_QueueTransfer

; Input:
;  a = ioc shl 7 or dir
;  bc = length
;  de = buffer
;  (ix+6) = endpoint
;  (ix+15) = handler
;  (ix+18) = data
_QueueTransfer:
	call	_CreateDummyTransfer
	jq	nz,_Error.NO_MEMORY
	ld	(.dummy),hl
	or	a,transfer.type.cerr
	push	af
	sbc	hl,hl
	sbc	hl,bc
	jq	z,.zlp
.next:
	push	de
	ld	a,d
	and	a,$F
	ld	d,a
	ld	hl,$5000
	sbc.s	hl,de
	sbc	hl,bc
	jq	c,.notEnd
	sbc	hl,hl
	bitmsk	AUTO_TERMINATE,(yendpoint.flags)
.notEnd:
	add	hl,bc
	jq	z,.last
	ld	de,(yendpoint.maxPktLen)
	ex.s	de,hl
	bitmsk	PO2_MPS,(yendpoint.internalFlags)
	jq	nz,.modPo2
	ld	a,h
	and	a,7
	ld	h,a
	or	a,l
	jq	z,_Error.INVALID_PARAM
	push	bc,de
	ld	b,-1
.modShift:
	inc	b
	add.s	hl,hl
	jq	nc,.modShift
	ex	de,hl
.modLoop:
	rr	d
	rr	e
	sbc	hl,de
	jq	nc,.modSkip
	add	hl,de
	or	a,a
.modSkip:
	djnz	.modLoop
	pop	de,bc
	jq	.modDone
.modPo2:
	ld	a,l
	add	a,a
	jq	nz,.modPo2Byte
	ld	a,h
	adc	a,a
	and	a,$F
	dec	a
	and	a,d
	ld	h,a
	ld	l,e
	jq	.modDone
.modPo2Byte:
	dec	a
	and	a,e
	ld	l,a
	ld	h,0
.modDone:
	ex	de,hl
	sbc	hl,bc
	add	hl,bc
	jq	nz,.notLast
	ld	a,d
	or	a,e
	jq	nz,.last
.notLast:
	or	a,a
	sbc	hl,de
	pop	de,af
	push	af,bc,de,hl
	call	_CreateDummyTransfer.enter
	jq	nz,_Error.NO_MEMORY
	and	a,00001101b
	pop	bc
	push	bc
	call	.queue
	pop	bc,hl,de
	add	hl,bc
	ex	de,hl
	sbc	hl,bc
	push	hl
	pop	bc
	jq	nz,.next
virtual
	jr	nz,$$
 assert $ = .zlp
 load .jr_nz: byte from $$
end virtual
	db	.jr_nz
.last:
	pop	de
.zlp:
	pop	af
	and	a,10001101b
	push	hl
	pop	bc
virtual at .queue
	ld	iy,0
 assert $ = .fill
 load .iyPrefix: byte from $$
end virtual
	ld	iyl,.iyPrefix
label .queue at $-byte
	ld	hl,0
label .dummy at $-long
.fill:
	set	7,b
	jq	_FillTransfer

; Input:
;  a = ioc shl 7 or transfer.type.cerr or pid
;  bc = dt shl 15 or length
;  de = buffer
;  hl = next
;  iy = alt next
;  (ix+6) = endpoint
;  (ix+15) = handler
;  (ix+18) = data
_FillTransfer:
	ex	de,hl
	push	hl,iy
	ld	yendpoint,(ix+6)
	ld	hl+transfer,(yendpoint.last)
	ld	(hl+transfer.next),de
	ld	(yendpoint.last),de
	setmsk	transfer.altNext,hl
	pop	de
	ld	(hl),de
repeat transfer.type-transfer.altNext
	inc	l
end repeat
	ld	(hl),a
repeat transfer.remaining-transfer.type
	inc	l
end repeat
	ld	(hl),c
	inc	l;transfer.remaining+1
	ld	(hl),b
	pop	de
	inc	l;transfer.buffers
	ld	(hl),de
	dec	sp
	push	de
	inc	sp
	pop	de
repeat transfer.length-transfer.buffers
	inc	l
end repeat
	ld	(hl),c
	inc	l;transfer.length+1
	ld	(hl),b
	call	.packHalf
	ld	bc,(ix+15)
	call	.pack
	ld	bc,(ix+18)
	call	.pack
	lea	bc,yendpoint
	call	.pack
	ld	(hl),d
	ld	a,l
	sub	a,transfer.padding-transfer.status
	ld	l,a
	ld	(hl),transfer.status.active
	ld	hl,mpUsbCmd
	bit	bUsbAsyncSchedEn,(hl)
	ret	nz
	ld	l,usbSts+1
	ld	b,(48000000*20/1000-.sync.cycles.pre+.sync.cycles-1)/.sync.cycles
.sync.cycles.pre := 16+12+5+8+8
.sync.wait:
	bit	bUsbAsyncSchedSts-8,(hl)	;12
	jq	nz,.sync			;+8
	ld	l,usbCmd
	set	bUsbAsyncSchedEn,(hl)
	ret
.sync:
	xor	a,a				;+4
.sync.loop:
	dec	a				;+(4
	jq	nz,.sync.loop			;  +13)*256-5
	djnz	.sync.wait			;+13
	jq	_Error.TIMEOUT
.sync.cycles := 12+8+4+(4+13)*256-5+13
.pack:
	ld	a,d
	xor	a,c
	and	a,$F
	xor	a,c
	ld	(hl),bc
	ld	(hl),a
	inc	l
	inc	l
.packHalf:
	inc	l
	ld	a,e
	or	a,$F
	ld	e,a
	inc	de
	ld	a,c
	xor	a,e
	and	a,$F
	xor	a,e
	ld	(hl),a
	inc	l
	ret

;-------------------------------------------------------------------------------
element error
label _Error at error

iterate error, SYSTEM, INVALID_PARAM, SCHEDULE_FULL, NO_DEVICE, NO_MEMORY, NOT_SUPPORTED, TIMEOUT, FAILED

.error:
	ld	a,USB_ERROR_#error
	jq	.return

end iterate

.check:
	pop	de
	call	__frameset0
	ld	a,(mpIntMask)
	and	a,intTmr3
	jq	nz,.SYSTEM
	ld	a,(mpUsbSts)
	and	a,bmUsbIntHostSysErr
	jq	nz,.SYSTEM
	ld	a,(usbInited)
	dec	a
	jq	nz,.SYSTEM
	ex	de,hl
	call	_DispatchEvent.dispatch
	jq	.success

.success:
	xor	a,a
	jq	.return

.return:
	or	a,a
	sbc	hl,hl
	ld	l,a
	jq	usb_Transfer.return

; Input:
;  a = fill
; Output:
;  bc = 0
;  hl = flags+$1B
_Init:
	ld	de,usbInited
	ld	(de),a
;	ld	hl,mpUsbCmd
;	ld	(hl),2 shl bUsbFrameListSize
;	call	_Delay10ms
;	ld	l,usbSts+1
;	bit	bUsbHcHalted-8,(hl)
;	jq	z,.notHalted
;	ld	l,usbCmd
;	ld	(hl),2 shl bUsbFrameListSize or bmUsbHcReset
;.waitForReset:
;	bit	bUsbHcReset,(hl)
;	jq	nz,.waitForReset
;.notHalted: ; rip memory?
	ld	hl,usbInited
	dec	de
	ld	bc,usbInited-usbArea
	lddr
	ld	hl,flags+$1B
	ret

;-------------------------------------------------------------------------------
; Input:
;  hl = mpUsbRange xor (? and $FF)
; Output:
;  a = 0
;  b = ?
;  d = ?
;  hl = dummyHead.next
_DisableSchedulesAndResetHostController:
	; stop schedules
	ld	l,usbCmd
.enter:
	ld	a,(hl)
	and	a,bmUsbAsyncSchedEn or bmUsbPeriodicSchedEn
assert bUsbAsyncSchedSts-8-bUsbAsyncSchedEn = bUsbPeriodicSchedSts-8-bUsbPeriodicSchedEn
repeat bUsbAsyncSchedSts-8-bUsbAsyncSchedEn
	rlca
end repeat
	ld	d,a
	ld	l,usbSts+1
	ld	b,(48000000*20/1000-.sync.cycles.pre+.sync.cycles-1)/.sync.cycles
.sync.cycles.pre := 8+8+8+4*2+4+8+8
.sync.wait:
	ld	a,(hl)							;8
	and	a,(bmUsbAsyncSchedSts or bmUsbPeriodicSchedSts) shr 8	;+8
	sub	a,d							;+4
	jq	nz,.sync						;+13
.sync.fail:
	jq	_ResetHostControllerFromUnknown

; Input:
;  a = 0
;  hl = mpUsbRange xor (? and $FF)
; Output:
;  a = 0
;  b = ?
;  d = ?
;  hl = dummyHead.next
_ResetHostControllerFromUnknown:
	; halt host controller (EHCI spec section 2.3)
	ld	l,usbIntEn
	ld	(hl),a
	ld	l,usbCmd
	ld	(hl),2 shl bUsbFrameListSize
	ld	l,usbSts+1
	ld	b,(48000000*2/1000-.halt.cycles.pre+.halt.cycles-1)/.halt.cycles
.halt.cycles.pre := 16
.halt.wait:
	bit	bUsbHcHalted-8,(hl)	;12
	jq	z,.halt			;+13
.halt.fail:

	; reset host controller (EHCI spec section 2.3)
	ld	l,usbCmd
	ld	(hl),2 shl bUsbFrameListSize or bmUsbHcReset
	ld	b,(48000000*250/1000-.reset.cycles.pre+.reset.cycles-1)/.reset.cycles
.reset.cycles.pre := 8
.reset.wait:
	bit	bUsbHcReset,(hl)	;12
	jq	nz,.reset		;+13
.reset.fail:

	; initialize host controller from halt (EHCI spec section 4.1)
	ld	l,usbIntEn
	ld	(hl),bmUsbInt or bmUsbIntErr or bmUsbIntPortChgDetect or bmUsbIntFrameListOver or bmUsbIntHostSysErr or bmUsbIntAsyncAdv
	ld	hl,periodicList
	ld	(mpUsbPeriodicListBase),hl
	ld	hl,dummyHead.next
	ld	(mpUsbAsyncListAddr),hl
	ret ; defer actual start until plug

namespace _DisableSchedulesAndResetHostController
?sync:
	xor	a,a							;+4
.loop:
	dec	a							;+(4
	jq	nz,.loop						;  +13)*256-5
	djnz	.wait							;+13
.cycles := 8+8+4+13+4+(4+13)*256-5+13
	jq	.fail
end namespace

.halt:
	dec	a			;+(4
	jq	nz,.halt		;  +13)256-5
	djnz	.halt.wait		;+13
.halt.cycles := 12+13+(4+13)*256-5+13
	jq	.halt.fail

.reset:
	ld	d,a			;+(4
.reset.loop:
	dec	d			;  +(4
	jq	nz,.reset.loop		;    +13)256-5
	dec	a			;  +4
	jq	nz,.reset		;  +13)256-5
	djnz	.reset.wait		;+13
.reset.cycles := 12+13+(4+(4+13)*256-5+4+13)*256-5+13
	jq	.reset.fail

;-------------------------------------------------------------------------------
; Input:
;  a = role
;  hl = mpUsbRange xor (? and $FF)
; Output:
;  zf = success
;  a = ?
;  bc = ?
;  hl = mpUsbRange xor (? and $FF) | error code
;  iy = ?
_PowerVbusForRole:
	ld	l,usbOtgCsr
	bitmsk	ROLE_DEVICE,a
	jq	nz,.unpower
.power:
	call	bos._UsbPowerVbus
	res	bUsbABusDrop,(hl)
	set	bUsbABusReq,(hl)
	ld	l,usbSts+1
	bit	bUsbHcHalted-8,(hl)
	jq	z,.notHalted
	ld	l,usbCmd
	set	bUsbRunStop,(hl)
.notHalted:
	or	a,a;ROLE_B
	ret	z
	ld	l,usbOtgCsr
	res	bUsbBHnp,(hl)
	res	bUsbBVbusDisc,(hl)
	ret
.unpower:
	res	bUsbASrpEn,(hl)
	push	hl,de
	call	_DisableSchedulesAndResetHostController
	ld	de,$D7FFFF ; disable doorbell
	call	_HandleAsyncAdvInt.cleanup.de
	call	_HandleAsyncAdvInt.cleanup.hl
	pop	de,hl
	set	bUsbABusDrop,(hl)
	res	bUsbABusReq,(hl)
	jq	bos._UsbUnpowerVbus

;-------------------------------------------------------------------------------
_DefaultHandler:
	ld	hl,USB_SUCCESS
	ret

;-------------------------------------------------------------------------------
; Input:
;  (sp+12) = block
; Output:
;  hl = ?
_FreeTransferData:
	ld	hl,3+12
	add	hl,sp
	ld	hl,(hl)
	jq	_Free32Align32

iterate <size,align>, 32,32, 64,256

; Frees an <align> byte aligned <size> byte block.
; Input:
;  hl = allocated memory to be freed.
_Free#size#Align#align:
	push	de
	ld	de,(freeList#size#Align#align)
	ld	(hl),de
	ld	(freeList#size#Align#align),hl
.return:
	pop	de
	ret

; Allocates an <align> byte aligned <size> byte block.
; Output:
;  zf = enough memory
;  hl = allocated memory
_Alloc#size#Align#align:
	ld	hl,(freeList#size#Align#align)
	bit	0,hl
	ret	nz
	push	hl
	ld	hl,(hl)
	ld	(freeList#size#Align#align),hl
	pop	hl
	ret

end iterate

; Input:
;  (ix+6) = endpoint
; Output:
;  zf = enough memory
;  hl = transfer
;  iy = (ix+6)
_CreateDummyTransfer:
	ld	yendpoint,(ix+6)
.enter:
	call	_Alloc32Align32
	ret	nz
	setmsk	transfer.status,hl
	ld	(hl),transfer.status.halted
	resmsk	transfer.status,hl
	ld	(hl),1
	ret

; Input:
;  b = port or 1 shl 7
;  c = find flags
;  de = parent hub
;  hl = pointer to device speed shl 2
; Output:
;  a = ?
;  zf = enough memory
;  hl = ?
;  iy = device
_CreateDevice:
	ld	a,(hl)
	call	_Alloc32Align32
	ret	nz
	push	hl
	pop	ydevice
	call	_Alloc32Align32
	jq	nz,.nomem
	ld	(ydevice.endpoints),hl
	ex	de,hl
	ld	(ydevice.hub),hl
	ld	(ydevice.find),c
assert bUsbSpd-16 = bUsbDevSpd
	and	a,bmUsbSpd shr 16
	rrca
	rrca
	ld	(ydevice.speed),a
	setmsk	device.addr,hl
	ld	a,(hl)
	srl	b
	rla
	rrca
	ld	c,a
assert ydevice.info+2 = ydevice.data ; clobber
	ld	(ydevice.info),bc
repeat device.child-device.addr
	inc	l
end repeat
	ld	(hl),ydevice
	ld	(ydevice.back),hl
	ld	bc,32-1
	push	de
	inc	de
	pop	hl
	ld	(hl),-1
	ldir
	ld	(ydevice.hubPorts),b;0
	ld	(ydevice.addr),b;0
	ld	(ydevice.data),bc;0 ; unclobber
	inc	c;1
	ld	(ydevice.refcount),bc;1
	ld	(ydevice.child),c;1
	ld	(ydevice.sibling),c;1
	cp	a,a
	ret
.nomem:
	lea	hl,ydevice
	jq	_Free32Align32

; Input:
;  ix = device-1
; Output:
;  zf = success
;  a = ?
;  bc = ?
;  de = ?
;  hl = mpUsbRange | error
;  ix = ?
;  iy = ?
_DeviceDisabled:
	ld	hl,_HandleAsyncAdvInt.scheduleCleanup.hl
	push	hl
virtual
	ld	hl,0
 assert $ = .recurse
 load .ld_hl: byte from $$
end virtual
	db	.ld_hl
.recursed:
	pop	xdevice
	ret	nz
.recurse:
	push	xdevice
	ld	de,(xdevice.endpoints+1)
	setmsk	IS_DISABLED,(xdevice.find+1)
	resmsk	IS_ENABLED,(xdevice.find+1)
	ld	xdevice,(xdevice.child+1)
	ld	hl,.recursed
	dec	ixl
	jq	nz,_DeviceDisconnected.recurse
	ld	xendpoint,dummyHead
	ld	bc,USB_TRANSFER_CANCELLED or USB_TRANSFER_NO_DEVICE
.loop:
	ld	a,(de)
	ld	ixh,a
	inc	a
	jq	z,.next
	ld	a,(xendpoint.type)
	or	a,a
	ld	a,-1
	ld	(de),a
	jq	nz,.notControl
	inc	e
	ld	(de),a
.notControl:
	sbc	hl,hl
	ld	ytransfer,(xendpoint.first)
	jq	.check
.flush:
	push	ytransfer,de
	call	_DispatchTransferCallback
	pop	de,ytransfer
	add	hl,de
	or	a,a
	sbc	hl,de
	jq	nz,_Free32Align32.return
.scan:
	bitmsk	ytransfer.type.ioc
	ld	ytransfer,(ytransfer.next)
	jq	z,.scan
.check:
	bitmsk	ytransfer.next.dummy
	jq	z,.flush
	lea	hl,xendpoint.next
	ld	h,(xendpoint.prev)
	ld	yendpoint,(xendpoint.next)
	ld	(hl+endpoint.next),yendpoint
	ld	(yendpoint.prev),h
	ld	hl,cleanupListPending
	ld	a,(hl)
	ld	(xendpoint.prev),a
	ld	a,ixh
	ld	(hl),a
.next:
	inc	e
	ld	a,e
	and	a,31
	jq	nz,.loop
	pop	xdevice
	ld	hl,mpUsbRange
	lea	de,xdevice+1
	ld	a,USB_DEVICE_DISABLED_EVENT
	jq	_DispatchEvent

; Input:
;  ix = device-1
; Output:
;  zf = success
;  a = ?
;  bc = ?
;  de = ?
;  hl = mpUsbRange | error
;  ix = ?
;  iy = ?
_DeviceDisconnected:
	ld	hl,_HandleAsyncAdvInt.scheduleCleanup.de
.recurse:
	push	hl
	call	_DeviceDisabled.recurse
	ret	nz
	lea	de,xdevice+1
	ld	a,USB_DEVICE_DISCONNECTED_EVENT
	call	_DispatchEvent
	ret	nz
	ld	bc,(xdevice.sibling+1)
	ld	hl,(xdevice.back+1)
	ld	(hl),bc
	ld	hl,(xdevice.endpoints+1)
	ld	(xdevice.endpoints+1),xdevice
	call	_Free32Align32
	lea	hl,xdevice.refcount+1
	jq	usb_UnrefDevice.refcount

; Input:
;  iy = device
; Output:
;  zf = enough memory
;  iy = endpoint | ?
_CreateDefaultControlEndpoint:
	ld	de,_DefaultControlEndpointDescriptor
	jq	_CreateEndpoint

; Input:
;  de = endpoint descriptor
;  iy = device
; Output:
;  zf = enough memory
;  iy = endpoint | ?
_CreateEndpoint:
	call	_Alloc64Align256
	ret	nz
	ld	bc,(dummyHead.next)
	ld	(hl+endpoint.next),bc
repeat endpoint.prev-endpoint
	inc	c
end repeat
	ld	a,h
	ld	(bc),a
	inc	de;endpointDescriptor.descriptor.bDescriptorType
	inc	de;endpointDescriptor.bEndpointAddress
	ld	a,(de)
	and	a,endpoint.info.ep
	or	a,(ydevice.speed)
	ld	l,endpoint
	push	af,hl
repeat endpoint.prev-endpoint
	inc	l
end repeat
	ld	(hl),dummyHead shr 8 and $FF
repeat endpoint.addr-endpoint.prev
	inc	l
end repeat
	ld	c,(ydevice.addr)
	ld	(hl),c
repeat endpoint.info-endpoint.addr
	inc	l
end repeat
	ld	(hl),a
	ld	bc,(ydevice.endpoints)
	ld	a,(de)
	and	a,$8F
	rlca
	or	a,c
	ld	c,a
	ld	a,h
	ld	(bc),a
	inc	de
	ld	a,(de)
	and	a,bmUsbFifoType
	jq	nz,.notControl
	ld	a,c
	xor	a,1
	ld	c,a
	ld	a,h
	ld	(bc),a
	setmsk	endpoint.info.dtc,(hl)
	ld	a,endpoint.maxPktLen.control shr 8
.notControl:
repeat endpoint.maxPktLen-endpoint.info
	inc	l
end repeat
	ex	de,hl
	inc	hl
	ldi
	or	a,$F0
	xor	a,(hl)
	and	a,$F8
	xor	a,(hl)
	ex	de,hl
	ld	(hl),a
	xor	a,a
	ld	bc,(ydevice.info)
iterate reg, a, a, c, b; endpoint.smask, endpoint.cmask, endpoint.hubInfo
	inc	l
	ld	(hl),reg
end iterate
	ld	l,endpoint.device
	ld	(hl),ydevice
	pop	yendpoint
assert endpoint.device and 1
	ld	(yendpoint.overlay.altNext),l
	call	_CreateDummyTransfer.enter
	pop	bc
	jq	nz,.nomem
	ld	(yendpoint.overlay.next),hl
	ld	(yendpoint.first),hl
	ld	(yendpoint.last),hl
	ex	de,hl
	ld	(yendpoint.overlay.status),a
	ld	(yendpoint.flags),a
	ld	(yendpoint.internalFlags),a
	ld	d,(hl)
	dec	hl
	ld	e,(hl)
	ld	a,e
	or	a,d
	jq	z,.checkedMps
	dec	de
	ld	a,e
	and	a,(hl)
	ld	e,a
	inc	hl
	ld	a,d
	and	a,(hl)
	or	a,e
	dec	hl
	jq	nz,.checkedMps
	setmsk	PO2_MPS,(yendpoint.internalFlags)
.checkedMps:
	dec	hl
	ld	a,(hl)
	and	a,bmUsbFifoType
	ld	(yendpoint.type),a
	or	a,bmUsbFifoEn
	ld	e,a
	dec	hl
	ld	a,(hl)
	and	a,1 shl 7
	rlca
	ld	(yendpoint.dir),a
	ld	(dummyHead.next),yendpoint
	sbc	hl,hl
	ld	a,(currentRole)
	and	a,bmUsbRole shr 16
	ret	z
	inc	b
	dec	b
assert bmUsbRole shr 16 = bmUsbDmaCxFifo
	jq	z,.control
assert bmUsbRole shr 16 = usbFifoIn
	and	a,l
	ld	c,a
	ld	hl,mpUsbFifo0Map-1
	ld	a,l
	add	a,b
	ld	l,a
	ld	a,(hl)
	and	a,not bmUsbFifoDir
	or	a,c
	ld	(hl),a
assert usbFifo0Cfg > usbFifo0Map
	setmsk	usbFifo0Cfg xor usbFifo0Map,hl
	ld	(hl),e
	ld	a,usbOutEp1+1-4-$100
assert usbOutEp1 > usbInEp1
repeat 2
	sub	a,c
end repeat
repeat 4
	add	a,b
end repeat
	ld	l,a
	ld	(hl),bmUsbEpReset shr 8
	ld	de,(yendpoint.maxPktLen)
	ld	a,d
	and	a,bmUsbEpMaxPktSz shr 8
	ld	(hl),a
	dec	l
	ld	(hl),e
	xor	a,a
	scf
.shift:
	rla
	djnz	.shift
.control:
	ld	(yendpoint.overlay.fifo),a
	ret
.nomem:
	lea	hl,yendpoint.base
	jq	_Free64Align256

;-------------------------------------------------------------------------------
; Input:
;  a = alt
;  b = num interfaces
;  de = length or ? shl 16
;  ix = descriptors
;  iy = device
; Output:
;  zf = valid
;  a = 0 | ?
;  bc = ?
;  de = ? and $FFFF
;  hl = ? and $FFFF
;  ix = ?
;  iy = device
_ParseInterfaceDescriptors:
	ld	hl,mpUsbDevTest
	set	bUsbTstClrFifo,(hl)
	res	bUsbTstClrFifo,(hl)
.host:
	inc	b
.dec:
	ld	(.alt),a
	or	a,a
	sbc	hl,hl
	ex.s	de,hl
	ld	c,e
	jq	.enter
.endpoint:
	cp	a,c
	jq	z,.next
	ld	a,e
	cp	a,sizeof xendpointDescriptor
	ret	c
	push	bc,de,hl,ydevice
	lea	de,xendpointDescriptor
	call	_CreateEndpoint
	pop	ydevice,hl,de,bc
	ret	nz
	dec	c
.next:
	add	xdescriptor,de
.enter:
	add	hl,de
	xor	a,a
	sbc	hl,de
	ret	z
	ld	a,(xdescriptor.bLength)
	cp	a,sizeof xdescriptor
	ret	c
	ld	e,a
	sbc	hl,de
	ret	c
	ld	a,(xdescriptor.bDescriptorType)
	sub	a,ENDPOINT_DESCRIPTOR
	jq	z,.endpoint
repeat ENDPOINT_DESCRIPTOR-INTERFACE_DESCRIPTOR
	inc	a
end repeat
	jq	nz,.next
	ld	c,a
	ld	a,e
	cp	a,sizeof xinterfaceDescriptor
	ret	c
	ld	a,(xinterfaceDescriptor.bAlternateSetting)
	sub	a,0
label .alt at $-byte
	jq	nz,.next
	ld	c,(xinterfaceDescriptor.bNumEndpoints)
	djnz	.next
	ret

;-------------------------------------------------------------------------------
; Input:
;  a = endpoint
;  bc = ? | bytes or ? shl 16
; Output:
;  cf = error
;  zf = ? | false
_ExecuteDma:
	ld	hl,(rootHub.child)
	call	usb_GetDeviceEndpoint.enter
	ld	l,endpoint.overlay.next
	ld	ytransfer,(hl)
	ld	a,(ytransfer.status)
repeat 8-bsr ytransfer.status.active
	rlca
end repeat
	ret	nc
	ld	de,(ytransfer.remaining)
	resmsk	ytransfer.remaining.dt,de
	ld	a,i
	push	af
	ld	l,endpoint.overlay.fifo
	ld	a,(hl)
	ld	l,endpoint.maxPktLen+1
	di
	ld	(mpUsbDmaFifo),a
	ld	a,(hl)
	dec	l;endpoint.maxPktLen
	ld	l,(hl)
	and	a,7
	ld	h,a
	push	hl
	sbc.s	hl,de
	jq	c,.mpsLess
	sbc	hl,hl
.mpsLess:
	add.s	hl,de
	ld	a,b
	and	a,7
	ld	b,a
	ld	a,(ytransfer.type)
repeat bUsbDmaDir-bsf ytransfer.type.pid
	rlca
end repeat
	and	a,bmUsbDmaClrFifo or usbDmaMem2Fifo
	jq	pe,.in
	inc	bc
	dec.s	bc
	sbc	hl,bc
	jq	c,.babble
	sbc	hl,hl
	add	hl,bc
.in:
	add	hl,bc
	sbc	hl,bc
	jq	z,.zlp
	ld	(mpUsbDmaLen),hl
	ex	de,hl
	sbc	hl,de
	ld	(ytransfer.remaining),hl
	ex	(sp),hl
	sbc.s	hl,de
	ex	(sp),hl
	ex	de,hl
	ld	bc,(ytransfer.buffers)
	add	hl,bc
	ld	(ytransfer.buffers),hl
.flush:
	ld	hl,mpUsbDmaAddr
	ld	(hl),bc
	ld	l,usbDmaCtrl-$100
	ld	(hl),a
	inc	a;bmUsbDmaStart
	ld	(hl),a
.waitDma:
	ld	a,(hl)
	ld	l,usbDevIsr-$100
	bit	bUsbIntDevDmaFin,(hl)
	jq	nz,.dmaFinished
	inc	l
	bit	bUsbIntDevDmaErr-8,(hl)
	jq	z,.waitDma
	ld	a,(ytransfer.status)
	and	a,not ytransfer.status.active
	or	a,ytransfer.status.halted or ytransfer.status.bufErr
	ld	(ytransfer.status),a
	ld	(hl),bmUsbIntDevDmaErr shr 8
	dec	l
.dmaFinished:
	ld	(hl),bmUsbIntDevDmaFin
.finishZlp:
	pop	bc
	ld	a,e
	or	a,d
	ld	de,(ytransfer.endpoint)
	ld	a,(ytransfer.status)
repeat 8-bsr ytransfer.status.halted
	rlca
end repeat
	jq	c,.continue
	jq	z,.next
	ld	a,c
	or	a,b
	jq	z,.continue
	ld	bc,(ytransfer.altNext)
	bit	0,bc
	jq	z,.alt
.next:
	ld	bc,(ytransfer.next)
.alt:
	ld	e,endpoint.overlay.next
	ex	de,hl
	ld	(hl),bc
	ex	de,hl
	resmsk	ytransfer.status.active
	ld	a,(ytransfer.altNext)
	rrca
	jq	nc,.continue
	ld	l,usbDmaFifo-$100
	bit	bUsbDmaCxFifo,(hl)
	jq	nz,.cx
assert bsr transfer.next.dummy = bsf ytransfer.type.pid
	ld	a,(bc+transfer.next)
	and	a,(ytransfer.type)
repeat bsr transfer.next.dummy+1
	rrca
end repeat
	sbc	a,a
	and	a,(hl)
	ld	l,usbFifoTxImr-$100
	or	a,(hl)
	ld	(hl),a
	scf
virtual
	jp	nc,0
 assert $ = .continue
 load .jp_nc: byte from $$
end virtual
	db	.jp_nc
.cx:
	ld	l,usbCxFifo-$100
assert usbCxFifo shr 8 = bmCxFifoFin
	ld	(hl),h ; Must happen before restoring interrupts!
.continue:
	ld	l,usbDmaFifo-$100
	ld	(hl),bmUsbDmaNoFifo ; Must happen before restoring interrupts!
	pop	bc
	bit	2,c ; p/v
	jq	z,.noEi
	ei
.noEi:
	ret	nc
	ld	e,endpoint
	push	de
	ex	(sp),ix
	call	_RetireTransfers
	ccf
	pop	ix
	ret
.babble:
	ld	a,(ytransfer.status)
	and	a,not ytransfer.status.active
	or	a,ytransfer.status.halted or ytransfer.status.babble
	ld	(ytransfer.status),a
	ld	a,bmUsbDmaClrFifo or usbDmaFifo2Mem
	ld	(mpUsbDmaLen),bc
	ld	bc,vRamEnd
	jq	.flush
.zlp:
	ld	hl,mpUsbCxFifo
	and	a,usbDmaMem2Fifo
	jq	z,.finishZlp
	bit	bUsbDmaCxFifo,(hl)
	jq	nz,.finishZlp
	ld	bc,(ytransfer.endpoint)
	ld	c,endpoint.info
	ld	a,(bc)
	and	a,endpoint.info.ep
repeat bsr (usbInEp2-usbInEp1)
	add	a,a
end repeat
	add	a,usbInEp1 shl 1-usbInEp2+1-$100
	ld	l,a
	set	bUsbInEpSendZlp-8,(hl)
	jq	.finishZlp

;-------------------------------------------------------------------------------
; Input:
;  ix = endpoint
; Output:
;  cf = success
;  zf = ? | false
;  a = ?
;  bc = ?
;  de = ?
;  hl = ? | error
;  ix = endpoint
;  iy = ?
_RetireTransfers:
	or	a,a
.nc:
	sbc	hl,hl
	inc.s	bc
	lea	ytransfer.next,xendpoint.first
.continue:
	ld	ytransfer,(ytransfer.next)
.loop:
	ld	a,(ytransfer.next)
repeat bsr ytransfer.next.dummy+1
	rrca
end repeat
	ret	c
assert ytransfer.status+1 = ytransfer.type
	ld	de,(ytransfer.status)
	ld	a,e
repeat 8-bsr ytransfer.status.active
	add	a,a
end repeat
	ret	c
repeat bsr ytransfer.status.active-bsr ytransfer.status.halted
	rlca
end repeat
	jq	c,.halted
	bit	bsr ytransfer.type.pid,d ; setup
	jq	nz,.continue
	ld	c,(ytransfer.length+0)
	ld	b,(ytransfer.length+1)
	resmsk	ytransfer.remaining.dt,bc
	add	hl,bc
	ld	c,(ytransfer.remaining+0)
	ld	a,(ytransfer.remaining+1)
	and	a,not (ytransfer.remaining.dt shr 8)
	ld	b,a
	sbc	hl,bc
	or	a,c
	jq	nz,.partial
	bitmsk	ytransfer.type.ioc,d
	jq	z,.continue
.partial:
	ld	c,0
	call	_DispatchTransferCallback
	dec	hl
.free:
	call	_FreeFirstTransfer
	ld	hl,1
	add	hl,de
	jq	c,.loop
	ret
.halted:
	ld	a,d
	and	a,ytransfer.type.cerr
	ld	c,e
	jq	z,.noStall
	bitmsk	ytransfer.status.babble,e
	jq	nz,.noStall
	inc	c
.noStall:
	call	_DispatchTransferCallback
	add	hl,de
	scf
	sbc	hl,de
	inc	hl
	jq	nz,_FlushEndpoint.skip
	ld	ytransfer,(xendpoint.first)
	ld	(xendpoint.overlay.next),ytransfer
	ld	(xendpoint.overlay.altNext),ytransfer
.restart:
	ld	de,(ytransfer.length)
	ld	(ytransfer.remaining+0),e
	ld	(ytransfer.remaining+1),d
	ld	a,(ytransfer.type)
	and	a,not ytransfer.type.cpage
	or	a,ytransfer.type.cerr
	ld	(ytransfer.type),a
	bitmsk	ytransfer.status.halted
	ld	(ytransfer.status),ytransfer.status.active
	ld	ytransfer,(ytransfer.next)
	jq	z,.restart
	ld	(xendpoint.overlay.status),h;0
	scf
	ret

; Input:
;  bc = status
;  iy = endpoint
; Output:
;  cf = success
;  zf = ? | false
;  hl = 0 | error
;  iy = ?
;  ix = endpoint
_FlushEndpoint:
	lea	xendpoint,yendpoint
	ld	ytransfer,(xendpoint.first)
	or	a,a
	sbc	hl,hl
	jq	.enter
.loop:
	call	_DispatchTransferCallback
.skip:
	call	_FreeFirstTransfer
	or	a,a
	sbc	hl,hl
	adc	hl,de
	ret	nz
.enter:
	ld	a,(ytransfer.next)
repeat bsr ytransfer.next.dummy+1
	rrca
end repeat
	jq	nc,.loop
	ld	(xendpoint.overlay.next),ytransfer
	ld	(xendpoint.overlay.altNext),ytransfer
	ld	(xendpoint.overlay.status),l;0
	bitmsk	USB_TRANSFER_STALLED,bc
	ret	z
	ld	a,(xendpoint.type)
	sbc	a,l;CONTROL_TRANSFER
	ret	c
	push	xendpoint
	call	usb_ClearEndpointHalt
	pop	af
	dec	hl
	ex	de,hl
	sbc	hl,hl
	inc	l
	add	hl,de
	ret

; Input:
;  bc = status
;  hl = transferred
;  ix = endpoint
;  iy = transfer
; Output:
;  af = ?
;  bc = status
;  hl = error
;  iy = ?
_DispatchTransferCallback:
	ld	de,(ytransfer.data)
	ld	a,e
	set	3,a
	cp	a,e
	jq	z,_HandleDeviceDescriptor.returnCarry
	ld	(ytransfer.data),a
	push	bc
	ld	b,0
	ld	a,(ytransfer.data+3)
	xor	a,e
	and	a,$F
	xor	a,e
	ld	e,a
	push	de,hl,bc,xendpoint
	ld	hl,(ytransfer.callback)
	ld	a,(ytransfer.callback+3)
	xor	a,l
	and	a,$F
	xor	a,l
	ld	l,a
	call	_DispatchEvent.dispatch
	pop	bc,bc,bc,bc,bc
	ret

; Input:
;  ix = endpoint
; Output:
;  f = ?
;  zf = false
;  cf = cf
;  de = hl
;  hl = ?
;  ix = endpoint
;  iy = next transfer
_FreeFirstTransfer:
	ex	de,hl
	ld	ytransfer,(xendpoint.first)
.loop:
	lea	hl,ytransfer
	bitmsk	ytransfer.type.ioc
	ld	ytransfer,(hl+transfer.next)
	call	_Free32Align32
	jq	z,.loop
	ld	(xendpoint.first),ytransfer
	ret

;-------------------------------------------------------------------------------
_HandleGetDescriptor:
	ld	de,(ysetup.wIndex)
	ld	bc,(ysetup.wValue)
	inc	bc
	dec.s	bc
	ld	ystandardDescriptors,(currentDescriptors)
	djnz	.notDevice;DEVICE_DESCRIPTOR
	or	a,c
	or	a,e
	or	a,d
	jq	nz,_HandleCxSetupInt.unhandled
.sendSingleDescriptorIYind:
	ld	b,a
	ld	hl,(ystandardDescriptors.device)
.sendSingleDescriptorHL:
	ld	c,(hl)
	ex	de,hl
	jq	.sendDescriptor
.notDevice:
	djnz	.notConfiguration;CONFIGURATION_DESCRIPTOR
	or	a,e
	or	a,d
	jq	nz,_HandleCxSetupInt.unhandled
	ld	hl,(ystandardDescriptors.configurations)
	ld	ydeviceDescriptor,(ystandardDescriptors.device)
	ld	a,c
	cp	a,(ydeviceDescriptor.bNumConfigurations)
	jq	nc,_HandleCxSetupInt.unhandled
repeat 3
	add	hl,bc
end repeat
	ld	yconfigurationDescriptor,(hl)
	ld	bc,(yconfigurationDescriptor.wTotalLength)
	ld	de,(hl)
	jq	.sendDescriptor
.notConfiguration:
	djnz	.notString;STRING_DESCRIPTOR
	ld	hl,(ystandardDescriptors.langids)
	cp	a,c
	jq	z,.langids
	ld	a,(ystandardDescriptors.numStrings)
	cp	a,c
	jq	c,_HandleCxSetupInt.unhandled
	ld	iy,(ystandardDescriptors.strings)
	ld	a,(hl)
	rra
	dec	a
	ld	b,a
	dec	c
	mlt	bc
repeat 3
	add	iy,bc
end repeat
	ld	b,a
	inc	hl
.findLangId:
	inc	hl
	ld	a,(hl)
	inc	hl
	sub	a,e
	jq	nz,.nextLangId
	ld	a,(hl)
	sub	a,d
	jq	z,.sendSingleDescriptorIYind
.nextLangId:
	lea	iy,iy+3
	djnz	.findLangId
.langids:
	or	a,e
	or	a,d
	jq	z,.sendSingleDescriptorHL
.notString:
	jq	_HandleCxSetupInt.unhandled

;	ld	hl,(currentDescriptors)
;	ld	ydeviceDescriptor,(hl+currentDescriptors.device)
;	ld	a,(ydeviceDescripter.bMaxPacketSize0)
.sendDescriptor:
	ld	hl,mpUsbDmaFifo
	ld	(hl),bmUsbDmaCxFifo
	ld	l,usbDmaAddr-$100
	ld	(hl),de
	ld	l,usbDmaCtrl-$100
	ld	a,(setupPacket.bmRequestType)
	rlca
	rlca
	xor	a,(hl)
	and	a,usbDmaMem2Fifo
	xor	a,(hl)
	ld	(hl),a
	inc	l;usbDmaLen-$100
	ex	de,hl
	ld	hl,(setupPacket.wLength)
	sbc.s	hl,bc
	jq	c,.min
	sbc	hl,hl
.min:
	add.s	hl,bc
	ex	de,hl
	ld	(hl),de
	dec	l;usbDmaCtrl-$100
	set	bUsbDmaStart,(hl)
	ld	l,usbDevIsr-$100
.wait:
	bit	bUsbIntDevDmaFin,(hl)
	jq	z,.wait
	ld	(hl),bmUsbIntDevDmaFin
	xor	a,a
	ld	l,usbDmaFifo-$100
	ld	(hl),a
	jq	_HandleCxSetupInt.handled

_HandleCxSetupInt:
	ld	b,4
	ld	de,setupPacket+4
	ld	l,usbDmaFifo-$100
	ld	a,i
	di
	ld	(hl),bmUsbDmaCxFifo
	ld	l,usbEp0Data+4-$100
.fetch:
	dec	hl
	dec	de
	ld	a,(hl)
	ld	(de),a
	setmsk	4,de
	ld	a,(hl)
	ld	(de),a
	resmsk	4,de
	djnz	.fetch
	ld	l,usbDmaFifo-$100
	jq	po,.noEi
	ei
.noEi:
	ld	(hl),b;bmUsbDmaNoFifo
	ld	l,usbCxFifo-$100
	set	bCxFifoClr,(hl)
	ld	a,USB_DEFAULT_SETUP_EVENT
	call	_DispatchEvent
	jq	z,.defaultHandler
	add	hl,de
	scf
	sbc	hl,de
	inc	hl
	ret	nz
	ld	hl,mpUsbCxIsr
	ld	(hl),bmUsbIntCxSetup
	ret
.defaultHandler:
	ld	ysetup,setupPacket
	ld	bc,(ysetup.bmRequestType)
	inc	b
	djnz	.notGetStatus
	ld	a,c
	sub	a,DEVICE_TO_HOST or STANDARD_REQUEST-1
	ld	b,a
	ld	c,2
	ld	de,(ysetup.wLength)
	ld	a,e
	xor	a,c
	or	a,d
	ld	de,(ysetup.wValue)
	or	a,e
	or	a,d
	ld	de,(ysetup.wIndex)
	or	a,d
	jq	nz,.unhandled
	or	a,e
	ld	de,tempEndpointStatus
	djnz	.notGetDeviceStatus
	jq	nz,.unhandled
	ld	(de),a
assert tempEndpointStatus-1 = deviceStatus
	dec	de
	jq	_HandleGetDescriptor.sendDescriptor
.notGetDeviceStatus:
	djnz	.notGetInterfaceStatus
	xor	a,a
.sendStatus:
	ld	(de),a
	jq	_HandleGetDescriptor.sendDescriptor
.notGetInterfaceStatus:
	djnz	.notGetEndpointStatus
	add	a,a
	jq	z,.sendStatus
	ld	hl,mpUsbOutEp1+2-4
	jq	nc,.out
assert usbInEp1 < usbOutEp1
	resmsk	(usbInEp1-2) xor (usbOutEp1-2),hl
.out:
	cp	a,(8+1) shl 1
	jq	nc,.unhandled
repeat 2
	add	a,l
end repeat
	ld	l,a
	ld	a,(hl)
repeat bUsbEpStall-8
	rrca
end repeat
	and	a,1
	jq	.sendStatus
.notGetEndpointStatus:
	jq	.unhandled
.notGetStatus:
	djnz	.notClearFeature
.notClearFeature:
	dec	b
	djnz	.notSetFeature
.notSetFeature:
	dec	b
	djnz	.notSetAddress
	ld	de,(ysetup.wValue)
	ld	a,e
	and	a,$80
	or	a,d
	or	a,c
	ld	bc,(ysetup.wIndex)
	or	a,c
	or	a,b
	ld	bc,(ysetup.wLength)
	or	a,c
	or	a,b
	jq	nz,.unhandled
	ld	l,usbDevAddr-$100
	ld	(hl),e
	jq	.handled
.notSetAddress:
	djnz	.notGetDescriptor
	ld	a,c
	xor	a,DEVICE_TO_HOST or STANDARD_REQUEST or RECIPIENT_DEVICE
	jq	z,_HandleGetDescriptor
.notGetDescriptor:
	djnz	.notSetDescriptor
.notSetDescriptor:
	djnz	.notGetConfiguration
	ld	a,c
	xor	a,DEVICE_TO_HOST or STANDARD_REQUEST or RECIPIENT_DEVICE
	ld	bc,(ysetup.wValue)
	or	a,c
	ld	a,b
	ld	bc,(ysetup.wIndex)
	or	a,c
	or	a,b
	ld	bc,(ysetup.wLength)
	dec	c
	or	a,c
	inc	c
	or	a,b
	ld	de,selectedConfiguration
	jq	z,_HandleGetDescriptor.sendDescriptor
	ld	b,a
.notGetConfiguration:
	djnz	.notSetConfiguration
	ld	de,(ysetup.wValue)
	ld	a,d
	or	a,c
	ld	bc,(ysetup.wIndex)
	or	a,c
	or	a,b
	ld	bc,(ysetup.wLength)
	or	a,c
	or	a,b
	jq	nz,.unhandled
	or	a,e
	jq	z,.setConfigured
	push	ix
	ld	xstandardDescriptors,(currentDescriptors)
	ld	ydeviceDescriptor,(xstandardDescriptors.device)
	ld	b,(ydeviceDescriptor.bNumConfigurations)
	ld	hl,(xstandardDescriptors.configurations)
.findConfigurationDescriptor:
	ld	xconfigurationDescriptor,(hl)
	xor	a,(xconfigurationDescriptor.bConfigurationValue)
	jq	z,.foundConfigurationDescriptor
repeat long
	inc	hl
end repeat
	ld	a,e
	djnz	.findConfigurationDescriptor
.foundConfigurationDescriptor:
	ld	ydevice,(rootHub.child)
	ld	de,(xconfigurationDescriptor.wTotalLength)
	ld	b,(xconfigurationDescriptor.bNumInterfaces)
	call	z,_ParseInterfaceDescriptors
	pop	ix
	jq	nz,.unhandled
	lea	de,ydevice
	ld	a,USB_HOST_CONFIGURE_EVENT
	call	_DispatchEvent
	ret	nz
	ld	a,(setupPacket.wValue)
	scf
.setConfigured:
	ld	(selectedConfiguration),a
	ld	hl,mpUsbDevAddr
	ld	a,(hl)
	rla
	rrca
	ld	(hl),a
	jq	.handled
.notSetConfiguration:
	djnz	.notGetInterface
.notGetInterface:
	djnz	.notSetInterface
.notSetInterface:
.unhandled:
	ld	hl,mpUsbCxFifo
	set	bCxFifoStall,(hl)
	jq	.return
.handled:
	ld	l,usbCxFifo-$100
	ld	(hl),bmCxFifoFin
.return:
	ld	l,usbCxIsr-$100
	ld	(hl),bmUsbIntCxSetup
	cp	a,a
	ret

_HandleDeviceDescriptor:
	ld	hl,3
	add	hl,sp
	ld	yendpoint,(hl)
repeat long
	inc	hl
end repeat
	ld	b,(hl)
repeat long
	inc	hl
end repeat
	ld	a,(hl)
	xor	a,8
	or	a,b
	jq	nz,.free
repeat long
	inc	hl
end repeat
	ld	de,(hl)
	ld	(de),a
	ld	hl,usedAddresses
	ld	b,sizeof usedAddresses
	scf
.search:
	ld	c,(hl)
	adc	a,c
	jq	c,.next
	or	a,c
	ld	(hl),a
	xor	a,c
	ld	c,8
	mlt	bc
.shift:
	dec	c
	rrca
	jq	nc,.shift
	sbc	a,c
	ex	de,hl
	ld	bc,_HandleDeviceEnable
	push	hl,bc,bc,hl,yendpoint
	inc	l
	ld	(hl),SET_ADDRESS
	ld	b,6
.zero:
	inc	l
	ld	c,(hl)
	ld	(hl),a
	xor	a,a
	djnz	.zero
	ld	(yendpoint.maxPktLen),c
	call	usb_ScheduleControlTransfer
	ld	a,l
	pop	bc,bc,bc,bc,bc
	or	a,a
	ret	z
virtual
	ld	hl,0
 assert $ = .free
 load .ld_hl: byte from $$
end virtual
	db	.ld_hl
.next:
	inc	l
	djnz	.search
.free:
	call	_FreeTransferData
.disable:
	call	_HandlePortPortEnInt.disable
.returnCarry:
	sbc	hl,hl
	ret

_HandleDeviceEnable:
	ld	hl,12
	add	hl,sp
	ld	hl,(hl)
	setmsk	2,hl
	ld	c,(hl)
	call	_FreeTransferData
	ld	hl,3
	add	hl,sp
	ld	yendpoint,(hl)
repeat long
	inc	hl
end repeat
	ld	a,(hl)
	or	a,a
	jq	nz,_HandleDeviceDescriptor.disable
	sbc	hl,hl
	ld	de,(yendpoint.device)
	ld	(yendpoint.addr),c
	ld	ydevice,(yendpoint.device)
	ld	(ydevice.addr),c
	ld	a,USB_DEVICE_ENABLED_EVENT
	jq	_DispatchEvent

_HandleDevInt:
	ld	l,usbGisr-$100
	inc	h
iterate type, Cx, Fifo, Dev
	bit	bUsbDevInt#type,(hl)
	call	nz,_HandleDev#type#Int
	ret	nz
end iterate
	ld	l,usbIsr
	dec	h
	ld	(hl),bmUsbIntDev
	ld	a,USB_DEVICE_INTERRUPT
	jq	_DispatchEvent

_HandleDevCxInt:
	ld	l,usbCxIsr-$100
iterate type, Setup, In, Out, End, Err, Abort
	bit	bUsbIntCx#type,(hl)
	call	nz,_HandleCx#type#Int
	ret	nz
end iterate
	ld	l,usbGisr-$100
	ld	(hl),bmUsbDevIntCx
	ld	a,USB_DEVICE_CONTROL_INTERRUPT
	jq	_DispatchEvent

_HandleDevFifoInt:
	ld	l,usbFifoRxIsr-$100
repeat 4, fifo: 0
 iterate type, Spk, Out
	bit	bUsbIntFifo#fifo#type,(hl)
	call	nz,_HandleFifo#fifo#type#Int
	ret	nz
 end iterate
end repeat
	ld	l,usbFifoTxImr-$100
	ld	a,(hl)
	cpl
	ld	l,usbFifoTxIsr-$100
	and	a,(hl)
	ld	c,a
repeat 4, fifo: 0
 iterate type, In
	push	bc
	bit	bUsbIntFifo#fifo#type,c
	call	nz,_HandleFifo#fifo#type#Int
	pop	bc
	ret	nz
 end iterate
end repeat
	ld	l,usbGisr-$100
	ld	(hl),bmUsbDevIntFifo
	ret

_HandleDevDevInt:
	ld	l,usbDevIsr-$100
iterate type, Reset, Suspend, Resume, IsocErr, IsocAbt, ZlpTx, ZlpRx, DmaFin
	bit	bUsbIntDev#type,(hl)
	call	nz,_HandleDev#type#Int
	ret	nz
end iterate
	inc	l;usbDevIsr+1-$100
iterate type, DmaErr, Idle, Wakeup
	bit	bUsbIntDev#type-8,(hl)
	call	nz,_HandleDev#type#Int
	ret	nz
end iterate
	ld	l,usbGisr-$100
	ld	(hl),bmUsbDevIntDev
	ld	a,USB_DEVICE_DEVICE_INTERRUPT
	jq	_DispatchEvent

_HandleOtgInt:
	ld	l,usbOtgIsr
iterate type, BSrpComplete, ASrpDetect, AVbusErr, BSessEnd
	bit	bUsbInt#type,(hl)
	call	nz,_Handle#type#Int
	ret	nz
end iterate
	inc	l;usbOtgIsr+1
iterate type, RoleChg, IdChg, Overcurr, BPlugRemoved, APlugRemoved
	bit	bUsbInt#type-8,(hl)
	call	nz,_Handle#type#Int
	ret	nz
end iterate
	ld	l,usbIsr
	ld	(hl),bmUsbIntOtg
	ld	a,USB_OTG_INTERRUPT
	jq	_DispatchEvent

_HandleHostInt:
	ld	l,usbSts
	ld	a,0
label .hack at $-byte
	and	a,bmUsbIntErr or bmUsbInt
	call	nz,_HandleCompletionInt
	ret	nz
	ld	hl,mpUsbSts
iterate type, PortChgDetect, FrameListOver, HostSysErr, AsyncAdv
	bit	bUsbInt#type,(hl)
	call	nz,_Handle#type#Int
	ret	nz
end iterate
	ld	l,usbIsr
	ld	(hl),bmUsbIntHost
	ld	a,USB_HOST_INTERRUPT
	jq	_DispatchEvent

_HandleCxInInt:
_HandleCxOutInt:
	ld	l,usbCxFifoBytes-$100
	ld	c,(hl)
	xor	a,a
	ld	b,a
	call	_ExecuteDma
	ret	c
	ld	hl,mpUsbCxIsr
	ld	(hl),bmUsbIntCxOut or bmUsbIntCxIn
	cp	a,a
	ret

_HandleCxEndInt:
	ld	l,usbCxFifo-$100
	ld	(hl),bmCxFifoFin
	ld	l,usbCxIsr-$100
	ld	(hl),bmUsbIntCxEnd
	cp	a,a
	ret

_HandleCxErrInt:
	ld	(hl),bmUsbIntCxErr
	ld	a,USB_CONTROL_ERROR_INTERRUPT
	jq	_DispatchEvent

_HandleCxAbortInt:
	ld	(hl),bmUsbIntCxAbort
	ld	a,USB_CONTROL_ABORT_INTERRUPT
	jq	_DispatchEvent

repeat 4, fifo: 0
_HandleFifo#fifo#OutInt:
	ld	l,usbFifo#fifo#Csr-$100
	ld	bc,(hl)
	ld	a,fifo+$01
	call	_ExecuteDma
	ret	c
	ld	hl,mpUsbFifoRxIsr
	ld	(hl),bmUsbIntFifo#fifo#Out
	cp	a,a
	ret

_HandleFifo#fifo#SpkInt:
	ld	(hl),bmUsbIntFifo#fifo#Spk
	ld	a,USB_FIFO#fifo#_SHORT_PACKET_INTERRUPT
	jq	_DispatchEvent

_HandleFifo#fifo#InInt:
	ld	a,fifo+$81
	call	_ExecuteDma
	ret	c
	ld	hl,mpUsbFifoTxIsr
	ld	(hl),bmUsbIntFifo#fifo#In
	cp	a,a
	ret
end repeat

_HandleDevResetInt:
	xor	a,a
	ld	l,usbDevAddr-$100
	ld	(hl),a
	ld	(selectedConfiguration),a
	inc	a
	ld	(deviceStatus),a
	ld	l,usbDmaCtrl-$100
	ld	(hl),bmUsbDmaClrFifo or bmUsbDmaAbort
	ld	l,usbCxFifo-$100
	set	bCxFifoClr,(hl)
	ld	de,rootHub
	ld	bc,(1 shl 7 or 1) shl 8 or IS_DEVICE or IS_ENABLED
	ld	l,usbDevCtrl-$100
	call	_CreateDevice
	call	z,_CreateDefaultControlEndpoint
	jq	nz,.nomem
	ld	hl,(currentDescriptors)
	ld	hl,(hl)
	ld	de,7
	add	hl,de
	ld	a,(hl)
	ld	(yendpoint.maxPktLen),a
.nomem:
	ld	hl,mpUsbDevIsr
	ld	(hl),bmUsbIntDevReset
	cp	a,a
	ret

_HandleDevSuspendInt:
	ld	(hl),bmUsbIntDevSuspend
	ld	a,USB_DEVICE_SUSPEND_INTERRUPT
	jq	_DispatchEvent

_HandleDevResumeInt:
	ld	(hl),bmUsbIntDevResume
	ld	a,USB_DEVICE_RESUME_INTERRUPT
	jq	_DispatchEvent

_HandleDevIsocErrInt:
	ld	(hl),bmUsbIntDevIsocErr
	ld	a,USB_DEVICE_ISOCHRONOUS_ERROR_INTERRUPT
	jq	_DispatchEvent

_HandleDevIsocAbtInt:
	ld	(hl),bmUsbIntDevIsocAbt
	ld	a,USB_DEVICE_ISOCHRONOUS_ABORT_INTERRUPT
	jq	_DispatchEvent

_HandleDevZlpTxInt:
	ld	l,usbTxZlp-$100
	xor	a,a
	ld	(hl),a
	ld	l,usbDevIsr-$100
	ld	(hl),bmUsbIntDevZlpTx
	ret

_HandleDevZlpRxInt:
	ld	l,usbRxZlp-$100
	call	.almostMostAtomicExchangePossible
.loop:
	inc	b
	srl	c
	push	bc
	ld	a,b
	ld	b,0
	ld	c,b
	call	c,_ExecuteDma
	pop	bc
	ret	c
	inc	c
	dec	c
	jq	nz,.loop
	ld	hl,mpUsbDevIsr
	ld	(hl),bmUsbIntDevZlpRx
	ret

.almostMostAtomicExchangePossible:
	ld	a,i
virtual at mpLcdLpbase+1
	ld	c,(hl)
	ld	(hl),b
	ret
 load .exchange $-$$ from $$
end virtual
	ld	iy,mpLcdRange
	ld	bc,.exchange
	di
	ld	de,(iy+lcdLpbase+1)
	ld	(iy+lcdLpbase+1),bc
	ld	b,0
	call	mpLcdLpbase+1
	ld	(iy+lcdLpbase+1),de
	ret	po
	ei
	ret

_HandleDevDmaFinInt:
	ld	(hl),bmUsbIntDevDmaFin
	ld	a,USB_DEVICE_DMA_FINISH_INTERRUPT
	jq	_DispatchEvent

_HandleDevDmaErrInt:
	ld	(hl),bmUsbIntDevDmaErr shr 8
	ld	a,USB_DEVICE_DMA_ERROR_INTERRUPT
	jq	_DispatchEvent

_HandleDevIdleInt:
	ld	(hl),bmUsbIntDevIdle shr 8
	ld	a,USB_DEVICE_IDLE_INTERRUPT
	jq	_DispatchEvent

_HandleDevWakeupInt:
	ld	l,usbPhyTmsr-$100
	res	bUsbUnplug,(hl)
	ld	l,usbDevIsr+1-$100
	ld	(hl),bmUsbIntDevWakeup shr 8
	ld	a,USB_DEVICE_WAKEUP_INTERRUPT
	jq	_DispatchEvent

_HandleBSrpCompleteInt:
	ld	(hl),bmUsbIntBSrpComplete
	ld	a,USB_B_SRP_COMPLETE_INTERRUPT
	jq	_DispatchEvent

_HandleASrpDetectInt:
	ld	(hl),bmUsbIntASrpDetect
	ld	a,USB_A_SRP_DETECT_INTERRUPT
	jq	_DispatchEvent

_HandleAVbusErrInt:
	ld	(hl),bmUsbIntAVbusErr
	ld	a,USB_A_VBUS_ERROR_INTERRUPT
	jq	_DispatchEvent

_HandleBSessEndInt:
	ld	(hl),bmUsbIntBSessEnd
	ld	a,USB_B_SESSION_END_INTERRUPT
	jq	_DispatchEvent

_HandleRoleChgInt:
_HandleIdChgInt:
	ld	de,currentRole
	ld	a,(de)
	ld	c,a
	ld	(hl),(bmUsbIntRoleChg or bmUsbIntIdChg) shr 8
	ld	a,(mpUsbOtgCsr+2)
	and	a,(bmUsbRole or bmUsbId) shr 16
	cp	a,c
	ret	z
	ld	(de),a
	call	_PowerVbusForRole
assert ~USB_ROLE_CHANGED_EVENT
	xor	a,a;USB_ROLE_CHANGED_EVENT
	ld	l,usbOtgIsr+1
	jq	_DispatchEvent

_HandleOvercurrInt:
	ld	(hl),bmUsbIntOvercurr shr 8
	ld	a,USB_OVERCURRENT_INTERRUPT
	jq	_DispatchEvent

_HandleAPlugRemovedInt:
_HandleBPlugRemovedInt:
	ld	(hl),(bmUsbIntAPlugRemoved or bmUsbIntBPlugRemoved) shr 8
	jq	_RootDeviceDisconnected

; Output:
;  zf = success
;  de = ? | hl
;  hl = hl | error
;  iy = ?
_RootDeviceDisconnected:
	ld	de,_DeviceDisconnected
.enter:
	ex	de,hl
	push	de,ix
	ld	xdevice,(rootHub.child)
	dec	ixl
	call	nz,_DispatchEvent.dispatch
	pop	ix,de
	ret	nz
	ex	de,hl
	ret

_HandleCompletionInt:
	ld	(hl),a
usb_PollTransfers:
	push	ix
	ld	xendpoint,(dummyHead.next)
.loop:
	or	a,a
	sbc	hl,hl
	ld	a,ixh
	xor	a,dummyHead shr 8 and $FF
	jq	z,.done
	call	_RetireTransfers.nc
	ld	xendpoint,(xendpoint.next)
	jq	c,.loop
.done:
	pop	ix
	ret

_HandlePortChgDetectInt:
	ld	(hl),bmUsbIntPortChgDetect
	ld	l,usbPortStsCtrl
iterate type, ConnSts, PortEn, Overcurr
	bit	bUsb#type#Chg, (hl)
	call	nz,_HandlePort#type#Int
	ret	nz
end iterate
	ld	l,usbSts
	ret

_HandlePortConnStsInt:
	call	_RootDeviceDisconnected
	ret	nz
	ld	a,(hl)
	and	a,not (bmUsbOvercurrChg or bmUsbPortEnChg or bmUsbPortEn)
	ld	(hl),a
	bit	bUsbCurConnSts,(hl)
	ret	z
	ld	de,rootHub
	ld	bc,(1 shl 7 or 1) shl 8 or IS_DEVICE or IS_DISABLED
	ld	l,usbOtgCsr+2
	call	_CreateDevice
	ld	hl,USB_ERROR_NO_MEMORY
	ret	nz ; FIXME
	ld	hl,mpUsbPortStsCtrl
	lea	de,ydevice
	ld	a,USB_DEVICE_CONNECTED_EVENT
	jq	_DispatchEvent

_HandlePortPortEnInt:
	ld	a,(hl)
	and	a,not (bmUsbOvercurrChg or bmUsbConnStsChg)
	ld	(hl),a
	ld	de,_DeviceDisabled
	bit	bUsbPortEn,(hl)
	jq	z,_RootDeviceDisconnected.enter
	ld	ydevice,(rootHub.child)
	ld	a,iyl
	cp	a,a
	rrca
	ret	c
	resmsk	IS_DISABLED,(ydevice.find)
	setmsk	IS_ENABLED,(ydevice.find)
	call	_CreateDefaultControlEndpoint
	call	z,_Alloc32Align32
	jq	nz,.disable
	ld	bc,_HandleDeviceDescriptor
	ld	de,_GetDeviceDescriptor8
	push	hl,bc,hl,de,yendpoint
	call	usb_ScheduleControlTransfer
	pop	de,de,de,de,de
	ld	a,l
	ld	hl,mpUsbPortStsCtrl
	or	a,a
	ret	z
	ex	de,hl
	call	_Free32Align32
.disable:
	ld	hl,mpUsbPortStsCtrl
	ld	a,(hl)
	and	a,not (bmUsbOvercurrChg or bmUsbPortEnChg or bmUsbPortEn or bmUsbConnStsChg)
	ld	(hl),a
	cp	a,a
	ret

_HandlePortOvercurrInt:
	ld	a,(hl)
	and	a,not (bmUsbPortEnChg or bmUsbConnStsChg)
	ld	(hl),a
	ld	a,(hl)
	and	a,bmUsbOvercurrActive
	cp	a,bmUsbOvercurrActive
	sbc	a,a
assert USB_DEVICE_OVERCURRENT_ACTIVATED_EVENT - 1 = USB_DEVICE_OVERCURRENT_DEACTIVATED_EVENT
	add	a,USB_DEVICE_OVERCURRENT_ACTIVATED_EVENT;USB_DEVICE_OVERCURRENT_DEACTIVATED_EVENT
	jq	_DispatchEvent

_HandleFrameListOverInt:
	ld	(hl),bmUsbIntFrameListOver
	ld	a,USB_HOST_FRAME_LIST_ROLLOVER_INTERRUPT
	jq	_DispatchEvent

_HandleHostSysErrInt:
	ld	(hl),bmUsbIntHostSysErr
	ld	a,USB_HOST_SYSTEM_ERROR_INTERRUPT
	jq	_DispatchEvent

_HandleAsyncAdvInt:
	ld	(hl),bmUsbIntAsyncAdv
.cleanup.hl:
	ex	de,hl
.cleanup.de:
	ld	a,(cleanupListReady)
	ld	yendpoint,dummyHead
	jq	.enter
.loop:
	ld	a,(yendpoint.prev)
	ld	hl,(yendpoint.last)
	call	_Free32Align32
	lea	hl,yendpoint.base
	call	_Free64Align256
.enter:
	ld	iyh,a
	inc	a
	jq	nz,.loop
	scf
.scheduleCleanup.de:
	ex	de,hl
.scheduleCleanup.hl:
	ret	nz
	sbc	a,a
	ld	de,(cleanupListReady)
	scf
	adc	a,e
	sbc	a,a
	ret	z
	ld	(cleanupListReady-1),de
	inc	d
	ret	z
	ld	a,l
	ld	l,usbCmd
	set	bUsbIntAsyncAdvDrbl,(hl)
	ld	l,a
	cp	a,a
	ret

;-------------------------------------------------------------------------------
_DispatchEvent:
	push	hl
	ld	hl,(eventCallback.data)
	push	hl,de
	or	a,a
	sbc	hl,hl
	ld	l,a
	push	hl
	ld	l,h
	ex	de,hl
	ld	hl,(eventCallback)
	sbc	hl,de
	call	nz,.dispatch
	pop	de,de,de,de
	add	hl,de
	or	a,a
	sbc	hl,de
	ret	nz
	ex	de,hl
	ret

;-------------------------------------------------------------------------------
usb_StartTimer:
	ret

;-------------------------------------------------------------------------------
usb_RepeatTimer:
	ret

;-------------------------------------------------------------------------------
usb_StartCycleTimer:
	ret

;-------------------------------------------------------------------------------
usb_RepeatCycleTimer:
	ret

;-------------------------------------------------------------------------------
usb_GetCycleCounter:
	call	usb_GetCycleCounterHigh
	dec	sp
	dec	sp
	push	hl
	dec	sp
	pop	hl,de
	ld	l,a
	ret

;-------------------------------------------------------------------------------
usb_GetCycleCounterHigh:
	ld	hl,(mpIntInvert+$20) or (intLatch+$20) shl 8
	ld	a,i
	di
	ld	a,(hl)
	push	af
	ld	(hl),.ret
	ld	l,h;ti.intLatch+$20
	ld	de,(hl)
	push	de
	ld	de,.ld_auhl_tmr2Counter
	ld	(hl),de
	ld	iy,mpTmr2Counter+1
.tmrBase := iy-tmr2Counter-1
	lea	hl,.tmrBase+tmr2Counter
virtual at mpIntLatch+$20
	ld	a,(hl)
	ld	hl,(.tmrBase+tmr2Counter+1)
 load .ld_auhl_tmr2Counter: $-$$ from $$
 assert .ld_auhl_tmr2Counter < 1 shl 22
end virtual
virtual at mpIntInvert+$20
	ret
 load .ret: $-$$ from $$
 assert .ret < 1 shl 8
end virtual
	call	mpIntLatch+$20
	ld	iy,mpIntRange+$20
	pop	de
	ld	(iy+intLatch),de
	pop	de
	ld	(iy+intInvert),d
	bit	2,e ; p/v flag
	jq	z,.noEi
	ei
.noEi:
	add	a,3 shl 2
	add	a,3 shl 1
	ret	nc
	inc	l
	ret	nz
	cp	a,3 shl 0
	ret	nc
	inc	h
	ret

;-------------------------------------------------------------------------------
_DefaultControlEndpointDescriptor:
	db 7, ENDPOINT_DESCRIPTOR, 0, 0
	dw 8
	db 0
_GetDeviceDescriptor8:
	db DEVICE_TO_HOST or STANDARD_REQUEST or RECIPIENT_DEVICE, GET_DESCRIPTOR, 0, DEVICE_DESCRIPTOR
	dw 0, 8
_DefaultStandardDescriptors:
	dl .device, .configurations, .langids
	db 2
	dl .strings
.device emit $12: $1201000200000040510408E0200201020003 bswap $12
.configurations dl .configuration1, .configuration2, .configuration3
.configuration1 emit $23: $0902230001010080FA0904000002FF0100000705810240000007050202400000030903 bswap $23
.configuration2 emit $23: $09022300010200C0000904000002FF0100000705810240000007050202400000030903 bswap $23
.configuration3 emit $23: $0902230001030080320904000002FF0100000705810240000007050202400000030903 bswap $23
.langids dw $0304, $0409
.strings dl .string1
.model dl .string84
.string1 dw $033E, 'T','e','x','a','s',' ','I','n','s','t','r','u','m','e','n','t','s',' ','I','n','c','o','r','p','o','r','a','t','e','d'
.string83 dw $0322, 'T','I','-','8','3',' ','P','r','e','m','i','u','m',' ','C','E'
.string84 dw $031C, 'T','I','-','8','4',' ','P','l','u','s',' ','C','E'
