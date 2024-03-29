module Parsec (Source : Nethra_syntax_source.Specs.SOURCE) = struct
  module Source = Source

  type 'b t = Source.t -> ('b, Source.t) Response.t

  let source c = Source.Construct.create c
end

module Functor (P : Specs.PARSEC) = Preface_make.Functor.Via_map (struct
  type 'a t = 'a P.t

  let map f p s =
    let open Response.Destruct in
    let open Response.Construct in
    fold
      ~success:(fun (a, b, s) -> success (f a, b, s))
      ~failure:(fun (m, b, s) -> failure (m, b, s))
      (p s)
end)

module Monad (P : Specs.PARSEC) = Preface_make.Monad.Via_return_and_bind (struct
  type 'a t = 'a P.t

  let return v s =
    let open Response.Construct in
    success (v, false, s)

  let bind f p s =
    let open Response.Destruct in
    let open Response.Construct in
    fold
      ~success:(fun (p, b1, s) ->
        fold
          ~success:(fun (a, b2, s) -> success (a, b1 || b2, s))
          ~failure:(fun (m, b, s) -> failure (m, b, s))
          (f p s) )
      ~failure:(fun (m, b, s) -> failure (m, b, s))
      (p s)
end)

module Eval (P : Specs.PARSEC) = struct
  module Monad = Monad (P)

  let locate p s =
    let module Region = Nethra_syntax_source.Region.Construct in
    let open Response.Destruct in
    let open Response.Construct in
    let open P.Source.Access in
    let l0 = location s in
    fold
      ~success:(fun (a, b, s) ->
        success ((a, Region.create l0 (location s)), b, s) )
      ~failure:(fun (m, _, _) -> failure (m, false, s))
      (p s)

  let eos s =
    let open Response.Construct in
    let open P.Source.Access in
    match next s with
    | Some _, s' -> failure (Some "stream not consumed", false, s')
    | None, s' -> success ((), false, s')

  let return = Monad.return

  let fail ?(consumed = false) ?(message = None) s =
    let open Response.Construct in
    failure (message, consumed, s)

  let do_lazy p s = Lazy.force p s

  let do_try p s =
    let open Response.Destruct in
    let open Response.Construct in
    fold
      ~success:(fun (a, b, s) -> success (a, b, s))
      ~failure:(fun (m, _, _) -> failure (m, false, s))
      (p s)

  let lookahead p s =
    let open Response.Destruct in
    let open Response.Construct in
    fold
      ~success:(fun (a, _, _) -> success (a, false, s))
      ~failure:(fun (m, _, _) -> failure (m, false, s))
      (p s)

  let satisfy p f =
    let open Monad in
    do_try
      ( p
      >>= fun a -> if f a then return a else fail ~consumed:false ~message:None
      )
end

module Operator (P : Specs.PARSEC) = struct
  module Functor = Functor (P)
  module Eval = Eval (P)

  let ( <~> ) p1 p2 s =
    let open Response.Destruct in
    let open Response.Construct in
    fold
      ~success:(fun (a1, b1, s1) ->
        fold
          ~success:(fun (a2, b2, s2) -> success ((a1, a2), b1 || b2, s2))
          ~failure:(fun (m, b2, s2) -> failure (m, b1 || b2, s2))
          (p2 s1) )
      ~failure:(fun (m, b1, s1) -> failure (m, b1, s1))
      (p1 s)

  let ( <~< ) p1 p2 = Functor.(p1 <~> p2 <&> fst)
  let ( >~> ) p1 p2 = Functor.(p1 <~> p2 <&> snd)

  let ( <~|~> ) p1 p2 s =
    let open Response.Destruct in
    let open Response.Construct in
    let open Functor in
    fold
      ~success:(fun (a, b, s) -> success (a, b, s))
      ~failure:(fun (m, b, s) ->
        if b then failure (m, b, s) else (p2 <&> fun e -> Either.Right e) s )
      ((p1 <&> fun e -> Either.Left e) s)

  let ( <|> ) p1 p2 =
    Functor.(p1 <~|~> p2 <&> function Either.Left a | Either.Right a -> a)

  let ( <?> ) p f =
    let open Eval in
    satisfy p f
end

module Atomic (P : Specs.PARSEC) = struct
  module Monad = Monad (P)
  module Eval = Eval (P)
  module Operator = Operator (P)

  let any s =
    let open Response.Construct in
    let open P.Source.Access in
    match next s with
    | Some e, s' -> success (e, true, s')
    | None, s' -> failure (Some "stream consumed", false, s')

  let not p s =
    let open Response.Destruct in
    let open Response.Construct in
    fold
      ~success:(fun (_, _, s) -> failure (None, false, s))
      ~failure:(fun (_, _, s) -> any s)
      (p s)

  let atom e =
    let open Operator in
    any <?> fun e' -> e' = e

  let atom_in l =
    let open Operator in
    any <?> fun e' -> List.mem e' l

  let atoms l =
    let open List in
    let open Monad in
    let open Eval in
    let open Operator in
    do_try
      (fold_left (fun p e -> p <~< atom e) (return ()) l <&> Stdlib.Fun.const l)
