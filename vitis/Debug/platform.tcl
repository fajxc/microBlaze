# 
# Usage: To re-create this platform project launch xsct with below options.
# xsct C:\ENEL400\microBlaze\vitis\Debug\platform.tcl
# 
# OR launch xsct and run below command.
# source C:\ENEL400\microBlaze\vitis\Debug\platform.tcl
# 
# To create the platform in a different location, modify the -out option of "platform create" command.
# -out option specifies the output directory of the platform project.

platform create -name {Debug}\
-hw {C:\ENEL400\microBlaze\hw\microV\10.xsa}\
-proc {microblaze_riscv_0} -os {standalone} -out {C:/ENEL400/microBlaze/vitis}

platform write
platform generate -domains 
platform active {Debug}
platform clean
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/reversed.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/extraState.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/raw_h.xsa}
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/newest.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/finalCheks.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/340am.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/poopshit.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/433am.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/ispathded.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/dfgfdgfdgdfgdfgdfgd.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/daiper.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/lasttry_620am.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/top.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/march3.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/3reads.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/1.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/testfinal.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/w2_checck.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/checDUPE.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/primed.xsa}
platform clean
platform generate
platform clean
platform generate
