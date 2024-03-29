open Stdlib.Fun
open Preface.Option.Monad
open Preface.Option.Foldable
open Nethra_lang_ast.Term
open Nethra_lang_ast.Term.Construct

let subs_kind (level, c) = kind ~c level
let subs_int (value, c) = int ~c value
let subs_char (value, c) = char ~c value
let subs_string (value, c) = string ~c value

let subs_id name value (n, initial, c) =
  if n = name then value else id ~c ~initial n

let subs_pi substitute name value (n, bound, body, implicit, c) =
  pi ~c ~implicit n
    (substitute name value bound)
    (if n = name then body else substitute name value body)

let subs_lambda substitute name value (n, body, implicit, c) =
  lambda ~c ~implicit n (if n = name then body else substitute name value body)

let subs_apply substitute name value (abstraction, parameter, implicit, c) =
  apply ~c ~implicit
    (substitute name value abstraction)
    (substitute name value parameter)

let subs_let_binding substitute name value (n, arg, body, c) =
  let_binding ~c n
    (substitute name value arg)
    (if n = name then body else substitute name value body)

let subs_sigma substitute name value (n, bound, body, c) =
  sigma ~c n
    (substitute name value bound)
    (if n = name then body else substitute name value body)

let subs_pair substitute name value (lhd, rhd, c) =
  pair ~c (substitute name value lhd) (substitute name value rhd)

let subs_fst substitute name value (term, c) =
  fst ~c (substitute name value term)

let subs_snd substitute name value (term, c) =
  snd ~c (substitute name value term)

let subs_sum substitute name value (lhd, rhd, c) =
  sum ~c (substitute name value lhd) (substitute name value rhd)

let subs_inl substitute name value (term, c) =
  inl ~c (substitute name value term)

let subs_inr substitute name value (term, c) =
  inr ~c (substitute name value term)

let subs_case substitute name value (term, left, right, c) =
  case ~c
    (substitute name value term)
    (substitute name value left)
    (substitute name value right)

let subs_mu substitute name value (n, kind, body, c) =
  mu ~c n
    (substitute name value kind)
    (if n = name then body else substitute name value body)

let subs_fold substitute name value (term, c) =
  fold ~c (substitute name value term)

let subs_unfold substitute name value (term, c) =
  unfold ~c (substitute name value term)

let subs_hole (v, r, c) = hole ~c ~r v

let subs_annotation substitute name value (term, kind, c) =
  annotation ~c (substitute name value term) (substitute name value kind)

let subs_equals substitute name value (lhd, rhd, c) =
  equals ~c (substitute name value lhd) (substitute name value rhd)

let subs_refl c = refl ~c ()

let subs_subst substitute name value (lhd, rhd, c) =
  subst ~c (substitute name value lhd) (substitute name value rhd)

let subs_record_sig substitute name value (l, c) =
  record_sig ~c (List.map (fun (n, t) -> (n, substitute name value t)) l)

let subs_record_val substitute name value (l, c) =
  record_val ~c (List.map (fun (n, t) -> (n, substitute name value t)) l)

let subs_access substitute name value (t, n, c) =
  access ~c (substitute name value t) n

let rec substitute name value term =
  Destruct.fold ~kind:subs_kind ~int:subs_int ~char:subs_char
    ~string:subs_string ~id:(subs_id name value)
    ~pi:(subs_pi substitute name value)
    ~lambda:(subs_lambda substitute name value)
    ~apply:(subs_apply substitute name value)
    ~let_binding:(subs_let_binding substitute name value)
    ~sigma:(subs_sigma substitute name value)
    ~pair:(subs_pair substitute name value)
    ~fst:(subs_fst substitute name value)
    ~snd:(subs_snd substitute name value)
    ~sum:(subs_sum substitute name value)
    ~inl:(subs_inl substitute name value)
    ~inr:(subs_inr substitute name value)
    ~case:(subs_case substitute name value)
    ~mu:(subs_mu substitute name value)
    ~fold:(subs_fold substitute name value)
    ~unfold:(subs_unfold substitute name value)
    ~hole:subs_hole
    ~annotation:(subs_annotation substitute name value)
    ~equals:(subs_equals substitute name value)
    ~refl:subs_refl
    ~subst:(subs_subst substitute name value)
    ~record_sig:(subs_record_sig substitute name value)
    ~record_val:(subs_record_val substitute name value)
    ~access:(subs_access substitute name value)
    term

let try_substitute id value term =
  fold_right const
    ( Destruct.fold_opt ~id:return id
    >>= fun (n, v, _) -> v <&> fun _ -> substitute n value term )
    term
