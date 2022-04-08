(* *)

type 'a goal =
  | Check of 'a Term.t * 'a Term.t
  | Infer of 'a Term.t * 'a Term.t option
  | Equivalent of 'a Term.t * 'a Term.t

type 'a t =
  | Step of 'a goal * 'a t list
  | Fail of string option

module Construct = struct
  let check term kind steps = Step (Check (term, kind), steps)
  let infer term kind steps = Step (Infer (term, kind), steps)
  let equivalent term kind steps = Step (Equivalent (term, kind), steps)
  let failure reason = Fail reason
end

module Destruct = struct
  let fold ~check ~infer ~equivalent ~failure = function
    | Step (Check (term, kind), steps) -> check (term, kind, steps)
    | Step (Infer (term, kind), steps) -> infer (term, kind, steps)
    | Step (Equivalent (lhd, rhd), steps) -> equivalent (lhd, rhd, steps)
    | Fail reason -> failure reason
end

let rec is_success step =
  Destruct.fold
    ~check:(fun (_, _, steps) -> List.for_all is_success steps)
    ~infer:(fun (_, _, steps) -> List.for_all is_success steps)
    ~equivalent:(fun (_, _, steps) -> List.for_all is_success steps)
    ~failure:(fun _ -> false)
    step

let rec size step =
  1
  + Destruct.fold
      ~check:(fun (_, _, steps) ->
        List.fold_left (fun s e -> s + size e) 0 steps )
      ~infer:(fun (_, _, steps) ->
        List.fold_left (fun s e -> s + size e) 0 steps )
      ~equivalent:(fun (_, _, steps) ->
        List.fold_left (fun s e -> s + size e) 0 steps )
      ~failure:(fun _ -> 0)
      step