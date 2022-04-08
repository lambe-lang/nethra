module Parsec : functor (Source : Nethra_syntax_source.Specs.Source) ->
  Specs.Parsec with module Source = Source

module Functor : functor (Parsec : Specs.Parsec) ->
  Preface_specs.FUNCTOR with type 'a t = 'a Parsec.t

module Monad : functor (Parsec : Specs.Parsec) ->
  Preface_specs.MONAD with type 'a t = 'a Parsec.t

module Eval : functor (Parsec : Specs.Parsec) -> sig
  val eos : unit Parsec.t
  val return : 'a -> 'a Parsec.t
  val fail : ?consumed:bool -> 'a Parsec.t
  val do_lazy : (unit -> 'a Parsec.t) -> 'a Parsec.t
  val do_try : 'a Parsec.t -> 'a Parsec.t
  val lookahead : 'a Parsec.t -> 'a Parsec.t
  val satisfy : 'a Parsec.t -> ('a -> bool) -> 'a Parsec.t
end

module Operator : functor (Parsec : Specs.Parsec) -> sig
  val ( <~> ) : 'a Parsec.t -> 'b Parsec.t -> ('a * 'b) Parsec.t
  val ( <~< ) : 'a Parsec.t -> 'b Parsec.t -> 'a Parsec.t
  val ( >~> ) : 'a Parsec.t -> 'b Parsec.t -> 'b Parsec.t
  val ( <|> ) : 'a Parsec.t -> 'a Parsec.t -> 'a Parsec.t
  val ( <?> ) : 'a Parsec.t -> ('a -> bool) -> 'a Parsec.t
end

module Atomic : functor (Parsec : Specs.Parsec) -> sig
  val any : Parsec.Source.e Parsec.t
  val atom : Parsec.Source.e -> Parsec.Source.e Parsec.t
  val atom_in : Parsec.Source.e list -> Parsec.Source.e Parsec.t
  val atoms : Parsec.Source.e list -> Parsec.Source.e list Parsec.t
  val not : 'a Parsec.t -> Parsec.Source.e Parsec.t
end

module Occurrence : functor (Parsec : Specs.Parsec) -> sig
  val opt : 'a Parsec.t -> 'a option Parsec.t
  val rep : 'a Parsec.t -> 'a list Parsec.t
  val opt_rep : 'a Parsec.t -> 'a list Parsec.t
end

module Literal : functor
  (Parsec : Specs.Parsec with type Source.e = char)
  -> sig
  val char : char -> char Parsec.t
  val char_in_range : char * char -> char Parsec.t
  val char_in_list : char list -> char Parsec.t
  val char_in_string : string -> char Parsec.t
  val digit : char Parsec.t
  val alpha : char Parsec.t
  val natural : int Parsec.t
  val integer : int Parsec.t
  val string : string -> string Parsec.t
  val sequence : char Parsec.t -> string Parsec.t

  module Delimited : sig
    val string : string Parsec.t
    val char : char Parsec.t
  end
end