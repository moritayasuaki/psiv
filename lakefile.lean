import Lake
open Lake DSL
package psiv where
  version := v!"0.5.0"
@[default_target]
lean_lib PSIV where
@[default_target]
lean_exe psiv_lean where
  srcDir := "examples/cli"
  root := `Main
@[default_target]
lean_exe psiv_vectors where
  srcDir := "examples/cli"
  root := `VectorMain
  supportInterpreter := false
  moreLinkArgs := #[]
