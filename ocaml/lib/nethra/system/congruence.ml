open Stdlib.Fun
open Preface.Option.Monad
open Preface.Option.Foldable
open Nethra_ast.Ast.Term.Builders
open Nethra_ast.Ast.Term.Catamorphism
open Nethra_ast.Ast.Proof.Builders
open Nethra_ast.Ast.Hypothesis.Access
open Reduction
open Substitution
include Judgment

(* Reference management in holes should be replaced thanks to a
   state monad embedding the hypothesis *)

let proof_from_option ?(reason = None) o = fold_right const o [ failure reason ]

let congruent_kind term' (level, _) =
  proof_from_option
    ( fold_opt ~kind:return term'
    >>= fun (level', _) -> if level = level' then Some [] else None )

let congruent_int term' (value, _) =
  proof_from_option
    ( fold_opt ~int:return term'
    >>= fun (value', _) -> if value = value' then Some [] else None )

let congruent_char term' (value, _) =
  proof_from_option
    ( fold_opt ~char:return term'
    >>= fun (value', _) -> if value = value' then Some [] else None )

let congruent_string term' (value, _) =
  proof_from_option
    ( fold_opt ~string:return term'
    >>= fun (value', _) -> if value = value' then Some [] else None )

let congruent_id term' (name, _, _) =
  proof_from_option
    ( fold_opt ~id:return term'
    >>= fun (name', _, _) -> if name = name' then Some [] else None )

let rec congruent_pi hypothesis term' (name, bound, body, implicit, c) =
  proof_from_option
    ( fold_opt ~pi:return term'
    >>= fun (name', bound', body', implicit', c') ->
    if implicit' = implicit
    then
      let var, hypothesis = fresh_variable hypothesis name in
      let body = substitute name (id ~c ~initial:(Some name) var) body
      and body' = substitute name' (id ~c:c' ~initial:(Some name') var) body' in
      Some [ hypothesis |- bound =?= bound'; hypothesis |- body =?= body' ]
    else None )

and congruent_lambda hypothesis term' (name, body, implicit, c) =
  proof_from_option
    ( fold_opt ~lambda:return term'
    >>= fun (name', body', implicit', c') ->
    if implicit' = implicit
    then
      let var, hypothesis = fresh_variable hypothesis name in
      let body = substitute name (id ~c ~initial:(Some name) var) body
      and body' = substitute name' (id ~c:c' ~initial:(Some name') var) body' in
      Some [ hypothesis |- body =?= body' ]
    else None )

and congruent_apply hypothesis term' (abstraction, argument, implicit, _) =
  proof_from_option
    ( fold_opt ~apply:return term'
    >>= fun (abstraction', argument', implicit', _) ->
    if implicit' = implicit
    then
      Some
        [
          hypothesis |- abstraction =?= abstraction'
        ; hypothesis |- argument =?= argument'
        ]
    else None )

and congruent_sigma hypothesis term' (name, bound, body, c) =
  proof_from_option
    ( fold_opt ~sigma:return term'
    <&> fun (name', bound', body', c') ->
    let var, hypothesis = fresh_variable hypothesis name in
    let body = substitute name (id ~c ~initial:(Some name) var) body
    and body' = substitute name' (id ~c:c' ~initial:(Some name') var) body' in
    [ hypothesis |- bound =?= bound'; hypothesis |- body =?= body' ] )

and congruent_pair hypothesis term' (lhd, rhd, _c) =
  proof_from_option
    ( fold_opt ~pair:return term'
    <&> fun (lhd', rhd', _) ->
    [ hypothesis |- lhd =?= lhd'; hypothesis |- rhd =?= rhd' ] )

and congruent_fst hypothesis term' (term, _c) =
  proof_from_option
    ( fold_opt ~fst:return term'
    <&> fun (term', _) -> [ hypothesis |- term =?= term' ] )

and congruent_snd hypothesis term' (term, _c) =
  proof_from_option
    ( fold_opt ~snd:return term'
    <&> fun (term', _) -> [ hypothesis |- term =?= term' ] )

and congruent_sum hypothesis term' (lhd, rhd, _c) =
  proof_from_option
    ( fold_opt ~sum:return term'
    <&> fun (lhd', rhd', _) ->
    [ hypothesis |- lhd =?= lhd'; hypothesis |- rhd =?= rhd' ] )

and congruent_inl hypothesis term' (term, _c) =
  proof_from_option
    ( fold_opt ~inl:return term'
    <&> fun (term', _) -> [ hypothesis |- term =?= term' ] )

and congruent_inr hypothesis term' (term, _c) =
  proof_from_option
    ( fold_opt ~inr:return term'
    <&> fun (term', _) -> [ hypothesis |- term =?= term' ] )

and congruent_case hypothesis term' (term, left, right, _c) =
  proof_from_option
    ( fold_opt ~case:return term'
    <&> fun (term', left', right', _c') ->
    [
      hypothesis |- term =?= term'
    ; hypothesis |- left =?= left'
    ; hypothesis |- right =?= right'
    ] )

and congruent_mu hypothesis term' (name, body, c) =
  proof_from_option
    ( fold_opt ~mu:return term'
    <&> fun (name', body', c') ->
    let var, hypothesis = fresh_variable hypothesis name in
    let body = substitute name (id ~c ~initial:(Some name) var) body
    and body' = substitute name' (id ~c:c' ~initial:(Some name') var) body' in
    [ hypothesis |- body =?= body' ] )

and congruent_fold hypothesis term' (term, _c) =
  proof_from_option
    ( fold_opt ~fold:return term'
    <&> fun (term', _) -> [ hypothesis |- term =?= term' ] )

and congruent_unfold hypothesis term' (term, _c) =
  proof_from_option
    ( fold_opt ~unfold:return term'
    <&> fun (term', _) -> [ hypothesis |- term =?= term' ] )

and congruent_hole hypothesis term' (name, reference, _c) =
  match !reference with
  | Some term -> [ hypothesis |- term =?= term' ]
  | None -> (
    match fold_opt ~hole:return term' with
    | Some (name', _, _) when name = name' -> []
    | _ ->
      let () = reference := Some term' in
      [] )

and congruent_terms hypothesis term term' =
  let term = reduce hypothesis term
  and term' = reduce hypothesis term' in
  let term, term' =
    fold_right const
      (fold_opt ~hole:return term' <&> fun _ -> (term', term))
      (term, term')
  in
  let proofs =
    fold ~kind:(congruent_kind term') ~int:(congruent_int term')
      ~char:(congruent_char term') ~string:(congruent_string term')
      ~id:(congruent_id term')
      ~pi:(congruent_pi hypothesis term')
      ~lambda:(congruent_lambda hypothesis term')
      ~apply:(congruent_apply hypothesis term')
      ~sigma:(congruent_sigma hypothesis term')
      ~pair:(congruent_pair hypothesis term')
      ~fst:(congruent_fst hypothesis term')
      ~snd:(congruent_snd hypothesis term')
      ~sum:(congruent_sum hypothesis term')
      ~inl:(congruent_inl hypothesis term')
      ~inr:(congruent_inr hypothesis term')
      ~case:(congruent_case hypothesis term')
      ~mu:(congruent_mu hypothesis term')
      ~fold:(congruent_fold hypothesis term')
      ~unfold:(congruent_unfold hypothesis term')
      ~hole:(congruent_hole hypothesis term')
      term
  in
  congruent term term' proofs

and ( =?= ) (hypothesis, term) term' = congruent_terms hypothesis term term'
