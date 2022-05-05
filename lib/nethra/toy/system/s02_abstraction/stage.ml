module Impl = struct
  type _ input = Nethra_toy_cst.Binding.t list

  type _ output =
    Nethra_syntax_source.Region.t Nethra_lang_ast.Context.Hypothesis.t

  let rec abstract_term r =
    let open Nethra_lang_ast.Term.Construct in
    let open Nethra_toy_cst.Term in
    function
    | Type l -> kind ~c:(Some r) l
    | Var l -> id ~c:(Some r) l
    | Literal (Int l) -> int ~c:(Some r) l
    | Literal (String l) -> string ~c:(Some r) l
    | Literal (Char l) -> char ~c:(Some r) l
    | Pi (n, t1, t2, b) ->
      pi ~c:(Some r) ~implicit:b n (abstract_localized t1)
        (abstract_localized t2)
    | Sigma (n, t1, t2) ->
      sigma ~c:(Some r) n (abstract_localized t1) (abstract_localized t2)
    | Lambda (n, t, b) ->
      lambda ~c:(Some r) ~implicit:b n (abstract_localized t)
    | Apply (t1, t2, b) ->
      apply ~c:(Some r) ~implicit:b (abstract_localized t1)
        (abstract_localized t2)
    | Let (n, t1, t2) ->
      apply ~c:(Some r) ~implicit:false
        (abstract_localized (Localized (Lambda (n, t2, false), r)))
        (abstract_localized t1)
    | Rec (n, t) -> mu ~c:(Some r) n (abstract_localized t)
    | Sum (t1, t2) ->
      sum ~c:(Some r) (abstract_localized t1) (abstract_localized t2)
    | Case (t1, t2, t3) ->
      case ~c:(Some r) (abstract_localized t1) (abstract_localized t2)
        (abstract_localized t3)
    | Pair (t1, t2) ->
      pair ~c:(Some r) (abstract_localized t1) (abstract_localized t2)
    | BuildIn (Fst, t) -> fst ~c:(Some r) (abstract_localized t)
    | BuildIn (Snd, t) -> snd ~c:(Some r) (abstract_localized t)
    | BuildIn (Inl, t) -> inl ~c:(Some r) (abstract_localized t)
    | BuildIn (Inr, t) -> inr ~c:(Some r) (abstract_localized t)
    | BuildIn (Fold, t) -> fold ~c:(Some r) (abstract_localized t)
    | BuildIn (Unfold, t) -> unfold ~c:(Some r) (abstract_localized t)

  and abstract_localized =
    let open Nethra_toy_cst.Localized in
    function Localized (t, r) -> abstract_term r t

  let rec abstract hypothesis =
    let open Nethra_lang_ast.Context.Hypothesis.Access in
    let open Nethra_toy_cst.Binding in
    function
    | [] -> hypothesis
    | Signature (n, t) :: bindings ->
      abstract (add_signature hypothesis (n, abstract_localized t)) bindings
    | Definition (n, t) :: bindings ->
      abstract (add_definition hypothesis (n, abstract_localized t)) bindings

  let run l =
    let open Nethra_lang_ast.Context.Hypothesis.Construct in
    Result.Ok (abstract create l)
end