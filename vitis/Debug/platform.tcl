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
platform config -updatehw {C:/ENEL400/microBlaze/hw/microV/cleaned.xsa}
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
bsp reload
bsp config clocking "true"
bsp write
bsp reload
catch {bsp regenerate}
platform generate
bsp reload
bsp reload
platform clean
platform clean
platform generate
platform clean
platform generate
platform active {Debug}
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/april3_microV.xsa}
platform generate
platform clean
platform clean
platform generate
platform clean
platform clean
platform generate
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/april4_camera.xsa}
platform clean
platform clean
platform generate
platform clean
platform clean
platform generate
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/april4_microV.xsa}
platform clean
platform clean
platform generate
platform clean
platform clean
platform generate
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/april4_camera.xsa}
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/april4_camera.xsa}
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/april4_microV.xsa}
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/april4_microV.xsa}
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/april3_microV.xsa}
platform active {Debug}
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/april4_microV.xsa}
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/primed.xsa}
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/april3_microV.xsa}
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/april4_microV.xsa}
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/april3_microV.xsa}
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/primed.xsa}
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/cleaned.xsa}
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/april4_microV.xsa}
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/april3_microV.xsa}
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/march3.xsa}
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/april3_microV.xsa}
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/testfinal.xsa}
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/april3_microV.xsa}
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/april4_camera.xsa}
platform generate
platform generate -domains standalone_domain 
platform generate -domains standalone_domain 
platform active {Debug}
catch {platform remove platform}
platform config -updatehw {C:/ENEL_400/CameraTest/CameraTest/microBlaze/hw/microV/apr4_new.xsa}
platform clean
platform active {Debug}
platform clean
platform generate
platform clean
platform generate -domains standalone_domain 
platform clean
platform generate -domains standalone_domain 
platform clean
platform active {Debug}
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze_with_Cam/microBlaze/hw/microV/apr4_new.xsa}
platform config -updatehw {C:/ENEL400/microBlaze_with_Cam/microBlaze/hw/microV/top1.xsa}
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze_with_Cam/microBlaze/hw/microV/Fajar.xsa}
platform generate
platform clean
platform generate
platform active {Debug}
platform config -updatehw {C:/ENEL400/microBlaze_with_Cam/microBlaze/hw/microV/784.xsa}
platform clean
platform generate
platform clean
platform generate
platform active {Debug}
platform config -updatehw {C:/ENEL400/microBlaze_with_Cam/microBlaze/hw/microV/newpreprocess.xsa}
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze_with_Cam/microBlaze/hw/microV/uart_teststtsets.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze_with_Cam/microBlaze/hw/microV/1231321313.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze_with_Cam/microBlaze/hw/microV/km,s.xsa}
platform generate
platform config -updatehw {C:/ENEL400/microBlaze_with_Cam/microBlaze/hw/microV/newProcess.xsa}
platform clean
platform generate
platform active {Debug}
platform config -updatehw {C:/ENEL400/microBlaze_with_Cam/microBlaze/hw/microV/TestingDynamic.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze_with_Cam/microBlaze/hw/microV/topstatic.xsa}
platform clean
platform generate
platform active {Debug}
platform config -updatehw {C:/ENEL400/microBlaze_with_Cam/microBlaze/hw/microV/newUItest.xsa}
platform clean
platform generate
platform config -updatehw {C:/ENEL400/microBlaze_with_Cam/microBlaze/hw/microV/FINALFORDEMO.xsa}
platform clean
platform generate
platform active {Debug}
platform config -updatehw {C:/Users/User/Downloads/ActualFinalDemoLast/microBlaze_with_Cam/microBlaze/hw/microV/last_test.xsa}
platform clean
platform generate