end

module Occurrence (P : Specs.PARSEC) = struct
  module Monad = Monad (P)
  module Eval = Eval (P)
  module Operator = Operator (P)

  let opt p s =
    let open Response.Destruct in
    let open Response.Construct in
    fold
      ~success:(fun (a, b, s) -> success (Some a, b, s))
      ~failure:(fun (m, b, s) ->
        if b then failure (m, b, s) else success (None, b, s) )
      (p s)

  let sequence optional p s =
    (* sequence is tail recursive *)
    let open Response.Destruct in
    let open Response.Construct in
    let rec sequence s aux b =
      fold
        ~success:(fun (a, b', s') -> sequence s' (a :: aux) (b || b'))
        ~failure:(fun (m, b', s') ->
          if b' || (aux = [] && not optional)
          then failure (m, b || b', s')
          else success (List.rev aux, b || b', s) )
        (p s)
    in
    sequence s [] false

  let rep p = sequence false p
  let opt_rep p = sequence true p
end

(* See https://hackage.haskell.org/package/parser-combinators-1.3.0/docs/src/Control.Monad.Combinators.Expr.html#Operator *)
module Expr (P : Specs.PARSEC) = struct
  module Monad = Monad (P)
  module Operator = Operator (P)

  let option x p =
    let open Monad in
    let open Operator in
    p <|> return x

  let term prefix t postfix =
    let open Stdlib.Fun in
    let open Monad in
    let open Monad.Syntax in
    let* pre = option id prefix in
    let* x = t in
    let* post = option id postfix in
    return @@ post @@ pre x

  let infixN op p x =
    let open Monad in
    let open Monad.Syntax in
    let* f = op in
    let* y = p in
    return @@ f x y

  let rec infixL op p x =
    let open Monad in
    let open Monad.Syntax in
    let open Operator in
    let* f = op in
    let* y = p in
    let r = f x y in
    infixL op p r <|> return r

  let rec infixR op p x =
    let open Monad in
    let open Monad.Syntax in
    let open Monad.Infix in
    let open Operator in
    let* f = op in
    let* y = p >>= fun r -> infixR op p r <|> return r in
    return @@ f x y
end

module Literal (P : Specs.PARSEC with type Source.e = char) = struct
  module Monad = Monad (P)
  module Atomic = Atomic (P)
  module Eval = Eval (P)
  module Operator = Operator (P)
  module Occurrence = Occurrence (P)

  let char c =
    let open Operator in
    let open Atomic in
    any <?> fun e' -> e' = c

  let char_in_ranges l =
    let open Operator in
    let open Atomic in
    any <?> fun e' -> List.exists (fun (l, u) -> l <= e' && e' <= u) l

  let char_in_range r = char_in_ranges [ r ]

  let char_in_list l =
    let open Operator in
    let open Atomic in
    any <?> fun e' -> List.mem e' l

  let char_in_string s =
    let open Nethra_syntax_source.Utils in
    char_in_list (chars_of_string s)

  let digit = char_in_range ('0', '9')
  let alpha = char_in_ranges [ ('a', 'z'); ('A', 'Z') ]

  let natural =
    let open Monad in
    let open Occurrence in
    let open Nethra_syntax_source.Utils in
    rep digit <&> string_of_chars <&> int_of_string

  let integer =
    let open Monad in
    let open Atomic in
    let open Operator in
    let open Occurrence in
    atom '-'
    >~> return (( * ) (-1))
    <|> (opt (atom '+') >~> return Stdlib.Fun.id)
    <~> natural
    <&> fun (f, i) -> f i

  let string s =
    let open Monad in
    let open Atomic in
    let open Nethra_syntax_source.Utils in
    atoms (chars_of_string s) <&> Stdlib.Fun.const s

  let string_in_list l =
    let open List in
    let open Eval in
    let open Operator in
    fold_left (fun p e -> p <|> string e) fail l

  let sequence p =
    let open Monad in
    let open Occurrence in
    let open Nethra_syntax_source.Utils in
    rep p <&> string_of_chars

  module Delimited = struct
    let string_delimited =
      let open Monad in
      let open Atomic in
      let open Operator in
      let open Occurrence in
      let open Nethra_syntax_source.Utils in
      char '"'
      >~> opt_rep
            (char '\\' >~> char '"' <&> Stdlib.Fun.const '"' <|> not (char '"'))
      <~< char '"'
      <&> string_of_chars

    let char_delimited =
      let open Monad in
      let open Atomic in
      let open Operator in
      char '\''
      >~> (string "\\\'" <&> Stdlib.Fun.const '\'' <|> not (char '\''))
      <~< char '\''

    let string = string_delimited
    let char = char_delimited
  end
end
