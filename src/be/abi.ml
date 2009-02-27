
(* 
 * The 'abi' structure is pretty much just a grab-bag of machine
 * dependencies.  Make some attempt to factor it as time goes by.  
 *)

(* 

 * It's also a place to make some notes and ascii-art about the actual
 * ABI. Because it needs a bunch of quite specific, yet somewhat
 * arbitrary choices made.

 * A frame needs a return PC and a yield PC. These have to be separate
 * because we can tail-yield, and want to skip intermediate live
 * non-tail-call frames.

 * How do you get two PCs when there's only a call instruction? There
 * are three cases: 

 * Case #1 is a "base call" in which we pass our PC using the call
 * insn and the static distance between the return-point and the
 * yield-point. Since we the caller have both these PCs in ourself, we
 * can statically work out the distance.

 * Case #2 is a "tail yield call": we are the return point, but our
 * caller (or one of its callers) is the yield point. Here we pass our
 * return PC and our caller's yield PC directly. We can't work out the
 * difference between the two because one is only knowable at
 * file-offset, compile-time terms, and one is dynamic.

 * Case #3 is a "full tail call": we are destroying our own frame
 * entirely and passing both our caller's return PC and yield PC to
 * the callee. Our PC is irrelevant so we just adjust the frame around
 * the existing (reused) two PCs and jump to our target.

 * The 2nd and 3rd case can, I think, be folded into a single case
 * with different frame adjustments. But we need to convey 1 bit of
 * information to differentiate 1st from 2nd. Easiest way is to use
 * the low bit of the yield address and make sure all yield addresses
 * are 2-byte aligned. This in turn requires that the assembler grow
 * the ability to insert nops, via a CODEALIGN alignment type. No
 * problem. If we actually need to differentiate case 3, possibly use
 * the two low bits, or possibly make multiple entry points in a fn.

 * 
 * 
 * 
 * frame layout:
 * 
 * [0] return PC
 * [1*ptr] link to process                     <-- frame pointer (x86:ebp) 
 * [2*ptr] link to type descriptor
 * [4*ptr] outgoing slot = N bytes             <-- start of 'args'
 * [N+4*ptr] arg tuple = K bytes
 * [3*ptr] yield PC (possibly delta from retpc)
 * [4*ptr] link to closure
 * [N+K+4*ptr] spill0
 * ...         ...
 * ...         spillN
 * 
 * 
 * process layout:
 * 
 *  [0] link to runtime system
 *  [1*ptr] link to crate
 *  [2*ptr] link to parent closure
 *
 *)


type proc_state =
    STATE_running
  | STATE_calling_c
  | STATE_exiting
;;

let proc_state_to_code (st:proc_state) : int64 =
  match st with
      STATE_running -> 0L
    | STATE_calling_c -> 1L
    | STATE_exiting -> 2L
;;

(* Word offsets for structure fields in rust.h. *)
let regs_field_pc = 0;;
let regs_field_sp = 1;;

let proc_field_rt = 0;;
let proc_field_stk = 1;;
let proc_field_prog = 2;;
let proc_field_regs = 3;;
let proc_field_regs_pc = proc_field_regs + regs_field_pc;;
let proc_field_regs_sp = proc_field_regs + regs_field_sp;;
let proc_field_state = 5;;
let proc_field_refcnt = 6;;

let rt_field_c_regs = 0;;
let rt_field_c_regs_pc = rt_field_c_regs + regs_field_pc;;
let rt_field_c_regs_sp = rt_field_c_regs + regs_field_sp;;
let rt_field_curr_proc = 2;;
let rt_field_live_procs = 3;;
let rt_field_procs = 4;;

type abi =
  {
    abi_ptr_sz: int64;
    abi_ptr_ty: Common.ty_mach;

    abi_is_2addr_machine: bool;
    abi_has_pcrel_loads: bool;
    abi_has_pcrel_jumps: bool;
    abi_has_imm_loads: bool;
    abi_has_imm_jumps: bool;

    abi_n_hardregs: int;
    abi_str_of_hardreg: (int -> string);

    abi_prealloc_quad: (Il.quad -> Il.quad);
    abi_emit_fn_prologue: (Il.emitter -> Common.fixup -> int64 -> Common.fixup -> unit);
    abi_emit_fn_epilogue: (Il.emitter -> unit);
    abi_emit_main_prologue: (Il.emitter -> Ast.block -> int64 -> Common.fixup -> unit);
    abi_emit_main_epilogue: (Il.emitter -> Ast.block -> unit);

    abi_clobbers: (Il.quad -> Il.hreg list);

    abi_emit_proc_state_change: (Il.emitter -> proc_state -> unit);

    (* Transitions between runtimes. *)
    abi_c_to_proc: (Il.emitter -> Common.fixup -> unit);
    abi_proc_to_c: (Il.emitter -> Common.fixup -> unit);

    abi_sp_reg: Il.reg;
    abi_fp_reg: Il.reg;
    abi_pp_operand: Il.operand;
    abi_implicit_args_sz: int64;
    abi_frame_base_sz: int64;
    abi_spill_slot: (int64 -> int -> Il.operand);
  }


(* 
 * Local Variables:
 * fill-column: 70; 
 * indent-tabs-mode: nil
 * compile-command: "make -k -C .. 2>&1 | sed -e 's/\\/x\\//x:\\//g'"; 
 * End:
 *)
