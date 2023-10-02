#Read All Files
read_file -format verilog  LEDDC.v
#read_file -format sverilog  LASER.v
current_design LEDDC
link

#Setting Clock Constraints
source -echo -verbose LEDDC_DC.sdc
check_design
set high_fanout_net_threshold 0
uniquify
set_fix_multiple_port_nets -all -buffer_constants [get_designs *]
#set_max_area 0
#Synthesis all design
#compile -map_effort high -area_effort high
#compile -map_effort high -area_effort high -inc
compile_ultra

write -format ddc     -hierarchy -output "LEDDC_syn.ddc"
write_sdf -version 1.0  LEDDC_syn.sdf
write -format verilog -hierarchy -output LEDDC_syn.v
report_area > area.log
report_timing > timing.log
report_qor   >  LEDDC_syn.qor
exit
