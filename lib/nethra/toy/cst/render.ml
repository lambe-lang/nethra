open Format
open Binding
open Term
open Localized

let render_operation ppf = function
  | Fst -> fprintf ppf "%s" "fst"
  | Snd -> fprintf ppf "%s" "snd"
  | Inl -> fprintf ppf "%s" "inl"
  | Inr -> fprintf ppf "%s" "inr"
  | Fold -> fprintf ppf "%s" "fold"
  | Unfold -> fprintf ppf "%s" "unfold"

let rec render_binding ppf = function
  | Signature (n, l) -> fprintf ppf "sig %s : %a" n render_localized l
  | Definition (n, None, l) -> fprintf ppf "val %s = %a" n render_localized l
  | Definition (n, Some t, l) ->
    fprintf ppf "val %s : %a = %a" n render_localized t render_localized l

and render_term ppf = function
  | Type i -> fprintf ppf "type%d" i
  | Var n -> fprintf ppf "%s" n
  | Literal (Int i) -> fprintf ppf "%d" i
  | Literal (String s) -> fprintf ppf "\"%s\"" s
  | Literal (Char c) -> fprintf ppf "'%c'" c
  | Pi (id, t1, t2, true) ->
    fprintf ppf "{%s:%a} -> %a" id render_localized t1 render_localized t2
  | Pi ("_", t1, t2, false) ->
    fprintf ppf "%a -> %a" render_localized t1 render_localized t2
  | Pi (id, t1, t2, false) ->
    fprintf ppf "(%s:%a) -> %a" id render_localized t1 render_localized t2
  | Sigma ("_", t1, t2) ->
    fprintf ppf "(%a) * (%a)" render_localized t1 render_localized t2
  | Sigma (id, t1, t2) ->
    fprintf ppf "(%s:%a) * %a" id render_localized t1 render_localized t2
  | Lambda (id, t, true) -> fprintf ppf "{%s}.(%a)" id render_localized t
  | Lambda (id, t, false) -> fprintf ppf "(%s).(%a)" id render_localized t
  | Let (id, None, v, f) ->
    fprintf ppf "let %s = %a in (%a)" id render_localized v render_localized f
  | Let (id, Some t, v, f) ->
    fprintf ppf "let %s : %a = %a in (%a)" id render_localized t
      render_localized v render_localized f
  | Rec (id, k, t) ->
    fprintf ppf "rec(%s:%a).(%a)" id render_localized k render_localized t
  | Case (t0, t1, t2) ->
    fprintf ppf "case (%a) (%a) (%a)" render_localized t0 render_localized t1
      render_localized t2
  | BuildIn (operation, t) ->
    fprintf ppf "%a (%a)" render_operation operation render_localized t
  | Apply (t1, t2, true) ->
    fprintf ppf "%a {%a}" render_localized t1 render_localized t2
  | Apply (t1, t2, false) ->
    fprintf ppf "%a (%a)" render_localized t1 render_localized t2
  | Sum (t1, t2) ->
    fprintf ppf "(%a) | (%a)" render_localized t1 render_localized t2
  | Pair (t1, t2) ->
    fprintf ppf "(%a),(%a)" render_localized t1 render_localized t2
  | Equal (t1, t2) ->
    fprintf ppf "(%a) =(%a)" render_localized t1 render_localized t2
  | Refl -> fprintf ppf "refl"
  | Subst (t1, t2) ->
    fprintf ppf "subst %a by %a" render_localized t1 render_localized t2
  | Record (S_Sig, _) -> fprintf ppf "sig struct ... end"
  | Record (S_Val, _) -> fprintf ppf "val struct ... end"
  | Access (e, id) -> fprintf ppf "#%s %a" id render_localized e
  | Annotation (e, t) ->
    fprintf ppf "(%a:%a)" render_localized e render_localized t

and render_localized ppt (Localized (t, _)) = render_term ppt t
