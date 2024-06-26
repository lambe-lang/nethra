open Common
open Nethra.Toy.Compiler

open Preface_stdlib.Result.Functor (struct
  type t = Nethra.Syntax.Source.Region.t Pass.error
end)

let compile_identity () =
  let result =
    Pass.run
      {toy|
        -----------
        sig int : type
        -----------
        sig id  : (a:type) -> a -> a
        val id  = fun _ a -> a
        sig one : int
        val one = id int 1
        -----------
      |toy}
    <&> fun (_, l) -> check l
  and expected = Result.Ok true in
  Alcotest.(check (result bool string))
    "basic identity" expected (string_of_error result)

let compile_implicit_identity () =
  let result =
    Pass.run
      {toy|
        -----------
        sig int : type
        -----------
        sig id  : {a:type} -> a -> a
        sig one : int
        val one = id 1
        -----------
      |toy}
    <&> fun (_, l) -> check l
  and expected = Result.Ok true in
  Alcotest.(check (result bool string))
    "basic implicit identity" expected (string_of_error result)

let compile_identity_usage () =
  let result =
    Pass.run
      {toy|
        -----------
        sig int : type
        -----------
        sig id   : {a:type} -> a -> a
        sig test : int -> int
        -----------
        -- Not capable to infer int type for the moment
        val test = id
      |toy}
    <&> fun (_, l) -> check l
  and expected = Result.Ok false in
  Alcotest.(check (result bool string))
    "basic implicit identity usage" expected (string_of_error result)

let compile_function () =
  let result =
    Pass.run
      {toy|
        -----------
        sig int : type
        -----------
        sig combine : int -> int -> int
        sig two : int
        val two = combine 1 1
        -----------
      |toy}
    <&> fun (_, l) -> check l
  and expected = Result.Ok true in
  Alcotest.(check (result bool string))
    "basic function" expected (string_of_error result)

let compile_polymorphic_function () =
  let result =
    Pass.run
      {toy|
        -- Preamble
        sig int : type
        -----------
        sig combine : (a:type) -> a -> a -> a
        sig two : int
        val two = combine int 1 1
        -----------
      |toy}
    <&> fun (_, l) -> check l
  and expected = Result.Ok true in
  Alcotest.(check (result bool string))
    "basic polymorphic function" expected (string_of_error result)

let compile_implicit_polymorphic_function () =
  let result =
    Pass.run
      {toy|
        -- Preamble
        sig int : type
        -----------
        sig combine : {a:type} -> a -> a -> a
        sig two : int
        val two = combine {int} 1 1
        -----------
      |toy}
    <&> fun (_, l) -> check l
  and expected = Result.Ok true in
  Alcotest.(check (result bool string))
    "basic implicit polymorphic function" expected (string_of_error result)

let compile_inferred_implicit_polymorphic_function () =
  let result =
    Pass.run
      {toy|
        -- Preamble
        sig int : type
        -----------
        sig combine : {a:type} -> a -> a -> a
        sig two : int
        val two = combine 1 1
        -----------
      |toy}
    <&> fun (_, l) -> check l
  and expected = Result.Ok true in
  Alcotest.(check (result bool string))
    "basic inferred implicit polymorphic function" expected
    (string_of_error result)

let compile_fixpoint_function () =
  let result =
    Pass.run
      {toy|
        sig fixpoint : {a b:type} -> ((a -> b) -> a -> b) -> a -> b
        val fixpoint = fun {a b} f -> rec(Fix:a -> b).fun x -> f Fix x -- NON!
        -{
          sig f = t
          the expression
            let rec f = e
          is translated to
            let f = rec(f:t).e
        }-
      |toy}
    <&> fun (_, l) -> check l
  and expected = Result.Ok true in
  Alcotest.(check (result bool string))
    "fixpoint function" expected (string_of_error result)

let compile_continuation () =
  let result =
    Pass.run
      {toy|
        -- Basic continuation definition
        sig cont : type -> type
        val cont = fun a -> {r:type} -> (a -> r) -> r
        -- Continuation definition with monad transformer
        sig contT : (type -> type) -> type -> type
        val contT = fun M a -> {r:type} -> (a -> M r) -> M r
      |toy}
    <&> fun (_, l) -> check l
  and expected = Result.Ok true in
  Alcotest.(check (result bool string))
    "continuation" expected (string_of_error result)

let cases =
  let open Alcotest in
  ( "Function Compiler"
  , [
      test_case "basic identity" `Quick compile_identity
    ; test_case "basic implicit identity" `Quick compile_implicit_identity
    ; test_case "basic implicit identity usage" `Quick compile_identity_usage
    ; test_case "basic function" `Quick compile_function
    ; test_case "basic polymorphic function" `Quick compile_polymorphic_function
    ; test_case "basic implicit polymorphic function" `Quick
        compile_implicit_polymorphic_function
    ; test_case "basic inferred implicit polymorphic function" `Quick
        compile_inferred_implicit_polymorphic_function
    ; test_case "fixpoint function" `Quick compile_fixpoint_function
    ; test_case "continuation" `Quick compile_continuation
    ] )
