open Format

let render_signature render_term ppf (n, t) =
  fprintf ppf "%s : %a, " n render_term t

let render render_term ppf p =
  let signatures = Nethra_lang_ast.Hypothesis.Access.signatures p in
  List.iter (render_signature render_term ppf) signatures

let render ?(term_render = Term.render) ppf p = render term_render ppf p