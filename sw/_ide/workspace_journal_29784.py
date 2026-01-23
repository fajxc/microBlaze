# 2026-01-22T21:35:54.192437400
import vitis

client = vitis.create_client()
client.set_workspace(path="sw")

advanced_options = client.create_advanced_options_dict(dt_overlay="0")

platform = client.create_platform_component(name = "microblaze_platform",hw_design = "$COMPONENT_LOCATION/../../hw/microBlaze/design_1_wrapper.xsa",os = "standalone",cpu = "microblaze_riscv_0",domain_name = "standalone_microblaze_riscv_0",generate_dtb = False,advanced_options = advanced_options,compiler = "gcc")

platform = client.get_component(name="microblaze_platform")
status = platform.build()

comp = client.create_app_component(name="uart_hello",platform = "$COMPONENT_LOCATION/../microblaze_platform/export/microblaze_platform/microblaze_platform.xpfm",domain = "standalone_microblaze_riscv_0")

comp = client.get_component(name="uart_hello")
comp.build()

comp.build()

vitis.dispose()

