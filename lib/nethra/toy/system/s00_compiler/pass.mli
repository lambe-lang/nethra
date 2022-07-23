module Impl :
  Nethra_lang_specs.PASS
    with type _ input = string
     and type _ output =
      Nethra_syntax_source.Region.t Nethra_lang_ast.Context.Hypothesis.t
      * (string * Nethra_syntax_source.Region.t Nethra_lang_ast.Proof.t option)
        list
     and type _ error = string