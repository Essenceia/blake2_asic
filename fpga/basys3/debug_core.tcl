set core_name "db_core_0"

create_debug_core $core_name ila

set_property C_INPUT_PIPE_STAGES 2   [get_debug_cores ${core_name}]

# connect clk to main design logic clk
connect_debug_port db_core_0/clk [get_nets clk]

# connect debug ports 
# dynamically connect all signals marked for debug in the design to 
# the debug core 

set raw_list [get_nets -hierarchical -filter {MARK_DEBUG == 1}]
array unset map *
foreach sig $raw_list {
    if {[regexp {^([^\[]+)} $sig -> base]} {
        puts "sig :"
		puts $sig
		puts "base :"
		puts $base
        lappend map($base) $sig
    }
}
set i 0
foreach sig [array names map] {
	if {$i != 0} {
		puts "create new probe $i for debug core $core_name"
		create_debug_port $core_name probe
	}
	puts "setting probe width to [llength $map($sig)]"
	set_property PORT_WIDTH [llength $map($sig)] [get_debug_ports $core_name/probe$i]
	puts "connecting debug port $core_name/probe$i to $map($sig)"
	connect_debug_port $core_name/probe$i [get_nets $map($sig)]
	incr i 1
}

