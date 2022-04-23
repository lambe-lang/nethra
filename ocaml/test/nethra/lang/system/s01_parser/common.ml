open Nethra.Syntax.Source
open Nethra.Syntax.Parser
open Nethra.Toy.Cst.Render

let response f r =
  let open Response.Destruct in
  fold
    ~success:(fun (a, b, _) -> (Some (f a), b))
    ~failure:(fun (b, _) -> (None, b))
    r

module Parsec = Parsers.Parsec (Sources.FromChars)

let render term =
  let buffer = Buffer.create 16 in
  let formatter = Format.formatter_of_buffer buffer in
  let () = render_localized formatter term in
  let () = Format.pp_print_flush formatter () in
  Buffer.contents buffer