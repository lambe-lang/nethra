module Impl (Theory : Specs.Theory) (Checker : Specs.Checker) = struct
  include Judgment
  open Stdlib.Fun
  open Preface.Option.Applicative
  open Preface.Option.Monad
  open Preface.Option.Foldable
  open Nethra_lang_ast.Term.Construct
  open Nethra_lang_ast.Term.Destruct
  open Nethra_lang_ast.Proof
  open Nethra_lang_ast.Proof.Construct
  open Nethra_lang_ast.Hypothesis.Access
  open Nethra_lang_basic.Substitution
  open Reduction
  open Equivalence.Impl (Theory)
  open Checker

  let get_type p =
    let open Nethra_lang_ast.Proof.Destruct in
    get_type p

  let proof_from_option ?(proofs = []) ?(reason = None) o =
    fold_right const o (None, proofs @ [ failure reason ])

  (*
    Γ ⊢
    -----------------------
    Γ ⊢ Type_i : Type_{i+1}
  *)
  let infer_kind _hypothesis (level, c) =
    let term = kind ~c @@ (level + 1) in
    (return term, [])

  (*
    l ∈ int
    -----------
    Γ ⊢ l : int
  *)
  let infer_int _hypothesis (_, c) =
    let term = id ~c "int" in
    (return term, [])

  (*
    l ∈ char
    ------------
    Γ ⊢ l : char
  *)
  let infer_char _hypothesis (_, c) =
    let term = id ~c "char" in
    (return term, [])

  (*
    l ∈ string
    --------------
    Γ ⊢ l : string
  *)
  let infer_string _hypothesis (_, c) =
    let term = id ~c "string" in
    (return term, [])

  (*
    Γ ⊢
    ----------------
    Γ, x : T ⊢ x : T
  *)
  let infer_id hypothesis (name, _, _) =
    proof_from_option
      ~reason:(return ("Unbound variable " ^ name))
      (get_signature hypothesis name <&> fun term -> (return term, []))

  (*
    Γ ⊢ M : S   Γ, x : M ⊢ N : T
    ----------------------------
    Γ ⊢ Π(x:M).N : T
  *)
  let rec infer_pi hypothesis (name, bound, body, _implicit, _c) =
    let proof = hypothesis |- bound => () in
    let bound' = get_type proof in
    let proof' = hypothesis +: (name, bound) |- body => () in
    let body' = get_type proof' in
    (bound' >>= const body', [ proof; proof' ])

  (*
    Γ, x : A ⊢ B : T          Γ, x : A ⊢ B : T
    ---------------------     ---------------------
    Γ ⊢ λ(x).B : Π(x:A).T     Γ ⊢ λ{x}.B : Π{x:A}.T
  *)
  and infer_lambda hypothesis (name, body, implicit, c) =
    let reference = ref None in
    let bound' = hole ~r:reference name in
    let hypothesis = hypothesis +: (name, bound') in
    let proof = hypothesis |- body => () in
    let body' = get_type proof in
    proof_from_option
      ~reason:(return "Cannot infer lambda")
      ~proofs:[ proof ]
      ( body'
      <&> fun body' ->
      fold_right const
        ( !reference
        <&> fun value -> (Some (pi ~implicit ~c name value body'), [ proof ]) )
        ( Some
            (* Unbound means Generalisable? *)
            (pi ~implicit:true name (kind 0)
               (pi ~implicit ~c name bound' body') )
        , [ proof ] ) )

  (*
    Γ ⊢ f : Π(x:M).N   Γ ⊢ e : M      Γ ⊢ f : Π{x:M}.N   Γ ⊢ e : M
    ----------------------------      ----------------------------
    Γ ⊢ f e : N[x:=e]                 Γ ⊢ f {e} : N[x:=e]
  *)
  and infer_apply hypothesis (abstraction, argument, implicit, _c) =
    let proof = hypothesis |- abstraction => () in
    let pi = get_type proof in
    proof_from_option
      ~reason:(return "Waiting for a Pi term")
      ~proofs:[ proof ]
      ( pi
      >>= fold_opt ~pi:return
      <&> fun (n, bound, body, implicit', _c') ->
      if implicit = implicit'
      then
        ( return (substitute n argument body)
        , [ hypothesis |- argument <= bound ] )
      else (None, [ proof; failure None ]) )

  (*
    Γ ⊢ e:M   Γ, x:M, x=e ⊢ f : N
    -----------------------------
    Γ ⊢ let x = e in f : N[x:=e]
  *)
  and infer_let_binding hypothesis (name, arg, body, _c) =
    let proof = hypothesis |- arg => () in
    let targ = get_type proof in
    proof_from_option ~proofs:[ proof ]
      ( targ
      <&> fun targ ->
      let proof' = hypothesis +: (name, targ) += (name, arg) |- body => () in
      let tbody = get_type proof' in
      ((tbody <&> fun tbody -> substitute name arg tbody), [ proof; proof' ]) )

  (*
    Γ ⊢ M : S   Γ, x : M ⊢ N : T
    ----------------------------
    Γ ⊢ Σ(x:M).N : T
  *)
  and infer_sigma hypothesis (name, bound, body, _c) =
    let proof = hypothesis |- bound => () in
    let bound' = get_type proof in
    let proof' = hypothesis +: (name, bound) |- body => () in
    let body' = get_type proof' in
    (bound' >>= const body', [ proof; proof' ])

  (*
    Γ ⊢ A : M   Γ ⊢ B : N
    ---------------------
    Γ ⊢ A,B : Σ(_:M).N
  *)
  and infer_pair hypothesis (lhd, rhd, _c) =
    let proof = hypothesis |- lhd => () in
    let left = get_type proof in
    let proof' = hypothesis |- rhd => () in
    let right = get_type proof' in
    ( (left >>= fun left -> right <&> fun right -> sigma "_" left right)
    , [ proof; proof' ] )

  (*
    Γ ⊢ p : Σ(x:M).N
    ----------------
    Γ ⊢ fst p : M
  *)
  and infer_fst hypothesis (term, _c) =
    let proof = hypothesis |- term => () in
    let sigma = get_type proof in
    proof_from_option
      ~reason:(return "Waiting for a Sigma term")
      ~proofs:[ proof ]
      ( sigma
      >>= fold_opt ~sigma:return
      <&> fun (_, bound, _, _) -> (return bound, [ proof ]) )

  (*
    Γ ⊢ p : Σ(x:M).N
    -----------------------
    Γ ⊢ snd p : N[x:=fst p]
  *)
  and infer_snd hypothesis (term, _c) =
    let proof = hypothesis |- term => () in
    let sigma = get_type proof in
    proof_from_option
      ~reason:(return "Waiting for a Sigma term")
      ~proofs:[ proof ]
      ( sigma
      >>= fold_opt ~sigma:return
      <&> fun (n, _, body, _) ->
      (return (substitute n (fst term) body), [ proof ]) )

  (*
    Γ ⊢ A : T   Γ ⊢ B : T
    ---------------------
    Γ ⊢ A + B : T
  *)
  and infer_sum hypothesis (lhd, rhd, _c) =
    let proof = hypothesis |- lhd => () in
    let term = get_type proof in
    proof_from_option ~reason:(return "infer_sum") ~proofs:[ proof ]
      (term <&> fun term -> (return term, [ hypothesis |- rhd <= term ]))

  (*
    Γ ⊢ A : M
    -----------------
    Γ ⊢ inl A : M + N
  *)
  and infer_inl hypothesis (term, c) =
    let proof = hypothesis |- term => () in
    let term = get_type proof in
    proof_from_option ~reason:(return "infer_inl") ~proofs:[ proof ]
      ( term
      <&> fun term ->
      let var, _hypothesis = fresh_variable hypothesis "_" in
      (return (sum term (hole ~c var)), [ proof ]) )

  (*
    Γ ⊢ A : N
    -----------------
    Γ ⊢ inr A : M + N
  *)
  and infer_inr hypothesis (term, c) =
    let proof = hypothesis |- term => () in
    let term = get_type proof in
    proof_from_option ~reason:(return "infer_inr") ~proofs:[ proof ]
      ( term
      <&> fun term ->
      let var, _hypothesis = fresh_variable hypothesis "_" in
      (return (sum (hole ~c var) term), [ proof ]) )

  (*
    Γ ⊢ a : A + B   Γ ⊢ l : Π(_:A).C   Γ ⊢ r : Π(_:B).T
    ---------------------------------------------------
    Γ ⊢ case a l r : C
  *)
  and infer_case hypothesis (term, left, right, _c) =
    let proof = hypothesis |- term => () in
    let term = get_type proof in
    proof_from_option
      ~reason:(return "Waiting for a Sum term")
      ~proofs:[ proof ]
      ( term
      >>= fold_opt ~sum:return
      <&> fun (lhd, rhd, c) ->
      let var, hypothesis = fresh_variable hypothesis "_" in
      let hole = hole ~c var in
      ( return hole
      , [
          proof
        ; hypothesis |- left <= arrow lhd hole
        ; hypothesis |- right <= arrow rhd hole
        ] ) )

  (*
    Γ,x : T ⊢ A : T
    ----------------
    Γ ⊢ μ(x:T).A : T
  *)
  and infer_mu hypothesis (name, kind, body, _c) =
    let hypothesis = hypothesis +: (name, kind) in
    (Some kind, [ hypothesis |- body <= kind ])

  (*
    Γ ⊢ A : N[x:=μ(x:T).N]
    ----------------------
    Γ ⊢ fold A : μ(x:T).N
  *)
  and infer_fold _hypothesis (_term, _c) =
    (None, [ failure @@ return "Cannot infer fold" ])

  (*
    Γ ⊢ A : μ(x:T).N
    ----------------------------
    Γ ⊢ unfold A : N[x=μ(x:T).N]
  *)
  and infer_unfold hypothesis (term, _c) =
    let proof = hypothesis |- term => () in
    let term = get_type proof in
    proof_from_option
      ~reason:(return "Waiting for a Mu term")
      ~proofs:[ proof ]
      ( term
      >>= fold_opt ~mu:return
      <&> fun (n, kind, body, c) ->
      (return (substitute n (mu ~c n kind body) body), [ proof ]) )

  (*
    Γ ⊢                   Γ, x : T ⊢ U : T
    -----------------     -------------------
    Γ, x : T ⊢ ?x : T     Γ, x : T ⊢ ?x=U : T
  *)
  and infer_hole hypothesis (name, _value, _c) =
    proof_from_option
      ~reason:(return ("Unbound variable" ^ name))
      (get_signature hypothesis name <&> fun t -> (return t, []))

  (*
    Γ ⊢ n : M    Γ ⊢ M : Type_0
    ---------------------------
    Γ ⊢ (n:M) : M
   *)

  and infer_annotation hypothesis (term, term'', c) =
    ( Some term''
    , [ hypothesis |- term <= term''; hypothesis |- term'' <= kind ~c 0 ] )

  (*
    Γ ⊢ n : A    Γ ⊢ m : A
    ----------------------
    Γ ⊢ n = m : Type_0
  *)

  and infer_equals hypothesis (lhd, rhd, c) =
    let proof = hypothesis |- lhd => () in
    let lhd = get_type proof in
    proof_from_option ~reason:(return "infer_equals") ~proofs:[ proof ]
      ( lhd
      <&> fun lhd -> (Some (kind ~c 0), [ proof; hypothesis |- rhd <= lhd ]) )

  (*
    Γ ⊢
    ----------------
    Γ ⊢ refl : m = m
  *)

  and infer_refl hypothesis c =
    let var, _ = fresh_variable hypothesis "refl" in
    let term = hole ~c var in
    (Some (equals term term), [])

  (*
      Γ ⊢ b : x = B    Γ ⊢ a : A[x:=B]    Γ ⊢ b : B = x    Γ ⊢ a : A[x:=B]
      --------------------------------    --------------------------------
      Γ ⊢ subst a by b : A                Γ ⊢ subst a by b : A
  *)

  and infer_subst hypothesis (a, b, _c) =
    let proof = hypothesis |- b => () in
    let tB = get_type proof in
    proof_from_option
      ~reason:(return "Waiting for an equality")
      ~proofs:[ proof ]
      ( tB
      >>= fold_opt ~equals:return
      <&> fun (eql, eqr, _c) ->
      let proof' = hypothesis |- a => () in
      let tA = get_type proof' in
      proof_from_option ~proofs:[ proof; proof' ]
        ( tA
        <&> (fun tA ->
              let tA' = try_substitute eql eqr tA in
              if tA = tA'
              then
                let tA' = try_substitute eqr eql tA in
                if tA = tA' then tA else tA'
              else tA' )
        <&> fun tA -> (Some tA, [ proof; proof' ]) ) )

  (*
    Γ ⊢
    ----------------
    Γ ⊢ < > : type_i

    Γ ⊢ T : type_i    Γ, n : T ⊢ r : type_i
    ----------------------------------------
    Γ ⊢ < n : T, r > : type_i
  *)

  and infer_record_sig hypothesis (l, c) =
    let t = kind ~c 0 in
    let r, p, _ =
      List.fold_left
        (fun (r, p, h) (n, e) ->
          let proof = h |- e <= t in
          let t' = get_type proof in
          (return (fun _ r -> r) <*> t' <*> r, proof :: p, h += (n, e)) )
        (Some t, [], hypothesis) l
    in
    (r, List.rev p)

  (*
    Γ ⊢
    -------------
    Γ ⊢ { } : < >

    Γ ⊢ e : T    Γ, n : T ⊢ r : R[n:=e]
    -----------------------------------
    Γ ⊢ { n = e, r } : < n : T, R >
  *)

  and infer_record_val hypothesis (l, c) =
    let r, p, _ =
      List.fold_left
        (fun (r, p, h) (n, e) ->
          let proof = h |- e => () in
          let t = get_type proof in
          (return (fun t l -> (n, t) :: l) <*> t <*> r, proof :: p, h += (n, e))
          )
        (Some [], [], hypothesis) l
    in
    ((r <&> fun r -> record_val ~c r), p)

  (*
    Γ ⊢ e : < n : T, R >
    --------------------
    Γ ⊢ e.n : T

    Γ ⊢ e : < m : T, R >    Γ, m : T ⊢ e.n : R    m ≠ n
    ---------------------------------------------------
    Γ ⊢ e.n : T[m:=e.m]
  *)

  and infer_access hypothesis (e, n, c) =
    let rec infer hypothesis l =
      match l with
      | [] -> (None, [ failure (Some ("no definition for " ^ n)) ])
      | (n', t') :: _ when n = n' -> (Some t', [])
      | (n', t') :: l ->
        let t, ps = infer (hypothesis +: (n', t')) l in
        (t <&> substitute n' (access ~c e n'), ps)
    in
    let proof = hypothesis |- e => () in
    let tR = get_type proof in
    proof_from_option
      ~reason:(return "Waiting for a record signature")
      ~proofs:[ proof ]
      ( tR
      >>= fold_opt ~record_sig:return ~record_val:return
      <&> fun (l, _) ->
      let t, ps = infer hypothesis l in
      (t, proof :: ps) )

  (*
    Additional inference rule dedicated to implicit parameters
  *)

  and implicit_parameter hypothesis term =
    proof_from_option
      ~reason:(return "implicit_parameter")
      ( fold_opt ~apply:return term
      <&> fun (abstraction, argument, implicit_apply, _) ->
      if implicit_apply
      then (None, [ failure None ])
      else
        let proof = hypothesis |- abstraction => () in
        let term'' = get_type proof in
        proof_from_option
          ~reason:(return "Waiting for a Pi term")
          ~proofs:[ proof ]
          ( term''
          >>= fold_opt ~pi:return
          <&> fun (n, bound, _, implicit_pi, _) ->
          if implicit_pi
          then
            let var, hypothesis = fresh_variable hypothesis n in
            let term =
              apply (apply ~implicit:true abstraction (hole var)) argument
            in
            let proof' = hypothesis +: (var, bound) |- term => () in
            let term' = get_type proof' in
            (term', [ proof; proof' ])
          else (None, [ proof; failure None ]) ) )

  and nominal hypothesis term =
    let term', proofs =
      fold ~kind:(infer_kind hypothesis) ~int:(infer_int hypothesis)
        ~char:(infer_char hypothesis) ~string:(infer_string hypothesis)
        ~id:(infer_id hypothesis) ~pi:(infer_pi hypothesis)
        ~lambda:(infer_lambda hypothesis) ~apply:(infer_apply hypothesis)
        ~let_binding:(infer_let_binding hypothesis)
        ~sigma:(infer_sigma hypothesis) ~pair:(infer_pair hypothesis)
        ~fst:(infer_fst hypothesis) ~snd:(infer_snd hypothesis)
        ~sum:(infer_sum hypothesis) ~inl:(infer_inl hypothesis)
        ~inr:(infer_inr hypothesis) ~case:(infer_case hypothesis)
        ~mu:(infer_mu hypothesis) ~fold:(infer_fold hypothesis)
        ~unfold:(infer_unfold hypothesis) ~hole:(infer_hole hypothesis)
        ~annotation:(infer_annotation hypothesis)
        ~equals:(infer_equals hypothesis) ~refl:(infer_refl hypothesis)
        ~subst:(infer_subst hypothesis)
        ~record_sig:(infer_record_sig hypothesis)
        ~record_val:(infer_record_val hypothesis)
        ~access:(infer_access hypothesis) term
    in
    let term' = term' <&> reduce hypothesis in
    (term', infer hypothesis term term' proofs)

  and infer_type hypothesis term =
    match nominal hypothesis term with
    | None, proof -> (
      match implicit_parameter hypothesis term with
      | None, proofs' ->
        let proof' = infer hypothesis term None proofs' in
        if size proof' > size proof then proof' else proof
      | term', proofs' -> infer hypothesis term term' proofs' )
    | _, r -> r

  and ( => ) (hypothesis, term) () = infer_type hypothesis term
end
