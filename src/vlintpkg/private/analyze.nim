import strformat
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
