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
        sig one : int
        def one = id int 1
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
        def one = id 2
        -----------
      |toy}
    <&> fun (_, l) -> check l
  and expected = Result.Ok true in
  Alcotest.(check (result bool string))
    "basic implicit identity" expected (string_of_error result)

let compile_function () =
  let result =
    Pass.run
      {toy|
        -----------
        sig int : type
        -----------
        sig combine : int -> int -> int
        sig two : int
        def two = combine 1 1
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
        def two = combine int 1 1
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
        def two = combine {int} 1 1
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
        def two = combine 1 1
        -----------
      |toy}
    <&> fun (_, l) -> check l
  and expected = Result.Ok true in
  Alcotest.(check (result bool string))
    "basic inferred implicit polymorphic function" expected
    (string_of_error result)

let cases =
  let open Alcotest in
  ( "Function Compiler"
  , [
      test_case "basic identity" `Quick compile_identity
    ; test_case "basic implicit identity" `Quick compile_implicit_identity
    ; test_case "basic function" `Quick compile_function
    ; test_case "basic polymorphic function" `Quick compile_polymorphic_function
    ; test_case "basic implicit polymorphic function" `Quick
        compile_implicit_polymorphic_function
    ; test_case "basic inferred implicit polymorphic function" `Quick
        compile_inferred_implicit_polymorphic_function
    ] )
