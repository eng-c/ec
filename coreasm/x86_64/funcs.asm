; funcs.asm
; x86_64 SysV ABI function/stack helpers for NASM/YASM
;
; Goals:
; - Make it impossible to "forget" stack frame allocation.
; - Keep 16-byte stack alignment at call sites.
; - Provide a small abstraction layer your codegen can target.
;
; Assumptions:
; - Linux/macOS style SysV x86_64 calling convention.
; - NASM/YASM syntax.
;
; Notes on alignment:
; After the caller executes `call`, RSP is misaligned by 8.
; `push rbp` restores 16B alignment.
; Therefore, after `push rbp`, subtracting a 16B-multiple keeps
; the stack 16B-aligned for subsequent calls inside the function.

%ifndef FUNCS_ASM_INCLUDED
%define FUNCS_ASM_INCLUDED 1

; ----------------------------
; Compile-time utilities
; ----------------------------

; ALIGN_UP_16(x) => (x + 15) & ~15
%define ALIGN_UP_16(x) (((x) + 15) & -16)

; ----------------------------
; Basic prologue/epilogue
; ----------------------------

; FUNC_PROLOGUE locals_bytes
; - Establishes frame pointer (RBP)
; - Allocates locals on stack (rounded up to 16)
%macro FUNC_PROLOGUE 1
    push rbp
    mov  rbp, rsp
%if %1 > 0
    sub  rsp, ALIGN_UP_16(%1)
%endif
%endmacro

; FUNC_EPILOGUE
%macro FUNC_EPILOGUE 0
    leave
    ret
%endmacro

; ----------------------------
; Convenience labels
; ----------------------------

; FUNC_BEGIN name, locals_bytes
%macro FUNC_BEGIN 2
global %1
%1:
    FUNC_PROLOGUE %2
%endmacro

; FUNC_END
%macro FUNC_END 0
    FUNC_EPILOGUE
%endmacro

; ----------------------------
; Callee-saved register helpers (SysV)
; ----------------------------
; Callee-saved: RBX, RBP, R12-R15.
; RBP is handled by the prologue/epilogue.
;
; Use these only if your function actually clobbers them.
; Example:
;   SAVE_CALLEE_SAVED rbx, r12, r13
;   ...
;   RESTORE_CALLEE_SAVED r13, r12, rbx
;
; (Order matters: restore in reverse order.)

%macro SAVE_CALLEE_SAVED 1-*
%rep %0
    push %1
%rotate 1
%endrep
%endmacro

%macro RESTORE_CALLEE_SAVED 1-*
%rep %0
    pop %1
%rotate 1
%endrep
%endmacro

; ----------------------------
; Dynamic stack allocation (optional)
; ----------------------------
; For future features like alloca/VLAs.
;
; DYN_ALLOC size_reg, scratch_reg
; - size_reg: register containing requested bytes (runtime value)
; - scratch_reg: temp register (will be clobbered)
; Effect:
;   size_reg becomes aligned size (16B)
;   RSP -= aligned size
;
; You must restore RSP later (e.g., by saving old RSP in a stack slot
; or callee-saved register and restoring it).

%macro DYN_ALLOC 2
    mov  %2, %1         ; scratch = size
    add  %2, 15
    and  %2, -16
    sub  rsp, %2
    mov  %1, %2         ; return aligned size in size_reg (optional convenience)
%endmacro

; DYN_FREE bytes_reg
; - bytes_reg: aligned byte count to free
%macro DYN_FREE 1
    add rsp, %1
%endmacro

; ----------------------------
; Call wrapper (optional)
; ----------------------------
; CALL_ALIGNED target
; If you use FUNC_PROLOGUE with 16B-aligned locals_bytes,
; you're already aligned at call sites. This is here mostly as a guardrail
; if you ever do odd stack adjustments.
%macro CALL_ALIGNED 1
    call %1
%endmacro

%endif ; FUNCS_ASM_INCLUDED
