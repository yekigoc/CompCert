(** Type preservation for the [Stacking] pass. *)

Require Import Coqlib.
Require Import Maps.
Require Import Integers.
Require Import AST.
Require Import Op.
Require Import Locations.
Require Import Conventions.
Require Import Linear.
Require Import Lineartyping.
Require Import Mach.
Require Import Machtyping.
Require Import Stacking.
Require Import Stackingproof.

(** We show that the Mach code generated by the [Stacking] pass
  is well-typed if the original Linear code is. *)

Definition wt_instrs (k: Mach.code) : Prop :=
  forall i, In i k -> wt_instr i.

Lemma wt_instrs_cons:
  forall i k,
  wt_instr i -> wt_instrs k -> wt_instrs (i :: k).
Proof.
  unfold wt_instrs; intros. elim H1; intro.
  subst i0; auto. auto.
Qed.

Section TRANSL_FUNCTION.

Variable f: Linear.function.
Let fe := make_env (function_bounds f).
Variable tf: Mach.function.
Hypothesis TRANSF_F: transf_function f = Some tf.

Lemma wt_Msetstack':
  forall idx ty r,
  mreg_type r = ty -> index_valid f idx ->
  wt_instr (Msetstack r (Int.repr (offset_of_index fe idx)) ty).
Proof.
  intros. constructor. auto. 
  unfold fe. rewrite (offset_of_index_no_overflow f tf TRANSF_F); auto.
  generalize (offset_of_index_valid f idx H0). tauto.
Qed.  

