# Usage with Vitis IDE:
# In Vitis IDE create a Single Application Debug launch configuration,
# change the debug type to 'Attach to running target' and provide this 
# tcl script in 'Execute Script' option.
# Path of this script: C:\ENEL400\microBlaze\vitis\mult_system\_ide\scripts\debugger_mult-default.tcl
# 
# 
# Usage with xsct:
# To debug using xsct, launch xsct and run below command
# source C:\ENEL400\microBlaze\vitis\mult_system\_ide\scripts\debugger_mult-default.tcl
# 
connect -url tcp:127.0.0.1:3121
targets -set -nocase -filter {name =~ "*Hart*#0"}
loadhw -hw C:/ENEL400/microBlaze/vitis/platform/export/platform/hw/feb17.xsa -regs
targets -set -nocase -filter {name =~ "*Hart*#0"}
rst -system
after 3000
targets -set -nocase -filter {name =~ "*Hart*#0"}
dow C:/ENEL400/microBlaze/vitis/mult/Debug/mult.elf
targets -set -nocase -filter {name =~ "*Hart*#0"}
con
