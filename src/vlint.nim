import strutils
import streams
import times
import terminal
import vparse
import vltoml

import ./log
import ./cli

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

var g: Graph
var exit_val = ESUCCESS
for filename in cli_state.input_files:
   let fs = new_file_stream(filename)
   if fs == nil:
      log.error("Failed to open '$1' for reading, skipping.", filename)
      continue

   let cache = new_ident_cache()
   log.info("Parsing source file '$1'", filename)
   let t_start = cpu_time()
   open_graph(g, cache, fs, filename, cli_state.include_paths, cli_state.defines)
   let t_diff_ms = (cpu_time() - t_start) * 1000
   let root_node = parse_all(g)

   log.info("Parse completed in ", fgGreen, styleBright,
            format_float(t_diff_ms, ffDecimal, 1), " ms", resetStyle, ".")

   if has_errors(root_node):
      log.error("The AST contains errors.")
      exit_val = EPARSE
   else:
      log.info("No errors.\n")

   close_graph(g)
   close(fs)

quit(exit_val)
