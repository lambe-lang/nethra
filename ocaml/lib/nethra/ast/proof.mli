(* *)

type 'a t

module Builders : sig
  val check : 'a Term.t -> 'a Term.t -> 'a t list -> 'a t
  val infer : 'a Term.t -> 'a t list -> 'a t
  val congruent : 'a Term.t -> 'a Term.t -> 'a t list -> 'a t
  val failure : string option -> 'a t
end

module Catamorphism : sig
  val fold :
       check:('a Term.t * 'a Term.t * 'a t list -> 'b)
    -> infer:('a Term.t * 'a t list -> 'b)
    -> congruent:('a Term.t * 'a Term.t * 'a t list -> 'b)
    -> failure:(string option -> 'b)
    -> 'a t
    -> 'b
end
