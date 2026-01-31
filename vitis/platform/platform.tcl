# 
# Usage: To re-create this platform project launch xsct with below options.
# xsct C:\ENEL400\microBlaze\vitis\platform\platform.tcl
# 
# OR launch xsct and run below command.
# source C:\ENEL400\microBlaze\vitis\platform\platform.tcl
# 
# To create the platform in a different location, modify the -out option of "platform create" command.
# -out option specifies the output directory of the platform project.

platform create -name {platform}\
-hw {C:\ENEL400\microBlaze\hw\microV\letsTry.xsa}\
-proc {microblaze_riscv_0} -os {standalone} -out {C:/ENEL400/microBlaze/vitis}

platform write
platform generate -domains 
platform active {platform}
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform active {platform}
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/top.xsa}
platform clean
platform generate
platform generate -domains 
