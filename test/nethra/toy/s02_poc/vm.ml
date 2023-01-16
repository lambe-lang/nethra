type value =
  | INT of int
  | UNIT

type instruction =
  | SEQ of instruction list
  | PUSH of value
  | EXEC
  | LAMBDA of string * instruction
  | DIG of int * string
  | DUP of int * string
  | DROP of int * string
  | SWAP
  | LEFT
  | RIGHT
  | IF_LEFT of instruction * instruction
  | PAIR
  | CAR
  | CDR

let render_value ppf =
  let open Format in
  function INT i -> fprintf ppf "INT %d" i | UNIT -> fprintf ppf "UNIT"

let rec render_list ppf =
  let open Format in
  function
  | [] -> ()
  | [ a ] -> render ppf a
  | a :: l -> fprintf ppf "%a; %a" render a render_list l

and render ppf =
  let open Format in
  function
  | SEQ l -> fprintf ppf "SEQ [%a]" render_list l
  | PUSH v -> fprintf ppf "PUSH (%a)" render_value v
  | EXEC -> fprintf ppf "EXEC"
  | LAMBDA (n, l) -> fprintf ppf "LAMBDA[%s] (%a)" n render l
  | DIG (i, n) -> fprintf ppf "DIG (%d,%s)" i n
  | DUP (i, n) -> fprintf ppf "DUP (%d,%s)" i n
  | DROP (i, n) -> fprintf ppf "DROP (%d,%s)" i n
  | SWAP -> fprintf ppf "SWAP"
  | LEFT -> fprintf ppf "LEFT"
  | RIGHT -> fprintf ppf "RIGHT"
  | IF_LEFT (l, r) -> fprintf ppf "IF_LEFT (%a,%a)" render l render r
  | PAIR -> fprintf ppf "PAIR"
  | CAR -> fprintf ppf "CAR"
  | CDR -> fprintf ppf "CDR"

let equal a b =
  match (a, b) with
  | DIG (i, _), DIG (j, _) -> i = j
  | DROP (i, _), DROP (j, _) -> i = j
  | DUP (i, _), DUP (j, _) -> i = j
  | _ -> a = b

let to_string o = Render.to_string render o