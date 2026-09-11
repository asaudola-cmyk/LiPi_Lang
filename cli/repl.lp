@! ============================================================================
@! MAYA CLI INTERACTIVE REPL ENTRYPOINT
@! Module: cli/repl.maya
@! Usage: maya repl / maya --repl / ./bin/maya cli/repl.maya
@! ============================================================================

import "compiler/backend/jit/mod"

@fn main()
  state = repl_init()
  return repl_run(state)
@end
