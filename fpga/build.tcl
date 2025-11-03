set project_path [lindex $argv 0]
set checkpoint_path [lindex $argv 1]
if { $argc > 2 } {
	set enable_debug_core [lindex $argv 2]
	set debug_probes_path [lindex $argv 3]
} else {
	set enable_debug_core 0
	set debug_probes_path "/tmp/dump"
}
puts "Implementation script called with project path $project_path, generating checkpoint at $checkpoint_path"

open_project $project_path 

# synth
synth_design -top emulator

if { $enable_debug_core } {
	source debug_core.tcl
} 

# implement
opt_design
place_design
route_design
phys_opt_design
report_timing_summary -no_detailed_paths

if { $enable_debug_core } {
	write_debug_probes -force $debug_probes_path
	report_debug_core
}

write_checkpoint $checkpoint_path -force 
close_project
exit 0
