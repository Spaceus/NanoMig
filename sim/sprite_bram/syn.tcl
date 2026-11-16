# Synthesis of sprite_ram alone for the Primer 25K, to see what the block ram
# version becomes without a full build. Run from this directory:
#   gw_sh syn.tcl          SDPB primitive (GOWIN defined, as in the real build)
#   gw_sh syn.tcl infer    inferred version (GOWIN not defined)
# The result is in impl/gwsynthesis/sprite_ram_syn.rpt.html and .vg

set_device GW5A-LV25MG121NC1/I0 -name GW5A-25A

# defines have to come from a file that is added first
set defs [open "syn_defs.vh" w]
if {[lsearch -exact $argv "infer"] < 0} { puts $defs "`define GOWIN" }
close $defs

add_file -type verilog syn_defs.vh
add_file -type verilog ../../src/minimig-aga/sprite_ram.v
add_file -type verilog syn_top.v

set_option -synthesis_tool gowinsynthesis
set_option -verilog_std sysv2017
set_option -top_module syn_top
set_option -output_base_name sprite_ram

run syn
