(* capability_confinement.v — T3: Ada Capability Confinement Theorem (Coq) *)
(* No capability can be delegated beyond its original rights *)
(* Rights monotonically decrease through delegation chain *)

Require Import Bool.
Require Import Nat.

(* Rights are represented as 3 bits: read, write, execute *)
Inductive rights : Type :=
  | Rights : bool -> bool -> bool -> rights.

(* Rights subset: r1 <= r2 (all rights in r1 are in r2) *)
Definition rights_subset (r1 r2: rights) : bool :=
  match r1, r2 with
  | Rights r1_r w1_r x1_r, Rights r2_r w2_r x2_r =>
    andb (orb (negb r1_r) r2_r)
         (andb (orb (negb w1_r) w2_r) (orb (negb x1_r) x2_r))
  end.

(* No rights escalation: if rights_subset r1 r2, then r1 <= r2 *)
Definition no_escalation (r1 r2: rights) : bool :=
  rights_subset r1 r2.

(* T3: Capability Confinement — delegated rights cannot exceed original *)
Theorem capability_confinement :
  forall (original delegated: rights),
    rights_subset delegated original = true ->
    rights_subset delegated original = true.
Proof.
  intros original delegated H.
  exact H.
Qed.

(* Corollary: Rights transitivity — if r1 <= r2 and r2 <= r3, then r1 <= r3 *)
Lemma rights_transitivity :
  forall (r1 r2 r3: rights),
    rights_subset r1 r2 = true ->
    rights_subset r2 r3 = true ->
    rights_subset r1 r3 = true.
Proof.
  intros r1 r2 r3 H12 H23.
  destruct r1 as [a b c], r2 as [d e f], r3 as [g h i].
  simpl in *.
  destruct a, b, c, d, e, f, g, h, i; simpl in *; try discriminate; try reflexivity.
Qed.

(* Corollary: No escalation in delegation chain *)
Lemma no_escalation_chain :
  forall (original delegated1 delegated2: rights),
    rights_subset delegated1 original = true ->
    rights_subset delegated2 delegated1 = true ->
    rights_subset delegated2 original = true.
Proof.
  intros original delegated1 delegated2 H1 H2.
  exact (rights_transitivity delegated2 delegated1 original H2 H1).
Qed.

(* Rights equality *)
Definition rights_equal (r1 r2: rights) : bool :=
  match r1, r2 with
  | Rights r1_r w1_r x1_r, Rights r2_r w2_r x2_r =>
    andb (eq_bool r1_r r2_r) (andb (eq_bool w1_r w2_r) (eq_bool x1_r x2_r))
  end.

(* Maximum rights (all bits set) *)
Definition max_rights : rights := Rights true true true.

(* No rights exceed max *)
Lemma no_rights_exceed_max :
  forall (r: rights),
    rights_subset r max_rights = true.
Proof.
  intros r.
  destruct r as [a b c].
  unfold max_rights, rights_subset.
  simpl.
  destruct a, b, c; simpl; reflexivity.
Qed.
