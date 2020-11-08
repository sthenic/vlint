import strformat
import strutils
import terminal
import vparse

proc write_errors*(f: File, n: PNode) =
   case n.kind
   of ErrorTypes - {NkTokenErrorSync}:
      let loc = $n.loc.line & ":" & $(n.loc.col + 1)
      var msg = n.msg
      if len(n.eraw) > 0:
         add(msg, &" ({n.eraw})")
      add(msg, "\n")
      if terminal.isatty(f):
         styled_write(f, styleBright, &"{loc:<8} ", resetStyle, msg)
      else:
         write(f, &"{loc:<8} ", msg)
   of PrimitiveTypes - ErrorTypes + {NkTokenErrorSync}:
      return
   else:
      for i in 0..<len(n.sons):
         write_errors(f, n.sons[i])


proc find_undeclared_identifiers*(g: Graph): tuple[internal: seq[PNode], external: seq[PNode]] =
   ## Traverse the AST downwards starting from ``n``, searching for undeclared
   ## identifiers. The proc returns a tuple of sequences containing identifier
   ## nodes whose declaration is missing. The result is split into internal and
   ## external identifiers. Missing external identifiers is often an issue with
   ## the include paths used when the module graph ``g`` is parsed.
   # A rather naive, but straight-forward approach is to walk over all
   # identifiers and attempt to find a declaration in its context. Though we
   # have to filter out external identifiers and handle them separately since
   # the find_declaration proc only navigates the local AST.
   for (id, context) in walk_identifiers(g.root, recursive = true):
      if OpChars in id.identifier.s or id.kind == NkAttributeName or context[^1].n.kind == NkPort:
         continue

      if is_external_identifier(context):
         let (d, _, _) = find_external_declaration(g, context, id.identifier)
         if is_nil(d):
            add(result.external, id)
      else:
         let (d, _, _, _) = find_declaration(context, id.identifier)
         if is_nil(d):
            add(result.internal, id)
