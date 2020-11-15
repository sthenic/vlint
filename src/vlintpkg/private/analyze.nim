import strformat
import strutils
import terminal
import vparse


type
   UndeclaredIdentifierKind* = enum
      UkModule,
      UkModuleParameterPort,
      UkModulePort,
      UkInternal

   UndeclaredIdentifier* = object
      kind*: UndeclaredIdentifierKind
      identifier*: PNode
      meta*: PNode

   ConnectionErrorKind* = enum
      CkMissing,
      CkUnconnected

   ConnectionError* = object
      kind*: ConnectionErrorKind
      instance*: PNode
      identifier*: PIdentifier
      meta*: PNode


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


proc ignore_identifier(id: PNode, context: AstContext): bool =
   result =
      OpChars in id.identifier.s or
      id.kind == NkAttributeName or
      context[^1].n.kind in {NkPort, NkGenerateBlock, NkParBlock, NkSeqBlock} or
      (context[^1].n.kind == NkSystemTaskEnable and context[^1].pos == find_first_index(context[^1].n, NkIdentifier))


proc new_undeclared_identifier(kind: UndeclaredIdentifierKind, identifier, meta: PNode): UndeclaredIdentifier =
   result.kind = kind
   result.identifier = identifier
   result.meta = meta


proc new_undeclared_identifier(kind: NodeKind, identifier, meta: PNode): UndeclaredIdentifier =
   let ukind = case kind
   of NkModuleInstantiation:
      UkModule
   of NkNamedPortConnection:
      UkModulePort
   of NkNamedParameterAssignment:
      UkModuleParameterPort
   else:
      UkInternal
   result = new_undeclared_identifier(ukind, identifier, meta)


proc find_undeclared_identifiers*(g: Graph): seq[UndeclaredIdentifier] =
   ## Traverse the AST downwards starting from ``n``, searching for undeclared
   ## identifiers. The proc returns a sequences containing
   ## ``UndeclaredIdentifier`` objects representing each identifier node whose
   ## declaration is missing. Missing external identifiers is often an issue with
   ## the include paths used when the module graph ``g`` is parsed.
   # A rather naive, but straight-forward approach is to walk over all
   # identifiers and attempt to find a declaration in its context. Though we
   # have to filter out external identifiers and handle them separately since
   # find_declaration() only navigates the local AST.
   for (id, context) in walk_identifiers(g.root, recursive = true):
      if ignore_identifier(id, context):
         continue

      let (is_external, kind) = check_external_identifier(context)
      if is_external:
         let (d, _, _) = find_external_declaration(g, context, id.identifier)
         if is_nil(d):
            add(result, new_undeclared_identifier(kind, id, get_module_name_from_connection(context)))
      else:
         let (d, _, _, _) = find_declaration(context, id.identifier)
         if is_nil(d):
            add(result, new_undeclared_identifier(UkInternal, id, nil))


proc new_connection_error(kind: ConnectionErrorKind, instance: PNode,
                          identifier: PIdentifier, meta: PNode): ConnectionError =
   result.kind = kind
   result.instance = instance
   result.identifier = identifier
   result.meta = meta


proc find_unconnected_ports(g: Graph, module, instance: PNode): seq[ConnectionError] =
   ## For a given ``instance`` (``NkModuleInstance``) of a ``module``
   ## (``NkModuleDecl``), find any unconnected input ports.
   let module_name = find_first(module, NkIdentifier)
   if is_nil(module_name):
      return

   for connection in walk_sons(instance, NkNamedPortConnection):
      let id_idx = find_first_index(connection, NkIdentifier)
      if id_idx < 0:
         continue

      let id = connection[id_idx]
      let expr = find_first(connection, ExpressionTypes, id_idx + 1)
      if not is_nil(expr):
         continue

      let (declaration, _, _) = find_module_port_declaration(g, module_name.identifier, id.identifier)
      if is_nil(declaration):
         continue

      # FIXME: Not working for port references, but that fix should be in vparse
      #        to make find_module_port_declaration return the internal NkPortDecl.
      let direction = find_first(declaration, NkDirection)
      if not is_nil(direction) and direction.identifier.s == "input":
         add(result, new_connection_error(CkUnconnected, instance, id.identifier, connection))


proc find_missing_ports(g: Graph, module, instance: PNode): seq[ConnectionError] =
   ## For a given ``instance`` (``NkModuleInstance``) of a ``module``
   ## (``NkModuleDecl``), find any unlisted port connections, i.e. where the
   ## instance is not providing a value for a named port.
   var connections: seq[string]
   let named_connections = is_nil(find_first(instance, NkOrderedPortConnection))
   for connection in walk_sons(instance, NkNamedPortConnection):
      let id = find_first(connection, NkIdentifier)
      if not is_nil(id):
         add(connections, id.identifier.s)

   # Only check against the named module ports if the instance is using named
   # port connections.
   if named_connections:
      for port, id in walk_ports(module):
         if id.identifier.s notin connections:
            add(result, new_connection_error(CkMissing, instance, id.identifier, port))


proc find_connection_errors*(g: Graph): seq[ConnectionError] =
   # We walk through all the module declarations we find in graph's root node
   # and look for module instantiations. For each instance, we attempt to find a
   # matching declaration in the cache. If we do find one, we compare the port
   # connections between the instantiation and the declaration.
   for n in walk_sons(g.root, NkModuleDecl):
      for instantiation in walk_module_instantiations(n):
         let module_name = find_first(instantiation, NkIdentifier)
         if is_nil(module_name):
            continue

         let module = get_module(g, module_name.identifier.s)
         if is_nil(module):
            continue

         for instance in walk_sons(instantiation, NkModuleInstance):
            add(result, find_missing_ports(g, module.n, instance))
            add(result, find_unconnected_ports(g, module.n, instance))
