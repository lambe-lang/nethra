module Impl (Theory : Specs.Theory) (Infer : Specs.Infer) = struct
  include Judgment
  open Stdlib.Fun
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
  open Infer

  let get_type p =
    let open Nethra_lang_ast.Proof.Destruct in
    get_type p

  let proof_from_option ?(proofs = []) ?(reason = None) o =
    fold_right const o (proofs @ [ failure reason ])

  (*
    Γ ⊢
    -----------------------
    Γ ⊢ Type_i : Type_{i+1}
  *)
  let check_kind hypothesis term' (level, c) =
    let proof = hypothesis |- kind ~c level => () in
    let term = get_type proof in
    proof_from_option
      (term <&> fun term -> [ proof; hypothesis |- term =?= term' ])

  (*
    l ∈ int
    -----------
    Γ ⊢ l : int
  *)
  let check_int hypothesis term' (value, c) =
    let proof = hypothesis |- int ~c value => () in
    let term = get_type proof in
    proof_from_option
      (term <&> fun term -> [ proof; hypothesis |- term =?= term' ])

  (*
    l ∈ char
    ------------
    Γ ⊢ l : char
  *)
  let check_char hypothesis term' (value, c) =
    let proof = hypothesis |- char ~c value => () in
    let term = get_type proof in
    proof_from_option ~reason:(return "check_var")
      (term <&> fun term -> [ proof; hypothesis |- term =?= term' ])

  (*
    l ∈ string
    --------------
    Γ ⊢ l : string
  *)
  let check_string hypothesis term' (value, c) =
    let proof = hypothesis |- string ~c value => () in
    let term = get_type proof in
    proof_from_option ~reason:(return "check_string")
      (term <&> fun term -> [ proof; hypothesis |- term =?= term' ])

  (*
    Γ ⊢
    ----------------
    Γ, x : T ⊢ x : T
  *)
  let check_id hypothesis term' (name, initial, c) =
    let proof = hypothesis |- id ~c ~initial name => () in
    let term = get_type proof in
    proof_from_option ~reason:(return "check_id")
      (term <&> fun term -> [ proof; hypothesis |- term =?= term' ])

  (*
    Γ ⊢ M : S   Γ, x : M ⊢ N : T    Γ ⊢ M : S   Γ, x : M ⊢ N : T
    ----------------------------    ----------------------------
    Γ ⊢ Π(x:M).N : T                Γ ⊢ Π{x:M}.N : T
  *)
  let rec check_pi hypothesis term' (name, bound, body, _implicit, c) =
    [
      hypothesis |- bound <= kind ~c 0
    ; hypothesis +: (name, bound) |- body <= term'
    ]

  (*
    Γ, x : A ⊢ B : T          Γ, x : A ⊢ B : T
    ---------------------     ---------------------
    Γ ⊢ λ(x).B : Π(x:A).T     Γ ⊢ λ{x}.B : Π{x:A}.T
  *)
  and check_lambda hypothesis term' (name, body, implicit, _c) =
    proof_from_option
      ~reason:(return "Waiting for a Pi term")
      ( fold_opt ~pi:return term'
      <&> fun (name', bound', body', implicit', _c') ->
      if implicit = implicit'
      then
        let var, hypothesis = fresh_variable hypothesis name in
        let body' = substitute name' (id ~initial:(return name') var) body'
        and body = substitute name (id ~initial:(return name) var) body in
        [ hypothesis +: (var, bound') |- body <= body' ]
      else [ failure (Some "mixed implicit/explicit") ] )

  (*
    Γ ⊢ f : Π(x:M).N   Γ ⊢ e : M      Γ ⊢ f : Π{x:M}.N   Γ ⊢ e : M
    ----------------------------      ----------------------------
    Γ ⊢ f e : N[x:=e]                  Γ ⊢ f {e} : N[x:=e]
  *)
  and check_apply hypothesis term' (abstraction, argument, implicit, _c) =
    let proof = hypothesis |- abstraction => () in
    let term = get_type proof in
    proof_from_option ~proofs:[ proof ]
      ~reason:(return "Waiting for a Pi term")
      ( term
      >>= fold_opt ~pi:return
      >>= fun (name, bound, body, implicit', _) ->
      if implicit = implicit'
      then
        return
          [
            proof
          ; hypothesis |- argument <= bound
          ; hypothesis |- substitute name argument body =?= term'
          ]
      else None )

  (*
    Γ ⊢ e:M   Γ, x:M, x=e ⊢ f : N
    -----------------------------
    Γ ⊢ let x = e in f : N[x:=e]
  *)
  and check_let_binding hypothesis term' (name, arg, body, _c) =
    let proof = hypothesis |- arg => () in
    let targ = get_type proof in
    proof_from_option ~proofs:[ proof ]
      ( targ
      <&> fun targ ->
      let proof' = hypothesis +: (name, targ) += (name, arg) |- body => () in
      let tbody = get_type proof' in
      proof_from_option ~proofs:[ proof; proof' ]
        ( tbody
        <&> fun tbody ->
        [ proof; proof'; hypothesis |- substitute name arg tbody =?= term' ] )
      )

  (*
    Γ ⊢ M : S   Γ, x : M ⊢ N : T
    ----------------------------
    Γ ⊢ Σ(x:M).N : T
  *)
  and check_sigma hypothesis term' (name, bound, body, c) =
    [
      hypothesis |- bound <= kind ~c 0 (* TODO *)
    ; hypothesis +: (name, bound) |- body <= term'
    ]

  (*
    Γ ⊢ A : M   Γ ⊢ B : N[x:=A]
    ---------------------------
    Γ ⊢ A,B : Σ(x:M).N
  *)
  and check_pair hypothesis term' (lhd, rhd, _c) =
    proof_from_option
      ~reason:(return "Waiting for a sigma")
      ( fold_opt ~sigma:return term'
      <&> fun (n', bound', body', _c') ->
      [
        hypothesis |- lhd <= bound'
      ; hypothesis |- rhd <= substitute n' lhd body'
      ] )

  (*
    Γ ⊢ p : Σ(x:M).N
    ----------------
    Γ ⊢ fst p : M
  *)
  and check_fst hypothesis term' (term, _c) =
    let proof = hypothesis |- term => () in
    let term'' = get_type proof in
    proof_from_option ~proofs:[ proof ]
      ~reason:(return "Waiting for a Sigma term")
      ( term''
      >>= fold_opt ~sigma:return
      <&> fun (_, bound, _, _) -> [ proof; hypothesis |- bound =?= term' ] )

  (*
    Γ ⊢ p : Σ(x:M).N
    -----------------------
    Γ ⊢ snd p : N[x:=fst p]
    *)
  and check_snd hypothesis term' (term, _c) =
    let proof = hypothesis |- term => () in
    let term'' = get_type proof in
    proof_from_option ~proofs:[ proof ]
      ~reason:(return "Waiting for a Sigma term")
      ( term''
      >>= fold_opt ~sigma:return
      <&> fun (n, _, body, _) ->
      [ proof; hypothesis |- substitute n (fst term) body =?= term' ] )

  (*
    Γ ⊢ A : T   Γ ⊢ B : T
    ---------------------
    Γ ⊢ A + B : T
  *)
  and check_sum hypothesis term' (lhd, rhd, _c) =
    [ hypothesis |- lhd <= term'; hypothesis |- rhd <= term' ]

  (*
    Γ ⊢ A : M
    -----------------
    Γ ⊢ inl A : M + N
  *)
  and check_inl hypothesis term' (term, _c) =
    proof_from_option
      ~reason:(return "Waiting for a Sum term")
      ( fold_opt ~sum:return term'
      <&> fun (lhd, _, _) -> [ hypothesis |- term <= lhd ] )

  (*
    Γ ⊢ A : N
    -----------------
    Γ ⊢ inr A : M + N
  *)
  and check_inr hypothesis term' (term, _c) =
    proof_from_option
      ~reason:(return "Waiting for a Sum term")
      ( fold_opt ~sum:return term'
      <&> fun (_, rhd, _) -> [ hypothesis |- term <= rhd ] )

  (*
    Γ ⊢ a : A + B   Γ ⊢ l : Π(x:A).C[a:=inl x]   Γ ⊢ r : Π(x:B).C[a:=inr x]   a in Id
    ---------------------------------------------------------------------------------
    Γ ⊢ case a l r : C

    Γ ⊢ a : A + B   Γ ⊢ l : Π(_:A).C   Γ ⊢ r : Π(_:B).C    a not in Id
    ------------------------------------------------------------------
    Γ ⊢ case a l r : C
  *)
  and check_case hypothesis term' (term, left, right, c) =
    let proof = hypothesis |- term => () in
    let term'' = get_type proof in
    let v, hypothesis = fresh_variable hypothesis "_" in
    proof_from_option ~proofs:[ proof ]
      ~reason:(return "Waiting for a Sum term")
      ( term''
      >>= fold_opt ~sum:return
      <&> fun (lhd, rhd, _) ->
      [
        proof
      ; hypothesis
        |- left
        <= pi v lhd (reduce hypothesis @@ try_substitute term (inl (id ~c v)) term')
      ; hypothesis
        |- right
        <= pi v rhd
             (reduce hypothesis @@ try_substitute term (inr (id ~c v)) term')
      ] )

  (*
    Γ,x : T ⊢ A : T
    ---------------
    Γ ⊢ μ(x).A : T
  *)
  and check_mu hypothesis term' (name, kind, body, _c) =
    [ hypothesis +: (name, kind) |- body <= term' ]

  (*
    Γ ⊢ A : N[x:=μ(x).N]
    --------------------
    Γ ⊢ fold A : μ(x).N
  *)
  and check_fold hypothesis term' (term, _c) =
    proof_from_option
      ~reason:(return "Waiting for a Mu term")
      ( fold_opt ~mu:return term'
      <&> fun (name', _kind, term'', _) ->
      [ hypothesis |- term <= substitute name' term' term'' ] )

  (*
    Γ ⊢ A : μ(x).N
    ---------------------------
    Γ ⊢ unfold A : N[x:=μ(x).N]
  *)
  and check_unfold hypothesis term' (term, _c) =
    let proof = hypothesis |- term => () in
    let term'' = get_type proof in
    proof_from_option ~proofs:[ proof ]
      ~reason:(return "Waiting for a Mu term")
      ( term''
      >>= fold_opt ~mu:return
      <&> fun (name', _kind, term'', _) ->
      [ proof; hypothesis |- term' =?= substitute name' term'' term'' ] )

  (*
    Γ ⊢                   Γ, x : T ⊢ U : T
    -----------------     -------------------
    Γ, x : T ⊢ ?x : T     Γ, x : T ⊢ ?x=U : T
  *)
  and check_hole hypothesis term' (name, reference, _c) =
    proof_from_option
      ~reason:(return ("Unbound variable " ^ name))
      ( get_signature hypothesis name
      <&> fun term ->
      [ hypothesis |- term =?= term' ]
      @ fold_right const
          (!reference <&> fun term -> [ hypothesis |- term <= term' ])
          [] )

  (*
    Γ ⊢ n : M    Γ ⊢ M : Type_0
    ---------------------------
    Γ ⊢ n as M : M
  *)

  and check_annotation hypothesis term' (term, term'', c) =
    [
      hypothesis |- term <= term''
    ; hypothesis |- term'' =?= term'
    ; hypothesis |- term'' <= kind ~c 0
    ]

  (*
    Γ ⊢ n : A    Γ ⊢ m : A
    ----------------------
    Γ ⊢ n = m : Type_0
  *)

  and check_equals hypothesis term' (lhd, rhd, _c) =
    let proof = hypothesis |- lhd => () in
    let lhd = get_type proof in
    proof_from_option ~proofs:[ proof ]
      ( lhd
      <&> fun lhd ->
      [ proof; hypothesis |- rhd <= lhd; hypothesis |- term' =?= kind 0 ] )

  (*
    Γ ⊢
    ----------------
    Γ ⊢ refl : m = m
  *)

  and check_refl hypothesis term' _c =
    proof_from_option
      ~reason:(return "Waiting for an equality")
      ( fold_opt ~equals:return term'
      <&> fun (lhd, rhd, _c) -> [ hypothesis |- lhd =?= rhd ] )

  (*
      Γ ⊢ b : x = B    Γ ⊢ a : A[x:=B]    Γ ⊢ b : B = x    Γ ⊢ a : A[x:=B]
      --------------------------------    --------------------------------
      Γ ⊢ subst a by b : A                Γ ⊢ subst a by b : A
  *)

  and check_subst hypothesis tA (a, b, _c) =
    let proof = hypothesis |- b => () in
    let tB = get_type proof in
    proof_from_option
      ~reason:(return "Waiting for an equality")
      ~proofs:[ proof ]
      ( tB
      >>= fold_opt ~equals:return
      <&> (fun (eql, eqr, _c) ->
            let tA' = try_substitute eql eqr tA in
            if tA = tA'
            then
              let tA' = try_substitute eqr eql tA in
              if tA = tA' then tA else tA'
            else tA' )
      <&> fun tA -> [ proof; hypothesis |- a <= tA ] )

  (*
    Γ ⊢
    ----------------
    Γ ⊢ < > : type_i

    Γ ⊢ T : type_i    Γ, n : T ⊢ r : type_i
    ----------------------------------------
    Γ ⊢ < n : T, r > : type_i
  *)

  and check_record_sig hypothesis term' (l, c) =
    let check hypothesis l t =
      List.fold_left
        (fun (l, h) (n, e) ->
          let p = h |- e <= t in
          (p :: l, h +: (n, e)) )
        ([], hypothesis) l
    in
    proof_from_option
      ~reason:(return "Waiting for type")
      ( fold_opt ~kind:return term'
      <&> (fun (level, _c) -> check hypothesis l (kind ~c level))
      <&> Stdlib.fst
      <&> List.rev )

  (*
    Γ ⊢
    -------------
    Γ ⊢ { } : < >

    Γ ⊢ e : T    Γ, n : T ⊢ r : R[n:=e]
    -----------------------------------
    Γ ⊢ { n = e, r } : < n : T, R >

    Γ ⊢ e : T'    Γ, n : T' ⊢ r : < m : T, R >    m ≠ n
    ---------------------------------------------------
    Γ ⊢ { n = e, r } : < m : T, R >
  *)

  and check_record_val hypothesis term' (l, _c) =
    let rec check hypothesis l lt =
      match (l, lt) with
      | [], [] -> []
      | [], (n', _) :: _ -> [ failure (Some ("waiting for " ^ n')) ]
      | (n, e) :: l, (n', t) :: lt when n = n' ->
        let p = hypothesis |- e <= t in
        let ps = check (hypothesis +: (n, t) += (n, e)) l lt in
        p :: ps
      | (n, e) :: l, lt ->
        let p = hypothesis |- e => () in
        let ps =
          fold_right const
            (get_type p <&> fun t -> check (hypothesis +: (n, t)) l lt)
            []
        in
        p :: ps
    in
    proof_from_option
      ~reason:(return "Waiting for record signature")
      ( fold_opt ~record_sig:return term'
      <&> fun (lt, _c) -> check hypothesis l lt )

  (*
    Γ ⊢ e : < n : T, R >
    --------------------
    Γ ⊢ e.n : T

    Γ ⊢ e : < m : T, R >    Γ, m : T ⊢ e.n : R    m ≠ n
    ---------------------------------------------------
    Γ ⊢ e.n : T[m:=e.m]
  *)

  and check_access hypothesis t' (r, n, c) =
    let proof = hypothesis |- access ~c r n => () in
    proof_from_option ~proofs:[ proof ]
      (get_type proof <&> fun t -> [ proof; hypothesis |- t' =?= t ])

  (* Additional rules for implicit parameters ... *)

  (*
    Γ ⊢ λ{x}.B : Π{x:A}.T   B ≠ λ{y}.C
    ----------------------------------
    Γ ⊢ B : Π{x:A}.T
  *)
  and implicit_argument hypothesis term term' =
    proof_from_option
      ~reason:(return "implicit_argument")
      (let implicit_lambda =
         fold_right const
           (fold_opt ~lambda:(fun (_, _, i, _) -> return i) term)
           false
       in
       fold_opt ~pi:(fun (n, _, _, i, _) -> return (n, i)) term'
       <&> fun (n, implicit_pi) ->
       if (not implicit_lambda) && implicit_pi
       then [ hypothesis |- lambda ~implicit:true n term <= term' ]
       else [ failure (Some "mixed implicit/explicit") ] )

  (*
    Γ ⊢ f : Π{x:M}.C   Γ, v:M ⊢ f {v} e : N
    ---------------------------------------
    Γ ⊢ f e : N
  *)
  and implicit_parameter hypothesis term term' =
    proof_from_option
      ~reason:(return "implicit_parameter")
      ( fold_opt ~apply:return term
      <&> fun (abstraction, argument, implicit_apply, _) ->
      if implicit_apply
      then [ failure (Some "mixed implicit/explicit") ]
      else
        let proof = hypothesis |- abstraction => () in
        let term'' = get_type proof in
        proof_from_option ~proofs:[ proof ]
          ~reason:(return "Waiting for a Pi term")
          ( term''
          >>= fold_opt ~pi:return
          <&> fun (n, bound, _, implicit_pi, _) ->
          if implicit_pi
          then
            let var, hypothesis = fresh_variable hypothesis n in
            let term =
              apply (apply ~implicit:true abstraction (hole var)) argument
            in
            [ proof; hypothesis +: (var, bound) |- term <= term' ]
          else [ proof; failure (Some "mixed implicit/explicit") ] ) )

  (*
    Γ ⊢ t : Type_i
    ------------------
    Γ ⊢ t : Type_{i+1}
  *)
  and type_level hypothesis term term' =
    proof_from_option ~reason:(return "type_level")
      ( fold_opt ~kind:return term'
      <&> fun (level, c) ->
      if level > 0
      then [ hypothesis |- term <= kind ~c (level - 1) ]
      else [ failure (Some "incompatible type level") ] )

  and nominal hypothesis term term' =
    fold
      ~kind:(check_kind hypothesis term')
      ~int:(check_int hypothesis term')
      ~char:(check_char hypothesis term')
      ~string:(check_string hypothesis term')
      ~id:(check_id hypothesis term')
      ~pi:(check_pi hypothesis term')
      ~lambda:(check_lambda hypothesis term')
      ~apply:(check_apply hypothesis term')
      ~let_binding:(check_let_binding hypothesis term')
      ~sigma:(check_sigma hypothesis term')
      ~pair:(check_pair hypothesis term')
      ~fst:(check_fst hypothesis term')
      ~snd:(check_snd hypothesis term')
      ~sum:(check_sum hypothesis term')
      ~inl:(check_inl hypothesis term')
      ~inr:(check_inr hypothesis term')
      ~case:(check_case hypothesis term')
      ~mu:(check_mu hypothesis term')
      ~fold:(check_fold hypothesis term')
      ~unfold:(check_unfold hypothesis term')
      ~hole:(check_hole hypothesis term')
      ~annotation:(check_annotation hypothesis term')
      ~equals:(check_equals hypothesis term')
      ~refl:(check_refl hypothesis term')
      ~subst:(check_subst hypothesis term')
      ~record_sig:(check_record_sig hypothesis term')
      ~record_val:(check_record_val hypothesis term')
      ~access:(check_access hypothesis term')
      term

  (* type checker main entrypoint *)
  and check_type hypothesis term term' =
    let term' = reduce hypothesis term' in
    let tactics =
      if Theory.type_in_type
      then [ nominal; implicit_argument; implicit_parameter ]
      else [ nominal; implicit_argument; implicit_parameter; type_level ]
    in
    (* Either can be uses here + Foldable *)
    let success, failures =
      List.fold_left
        (fun (success, failures) tactic ->
          match success with
          | Some _ -> (success, [])
          | None ->
            let proof =
              check hypothesis term term' (tactic hypothesis term term')
            in
            if is_success proof
            then (return proof, [])
            else (None, proof :: failures) )
        (None, []) tactics
    in
    match success with
    | Some proof -> proof
    | None ->
      List.fold_left
        (fun p p' -> if size p > size p' then p else p')
        (failure None) failures

  and ( <= ) (hypothesis, term) term' = check_type hypothesis term term'
end
