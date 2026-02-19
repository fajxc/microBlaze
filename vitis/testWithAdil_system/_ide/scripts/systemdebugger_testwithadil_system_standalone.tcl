# Usage with Vitis IDE:
# In Vitis IDE create a Single Application Debug launch configuration,
# change the debug type to 'Attach to running target' and provide this 
# tcl script in 'Execute Script' option.
# Path of this script: C:\ENEL400\microBlaze\vitis\testWithAdil_system\_ide\scripts\systemdebugger_testwithadil_system_standalone.tcl
# 
# 
# Usage with xsct:
# To debug using xsct, launch xsct and run below command
# source C:\ENEL400\microBlaze\vitis\testWithAdil_system\_ide\scripts\systemdebugger_testwithadil_system_standalone.tcl
# 
connect -url tcp:127.0.0.1:3121
targets -set -filter {jtag_cable_name =~ "Digilent Basys3 210183BD3E2DA" && level==0 && jtag_device_ctx=="jsn-Basys3-210183BD3E2DA-0362d093-0"}
fpga -file C:/ENEL400/microBlaze/vitis/testWithAdil/_ide/bitstream/test_w2_hs.bit
targets -set -nocase -filter {name =~ "*Hart*#0"}
loadhw -hw C:/ENEL400/microBlaze/vitis/platform/export/platform/hw/test_w2_hs.xsa -regs
targets -set -nocase -filter {name =~ "*Hart*#0"}
rst -system
after 3000
targets -set -nocase -filter {name =~ "*Hart*#0"}
dow C:/ENEL400/microBlaze/vitis/testWithAdil/Debug/testWithAdil.elf
targets -set -nocase -filter {name =~ "*Hart*#0"}
con
