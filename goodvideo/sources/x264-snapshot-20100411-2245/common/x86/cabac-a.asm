;*****************************************************************************
;* cabac-a.asm: h264 encoder library
;*****************************************************************************
;* Copyright (C) 2008 x264 project
;*
;* Author: Loren Merritt <lorenm@u.washington.edu>
;*         Jason Garrett-Glaser <darkshikari@gmail.com>
;*         Holger Lubitz <holger@lubitz.org>
;*
;* This program is free software; you can redistribute it and/or modify
;* it under the terms of the GNU General Public License as published by
;* the Free Software Foundation; either version 2 of the License, or
;* (at your option) any later version.
;*
;* This program is distributed in the hope that it will be useful,
;* but WITHOUT ANY WARRANTY; without even the implied warranty of
;* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;* GNU General Public License for more details.
;*
;* You should have received a copy of the GNU General Public License
;* along with this program; if not, write to the Free Software
;* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02111, USA.
;*****************************************************************************

%include "x86inc.asm"

SECTION_RODATA

SECTION .text

cextern x264_cabac_range_lps
cextern x264_cabac_transition
cextern x264_cabac_renorm_shift

; t3 must be ecx, since it's used for shift.
%ifdef WIN64
    DECLARE_REG_TMP 3,1,2,0,4,5,6,10
    %define pointer resq
%elifdef ARCH_X86_64
    DECLARE_REG_TMP 0,1,2,3,4,5,6,10
    %define pointer resq
%else
    DECLARE_REG_TMP 0,4,2,1,3,5,6,2
    %define pointer resd
%endif

struc cb
    .low: resd 1
    .range: resd 1
    .queue: resd 1
    .bytes_outstanding: resd 1
    .start: pointer 1
    .p: pointer 1
    .end: pointer 1
    align 16, resb 1
    .bits_encoded: resd 1
    .state: resb 460
endstruc

%macro LOAD_GLOBAL 4
%ifdef PIC
    ; this would be faster if the arrays were declared in asm, so that I didn't have to duplicate the lea
    lea   r11, [%2]
    %ifnidn %3, 0
    add   r11, %3
    %endif
    movzx %1, byte [r11+%4]
%else
    movzx %1, byte [%2+%3+%4]
%endif
%endmacro

cglobal x264_cabac_encode_decision_asm, 0,7
    movifnidn t0,  r0mp
    movifnidn t1d, r1m
    mov   t5d, [t0+cb.range]
    movzx t6d, byte [t0+cb.state+t1]
    mov   t3d, t5d
    shr   t5d, 6
    movifnidn t2d, r2m
    LOAD_GLOBAL t5d, x264_cabac_range_lps-4, t5, t6*4
    LOAD_GLOBAL t4d, x264_cabac_transition, t2, t6*2
    shr   t6d, 6
    sub   t3d, t5d
    cmp   t6d, t2d
    mov   t6d, [t0+cb.low]
    lea   t7,  [t6+t3]
    cmovne t3d, t5d
    cmovne t6d, t7d
    mov   [t0+cb.state+t1], t4b
;x264_cabac_encode_renorm
    mov   t4d, t3d
    shr   t3d, 3
    LOAD_GLOBAL t3d, x264_cabac_renorm_shift, 0, t3
    shl   t4d, t3b
    shl   t6d, t3b
    add   t3d, [t0+cb.queue]
    mov   [t0+cb.range], t4d
    cmp   t3d, 8
    jl .update_queue_low
;x264_cabac_putbyte
    ; alive: t0=cb t3=queue t6=low
%ifdef WIN64
    DECLARE_REG_TMP 3,4,1,0,2,5,6,10
%endif
    mov   t1d, -1
    add   t3d, 2
    mov   t2d, t6d
    shl   t1d, t3b
    shr   t2d, t3b ; out
    not   t1d
    sub   t3d, 10
    and   t6d, t1d
    mov   t5d, [t0+cb.bytes_outstanding]
    cmp   t2b, 0xff ; FIXME is a 32bit op faster?
    jz    .postpone
    mov   t1,  [t0+cb.p]
    add   [t1-1], dh ; t2h
    dec   dh
.loop_outstanding:
    mov   [t1], dh
    inc   t1
    dec   t5d
    jge .loop_outstanding
    mov   [t1-1], t2b
    mov   [t0+cb.p], t1
.postpone:
    inc   t5d
    mov   [t0+cb.bytes_outstanding], t5d
.update_queue_low:
    mov   [t0+cb.low], t6d
    mov   [t0+cb.queue], t3d
    RET

