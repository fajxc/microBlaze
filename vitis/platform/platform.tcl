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
platform active {platform}
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/nntest.xsa}
platform clean
platform generate
platform generate -domains 
platform active {platform}
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/nnv1.xsa}
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/weight_test.xsa}
platform clean
platform generate
platform generate -domains 
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/weight_test.xsa}
platform generate -domains 
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/feb9.xsa}
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform generate -domains 
platform clean
platform generate
platform active {platform}
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/feb13.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/2-feb13.xsa}
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/3-feb13.xsa}
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/4mem-feb13.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/lastTestMem.xsa}
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/v1mac.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/feb16.xsa}
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/feb16new.xsa}
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/changed.xsa}
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/pls_work.xsa}
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/yaAllah.xsa}
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/habibi.xsa}
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/godhelpme.xsa}
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/top.xsa}
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/feb17.xsa}
platform clean
platform generate
