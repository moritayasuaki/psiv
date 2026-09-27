import Lake
open Lake DSL
package psiv_consumer where
require psiv from "../.."
@[default_target]
lean_exe psiv_spec_example where
  root := `Main
