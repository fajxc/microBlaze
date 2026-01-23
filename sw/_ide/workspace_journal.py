# 2026-01-22T22:01:21.616998500
import vitis

client = vitis.create_client()
client.set_workspace(path="sw")

component = client.get_component(name="uart_hello")

lscript = component.get_ld_script(path="C:\ENEL400\microBlaze\sw\uart_hello\src\lscript.ld")

lscript.regenerate()

lscript.regenerate()

platform = client.get_component(name="microblaze_platform")
status = platform.build()

status = platform.build()

comp = client.get_component(name="uart_hello")
comp.build()

vitis.dispose()

