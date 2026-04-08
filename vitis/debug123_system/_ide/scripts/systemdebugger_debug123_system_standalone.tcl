# Usage with Vitis IDE:
# In Vitis IDE create a Single Application Debug launch configuration,
# change the debug type to 'Attach to running target' and provide this 
# tcl script in 'Execute Script' option.
# Path of this script: C:\Users\User\Downloads\ActualFinalDemoLast\microBlaze_with_Cam\microBlaze\vitis\debug123_system\_ide\scripts\systemdebugger_debug123_system_standalone.tcl
# 
# 
# Usage with xsct:
# To debug using xsct, launch xsct and run below command
# source C:\Users\User\Downloads\ActualFinalDemoLast\microBlaze_with_Cam\microBlaze\vitis\debug123_system\_ide\scripts\systemdebugger_debug123_system_standalone.tcl
# 
connect -url tcp:127.0.0.1:3121
targets -set -nocase -filter {name =~ "*Hart*#0"}
loadhw -hw C:/ENEL400/microBlaze_with_Cam/microBlaze/hw/microV/784.xsa -regs
targets -set -nocase -filter {name =~ "*Hart*#0"}
rst -system
after 3000
targets -set -nocase -filter {name =~ "*Hart*#0"}
dow C:/Users/User/Downloads/ActualFinalDemoLast/microBlaze_with_Cam/microBlaze/vitis/debug123/Debug/debug123.elf
targets -set -nocase -filter {name =~ "*Hart*#0"}
con
