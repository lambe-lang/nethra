module type Parsec = sig
  module Source : Nethra_syntax_source.Specs.Source

  (* Profunctor -> Arrow? *)
  type 'a t = Source.t -> ('a, Source.t) Response.t

  val source : Source.Construct.c -> Source.t
end
