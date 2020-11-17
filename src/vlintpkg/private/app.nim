import strutils
import streams
import times
import terminal
import vparse
import vltoml

import ./utils/[log, cli]
import ./analyze

const
   # Version information
   VERSION_STR = static_read("./VERSION").strip()
   # Exit codes: negative values are errors.
   ESUCCESS = 0
   EINVAL = -1
   EFILE = -2
   EPARSE = -3

   STATIC_HELP_TEXT = static_read("./CLI_HELP")

let HELP_TEXT = "vlint v" & VERSION_STR & "\n\n" & STATIC_HELP_TEXT

# If the terminal does not have the 'stdout' attribute, i.e. stdout does not
# lead back to the calling terminal, the output is piped to another
# application or written to a file. In any case, disable the colored output and
# do this before parsing the input arguments and options.
if not terminal.isatty(stdout):
   log.set_color_mode(NoColor)

# Parse the arguments and options and return a CLI state object.
var cli_state: CliState
try:
   cli_state = parse_cli()
except CliValueError:
   quit(EINVAL)

# Parse CLI object state.
if not cli_state.is_ok:
   # Invalid input combination (but otherwise correctly formatted arguments
   # and options).
   echo HELP_TEXT
   quit(EINVAL)
elif cli_state.print_help:
   # Show help text and exit.
   echo HELP_TEXT
   quit(ESUCCESS)
elif cli_state.print_version:
   # Show version information and exit.
   echo VERSION_STR
   quit(ESUCCESS)

log.info("vlint v" & VERSION_STR)

if len(cli_state.input_files) == 0:
   log.error("No input files, aborting.")
   quit(EINVAL)

var exit_val = ESUCCESS
let module_cache = new_module_cache()
let locations = new_locations()
var include_paths = new_seq_of_cap[string](32)
var defines = new_seq_of_cap[string](32)
for filename in cli_state.input_files:
   let fs = new_file_stream(filename)
   if fs == nil:
      log.error("Failed to open '$1' for reading, skipping.", filename)
      continue

   # Load any configuration file.
   var configuration: Configuration
   init(configuration)
   let cfilename = find_configuration_file(filename)
   if len(cfilename) > 0:
      try:
         configuration = vltoml.parse_file(cfilename)
         log.info("Using configuration file '$1'.", cfilename)
      except ConfigurationParseError as e:
         log.error("Failed to parse configuration file '$1'.", e.msg)

   # Prepare the parse.
   set_len(include_paths, 0)
   set_len(defines, 0)
   add(include_paths, configuration.include_paths)
   add(include_paths, cli_state.include_paths)
   add(defines, configuration.defines)
   add(defines, cli_state.defines)
   let cache = new_ident_cache()
   let graph = new_graph(cache, module_cache, locations)
   log.info("Parsing source file '$1'", filename)
   let t_start = cpu_time()
   let root = parse(graph, fs, filename, include_paths, defines)
   let t_diff_ms = (cpu_time() - t_start) * 1000
   close(fs)

   log.info("Parse completed in ", fgGreen, styleBright,
            format_float(t_diff_ms, ffDecimal, 1), " ms", resetStyle, ".")

   # Analyze the AST.
   if has_errors(root):
      log.error("The AST contains errors.\n")
      write_errors(stdout, root)
      exit_val = EPARSE
   else:
      log.info("No errors.\n")

   let undeclared_identifiers = find_undeclared_identifiers(graph)
   for id in undeclared_identifiers:
      log.info("'$1' is undeclared ($2).", id.identifier.identifier.s, $id.kind)
      log.info("meta: $1", if is_nil(id.meta): "nil" else: pretty(id.meta))

   for error in find_connection_errors(graph):
      case error.kind
      of CkMissingPort:
         log.info("Missing port '$1'.", error.identifier.s)
      of CkUnconnectedPort:
         log.info("Input port '$1' is unconnected.", error.identifier.s)
      of CkMissingParameter:
         log.info("Missing parameter assignment '$1'.", error.identifier.s)
      of CkUnassignedParameter:
         log.info("Parameter '$1' is unassigned.", error.identifier.s)


quit(exit_val)
