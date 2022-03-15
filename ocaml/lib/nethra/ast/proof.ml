(* *)

type 'a goal =
  | Check of 'a Term.t * 'a Term.t
  | Infer of 'a Term.t
  | Congruent of 'a Term.t * 'a Term.t

type 'a t =
  | Step of 'a goal * 'a t list
  | Fail of string option

module Builders = struct
  let check term kind steps = Step (Check (term, kind), steps)
  let infer term steps = Step (Infer term, steps)
  let congruent term kind steps = Step (Congruent (term, kind), steps)
  let failure reason = Fail reason
end

module Catamorphism = struct
  let fold ~check ~infer ~congruent ~failure = function
    | Step (Check (term, kind), steps) -> check (term, kind, steps)
    | Step (Infer term, steps) -> infer (term, steps)
    | Step (Congruent (lhd, rhd), steps) -> congruent (lhd, rhd, steps)
    | Fail reason -> failure reason
end

let rec is_success step =
  Catamorphism.fold
    ~check:(fun (_, _, steps) -> List.for_all is_success steps)
    ~infer:(fun (_, steps) -> List.for_all is_success steps)
    ~congruent:(fun (_, _, steps) -> List.for_all is_success steps)
    ~failure:(fun _ -> false)
    step