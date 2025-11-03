set checkpoint_path [lindex $argv 0]
set out_dir [lindex $argv 1]
puts "Programming script called with checkpoint path $checkpoint_path, generating bitsteam to $out_dir folder"



puts "Opening program at $checkpoint_path"
open_checkpoint $checkpoint_path 

set bin_path "$out_dir/[current_project]"

open_hw_manager
connect_hw_server

# autodetecting xilinx approved programmer, will fail otherwise, will used current_hw_target by default
puts "Detecting hw target [current_hw_target]"

if { [current_hw_target] ne "" } {
	puts "Writing bistream at $bin_path.bit"
	write_bitstream "$bin_path.bit" -force

	open_hw_target
	current_hw_device

	set_property PROGRAM.FILE $bin_path.bit [current_hw_device]

	set fail [program_hw_device -verbose]
	
} else {

	puts "Error : no hw target detected !"

}

close_hw_manager
exit 0


