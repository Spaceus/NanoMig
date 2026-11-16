# Synthesis of denise_scroll_history (block ram version) alone for the
# Primer 25K. Run from this directory:  gw_sh syn.tcl
# The result is in impl/gwsynthesis/scroll_history.vg and _syn.rpt.html

set_device GW5A-LV25MG121NC1/I0 -name GW5A-25A

set defs [open "syn_defs.vh" w]
puts $defs "`define GOWIN"
puts $defs "`define DENISE_EBR"
close $defs

add_file -type verilog syn_defs.vh
add_file -type verilog ../../src/minimig-aga/denise_bitplanes.v
add_file -type verilog syn_top.v

set_option -synthesis_tool gowinsynthesis
set_option -verilog_std sysv2017
set_option -top_module syn_top
set_option -output_base_name scroll_history

run syn
