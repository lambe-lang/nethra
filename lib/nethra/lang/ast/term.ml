(* *)

type implicit = bool

type lit =
  | Int of int
  | Char of char
  | String of string

type builtin =
  | Fst
  | Snd
  | Inl
  | Inr
  | Fold
  | Unfold

type 'a t =
  (* Basic type, identifier and literals *)
  | Type of int * 'a option
  | Id of string * string option * 'a option
  | Literal of lit * 'a option
  (* Function type and data *)
  | Pi of string * 'a t * 'a t * implicit * 'a option
  | Lambda of string * 'a t * implicit * 'a option
  | Apply of 'a t * 'a t * implicit * 'a option
  | Let of string * 'a t * 'a t * 'a option
  (* Pair type and data *)
  | Sigma of string * 'a t * 'a t * 'a option
  | Pair of 'a t * 'a t * 'a option
  (* Sum type and data *)
  | Sum of 'a t * 'a t * 'a option
  | Case of 'a t * 'a t * 'a t * 'a option
  (* Recursion *)
  | Mu of string * 'a t * 'a t * 'a option
  (* builtin  *)
  | BuiltIn of builtin * 'a t * 'a option
  (* Type for inference *)
  | Hole of string * 'a t option ref * 'a option
  (* Type annotation *)
  | Annotation of 'a t * 'a t * 'a option
  (* Propositional equality *)
  | Equals of 'a t * 'a t * 'a option
  | Refl of 'a option
  | Subst of 'a t * 'a t * 'a option
  (* Record type and Access *)
  | RecordSig of (string * 'a t) list * 'a option
  | RecordVal of (string * 'a t) list * 'a option
  | Access of 'a t * string * 'a option

module Construct = struct
  let kind ?(c = None) i = Type (i, c)
  let int ?(c = None) v = Literal (Int v, c)
  let string ?(c = None) v = Literal (String v, c)
  let char ?(c = None) v = Literal (Char v, c)
  let id ?(c = None) ?(initial = None) name = Id (name, initial, c)

  let pi ?(c = None) ?(implicit = false) n bound body =
    Pi (n, bound, body, implicit, c)

  let arrow ?(c = None) bound body = pi ~c "_" bound body

  let lambda ?(c = None) ?(implicit = false) n body =
    Lambda (n, body, implicit, c)

  let apply ?(c = None) ?(implicit = false) abs arg =
    Apply (abs, arg, implicit, c)

  let let_binding ?(c = None) id arg body = Let (id, arg, body, c)
  let sigma ?(c = None) n bound body = Sigma (n, bound, body, c)
  let pair ?(c = None) left right = Pair (left, right, c)
  let fst ?(c = None) term = BuiltIn (Fst, term, c)
  let snd ?(c = None) term = BuiltIn (Snd, term, c)
  let sum ?(c = None) left right = Sum (left, right, c)
  let inl ?(c = None) term = BuiltIn (Inl, term, c)
  let inr ?(c = None) term = BuiltIn (Inr, term, c)
  let case ?(c = None) term left right = Case (term, left, right, c)
  let mu ?(c = None) self kind body = Mu (self, kind, body, c)
  let fold ?(c = None) term = BuiltIn (Fold, term, c)
  let unfold ?(c = None) term = BuiltIn (Unfold, term, c)
  let hole ?(c = None) ?(r = ref None) n = Hole (n, r, c)
  let annotation ?(c = None) term kind = Annotation (term, kind, c)
  let equals ?(c = None) lhd rhd = Equals (lhd, rhd, c)
  let refl ?(c = None) _ = Refl c
  let subst ?(c = None) lhd rhd = Subst (lhd, rhd, c)
  let record_sig ?(c = None) l = RecordSig (l, c)
  let record_val ?(c = None) l = RecordVal (l, c)
  let access ?(c = None) t n = Access (t, n, c)
end

module Destruct = struct
  let fold ~kind ~int ~char ~string ~id ~pi ~lambda ~apply ~let_binding ~sigma
      ~pair ~fst ~snd ~sum ~inl ~inr ~case ~mu ~fold ~unfold ~hole ~annotation
      ~equals ~refl ~subst ~record_sig ~record_val ~access = function
    | Type (i, c) -> kind (i, c)
    | Literal (Int i, c) -> int (i, c)
    | Literal (Char i, c) -> char (i, c)
    | Literal (String i, c) -> string (i, c)
    | Id (name, initial, c) -> id (name, initial, c)
    | Pi (n, bound, body, implicit, c) -> pi (n, bound, body, implicit, c)
    | Lambda (n, body, implicit, c) -> lambda (n, body, implicit, c)
    | Apply (abs, arg, implicit, c) -> apply (abs, arg, implicit, c)
    | Let (n, arg, body, c) -> let_binding (n, arg, body, c)
    | Sigma (n, bound, body, c) -> sigma (n, bound, body, c)
    | Pair (first, second, c) -> pair (first, second, c)
    | BuiltIn (Fst, term, c) -> fst (term, c)
    | BuiltIn (Snd, term, c) -> snd (term, c)
    | Sum (lhd, rhd, c) -> sum (lhd, rhd, c)
    | BuiltIn (Inl, term, c) -> inl (term, c)
    | BuiltIn (Inr, term, c) -> inr (term, c)
    | Case (term, left, right, c) -> case (term, left, right, c)
    | Mu (self, kind, body, c) -> mu (self, kind, body, c)
    | BuiltIn (Fold, term, c) -> fold (term, c)
    | BuiltIn (Unfold, term, c) -> unfold (term, c)
    | Hole (n, body, c) -> hole (n, body, c)
    | Annotation (term, kind, c) -> annotation (term, kind, c)
    | Equals (lhd, rhd, c) -> equals (lhd, rhd, c)
    | Refl c -> refl c
    | Subst (lhd, rhd, c) -> subst (lhd, rhd, c)
    | RecordSig (l, c) -> record_sig (l, c)
    | RecordVal (l, c) -> record_val (l, c)
    | Access (l, n, c) -> access (l, n, c)

  let fold_opt =
    let internal_fold = fold in
    let none _ = None in
    let orElse f1 f2 t a = match f1 a with None -> f2 t | r -> r in
    fun ?(kind = none) ?(int = none) ?(char = none) ?(string = none)
        ?(id = none) ?(pi = none) ?(lambda = none) ?(apply = none)
        ?(let_binding = none) ?(sigma = none) ?(pair = none) ?(fst = none)
        ?(snd = none) ?(sum = none) ?(inl = none) ?(inr = none) ?(case = none)
        ?(mu = none) ?(fold = none) ?(unfold = none) ?(hole = none)
        ?(annotation = none) ?(equals = none) ?(refl = none) ?(subst = none)
        ?(record_sig = none) ?(record_val = none) ?(access = none)
        ?(default = none) term ->
      internal_fold ~kind:(orElse kind default term)
        ~int:(orElse int default term) ~char:(orElse char default term)
        ~string:(orElse string default term)
        ~id:(orElse id default term) ~pi:(orElse pi default term)
        ~lambda:(orElse lambda default term)
        ~apply:(orElse apply default term)
        ~let_binding:(orElse let_binding default term)
        ~sigma:(orElse sigma default term)
        ~pair:(orElse pair default term) ~fst:(orElse fst default term)
        ~snd:(orElse snd default term) ~sum:(orElse sum default term)
        ~inl:(orElse inl default term) ~inr:(orElse inr default term)
        ~case:(orElse case default term) ~mu:(orElse mu default term)
        ~fold:(orElse fold default term)
        ~unfold:(orElse unfold default term)
        ~hole:(orElse hole default term)
        ~annotation:(orElse annotation default term)
        ~equals:(orElse equals default term)
        ~refl:(orElse refl default term)
        ~subst:(orElse subst default term)
        ~record_sig:(orElse record_sig default term)
        ~record_val:(orElse record_val default term)
        ~access:(orElse access default term)
        term
end
