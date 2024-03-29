type literal =
  | Int of int
  | String of string
  | Char of char

type operation =
  | Fst
  | Snd
  | Inl
  | Inr
  | Fold
  | Unfold

type sort =
  | S_Sig
  | S_Val

type t =
  | Type of int
  | Var of string
  | Literal of literal
  | Pi of (string * t Localized.t * t Localized.t * bool)
  | Sigma of (string * t Localized.t * t Localized.t)
  | Lambda of (string * t Localized.t * bool)
  | Let of (string * t Localized.t option * t Localized.t * t Localized.t)
  | Rec of (string * t Localized.t * t Localized.t)
  | Case of (t Localized.t * t Localized.t * t Localized.t)
  | BuildIn of (operation * t Localized.t)
  | Apply of (t Localized.t * t Localized.t * bool)
  | Sum of (t Localized.t * t Localized.t)
  | Pair of (t Localized.t * t Localized.t)
  | Equal of (t Localized.t * t Localized.t)
  | Refl
  | Subst of (t Localized.t * t Localized.t)
  | Record of sort * (string * t Localized.t) list
  | Access of t Localized.t * string
  | Annotation of t Localized.t * t Localized.t