Lemma wt_fold_right:
  forall (A: Set) (f: A -> code -> code) (k: code) (l: list A),
  (forall x k', In x l -> wt_instrs k' -> wt_instrs (f x k')) ->
  wt_instrs k ->
  wt_instrs (List.fold_right f k l).
Proof.
  induction l; intros; simpl.
  auto.
  apply H. apply in_eq. apply IHl. 
  intros. apply H. auto with coqlib. auto. 
  auto. 
Qed.

Lemma wt_save_int_callee_save:
  forall cs k,
  In cs int_callee_save_regs -> wt_instrs k ->
  wt_instrs (save_int_callee_save fe cs k).
Proof.
  intros. unfold save_int_callee_save.
  case (zlt (index_int_callee_save cs) (fe_num_int_callee_save fe)); intro.
  apply wt_instrs_cons; auto.
  apply wt_Msetstack'. apply int_callee_save_type; auto.
  apply index_saved_int_valid. auto. exact z.
  auto.
Qed.

Lemma wt_save_float_callee_save:
  forall cs k,
  In cs float_callee_save_regs -> wt_instrs k ->
  wt_instrs (save_float_callee_save fe cs k).
Proof.
  intros. unfold save_float_callee_save.
  case (zlt (index_float_callee_save cs) (fe_num_float_callee_save fe)); intro.
  apply wt_instrs_cons; auto.
  apply wt_Msetstack'. apply float_callee_save_type; auto.
  apply index_saved_float_valid. auto. exact z.
  auto.
Qed.

Lemma wt_restore_int_callee_save:
  forall cs k,
  In cs int_callee_save_regs -> wt_instrs k ->
  wt_instrs (restore_int_callee_save fe cs k).
Proof.
  intros. unfold restore_int_callee_save.
  case (zlt (index_int_callee_save cs) (fe_num_int_callee_save fe)); intro.
  apply wt_instrs_cons; auto.
  constructor. apply int_callee_save_type; auto.
  auto.
Qed.

Lemma wt_restore_float_callee_save:
  forall cs k,
  In cs float_callee_save_regs -> wt_instrs k ->
  wt_instrs (restore_float_callee_save fe cs k).
Proof.
  intros. unfold restore_float_callee_save.
  case (zlt (index_float_callee_save cs) (fe_num_float_callee_save fe)); intro.
  apply wt_instrs_cons; auto.
  constructor. apply float_callee_save_type; auto.
  auto.
Qed.

Lemma wt_save_callee_save:
  forall k,
  wt_instrs k -> wt_instrs (save_callee_save fe k).
Proof.
  intros. unfold save_callee_save.
  apply wt_fold_right. exact wt_save_int_callee_save.
  apply wt_fold_right. exact wt_save_float_callee_save.
  auto.
Qed.

Lemma wt_restore_callee_save:
  forall k,
  wt_instrs k -> wt_instrs (restore_callee_save fe k).
Proof.
  intros. unfold restore_callee_save.
  apply wt_fold_right. exact wt_restore_int_callee_save.
  apply wt_fold_right. exact wt_restore_float_callee_save.
  auto.
Qed.

Lemma wt_transl_instr:
  forall instr k,
  Lineartyping.wt_instr f instr ->
  wt_instrs k ->
  wt_instrs (transl_instr fe instr k).
Proof.
  intros. destruct instr; unfold transl_instr; inversion H.
  (* getstack *)
  destruct s; simpl in H3; apply wt_instrs_cons; auto;
  constructor; auto.
  (* setstack *)
  destruct s; simpl in H3; simpl in H4.
  apply wt_instrs_cons; auto. apply wt_Msetstack'. auto. 
  apply index_local_valid. auto. 
  auto.
  apply wt_instrs_cons; auto. apply wt_Msetstack'. auto. 
  apply index_arg_valid. auto. 
  (* op, move *)
  simpl. apply wt_instrs_cons. constructor; auto. auto.
  (* op, undef *)
  simpl. apply wt_instrs_cons. constructor. auto.
  (* op, others *)
  apply wt_instrs_cons; auto.
  constructor. 
  destruct o; simpl; congruence.
  destruct o; simpl; congruence.
  rewrite H6. destruct o; reflexivity || congruence.
  (* load *)
  apply wt_instrs_cons; auto.
  constructor; auto.
  rewrite H4. destruct a; reflexivity.
  (* store *)
  apply wt_instrs_cons; auto.
  constructor; auto.
  rewrite H3. destruct a; reflexivity.
  (* call *)
  apply wt_instrs_cons; auto.
  constructor; auto.
  (* label *)
  apply wt_instrs_cons; auto.
  constructor.
  (* goto *)
  apply wt_instrs_cons; auto.
  constructor; auto.
  (* cond *)
  apply wt_instrs_cons; auto.
  constructor; auto.
  (* return *)
  apply wt_restore_callee_save. apply wt_instrs_cons. constructor. auto.
Qed.

End TRANSL_FUNCTION.

Lemma wt_transf_function:
  forall f tf, 
  transf_function f = Some tf ->
  Lineartyping.wt_function f ->
  wt_function tf.
Proof.
  intros. 
  generalize H; unfold transf_function.
  case (zlt (Linear.fn_stacksize f) 0); intro.
  intros; discriminate.
  case (zlt (- Int.min_signed) (fe_size (make_env (function_bounds f)))); intro.
  intros; discriminate. intro EQ.
  generalize (unfold_transf_function f tf H); intro.
  assert (fn_framesize tf = fe_size (make_env (function_bounds f))).
    subst tf; reflexivity.
  constructor.
  change (wt_instrs (fn_code tf)).
  rewrite H1; simpl; unfold transl_body. 
  apply wt_save_callee_save with tf; auto. 
  unfold transl_code. apply wt_fold_right. 
  intros. eapply wt_transl_instr; eauto. 
  red; intros. elim H3.
  subst tf; simpl; auto.
  rewrite H2. eapply size_pos; eauto.
  rewrite H2. eapply size_no_overflow; eauto.
Qed.

Lemma program_typing_preserved:
  forall (p: Linear.program) (tp: Mach.program),
  transf_program p = Some tp ->
  Lineartyping.wt_program p ->
  Machtyping.wt_program tp.
Proof.
  intros; red; intros.
  generalize (transform_partial_program_function transf_function p i f H H1).
  intros [f0 [IN TRANSF]].
  apply wt_transf_function with f0; auto.
  eapply H0; eauto.
Qed.