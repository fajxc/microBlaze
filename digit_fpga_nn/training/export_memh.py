import numpy as np
import torch
from train_mlp import MLP

H = 32
SHIFT = 8

def to_int8_with_scale(w):
    max_abs = np.max(np.abs(w))
    scale = 127.0 / max_abs if max_abs > 1e-12 else 1.0
    return np.round(w * scale).astype(np.int8), scale

def write_mem_8(path, arr):
    with open(path, "w") as f:
        for v in arr.flatten():
            f.write(f"{(int(v) & 0xff):02x}\n")

def write_mem_32(path, arr):
    with open(path, "w") as f:
        for v in arr.flatten():
            f.write(f"{(int(v) & 0xffffffff):08x}\n")

# Load trained model
model = MLP(hidden=H)
sd = torch.load(
    r"C:\ENEL400\microBlaze\digit_fpga_nn\training\mlp32.pth",
    map_location="cpu"
)

model.load_state_dict(sd)
model.eval()

# Extract weights
w1 = model.fc1.weight.detach().numpy()   # (32,784)
b1 = model.fc1.bias.detach().numpy()     # (32,)
w2 = model.fc2.weight.detach().numpy()   # (10,32)
b2 = model.fc2.bias.detach().numpy()     # (10,)

# Quantize
w1q, s1 = to_int8_with_scale(w1)
w2q, s2 = to_int8_with_scale(w2)
b1q = np.round(b1 * s1).astype(np.int32)
b2q = np.round(b2 * s2 * (2**SHIFT)).astype(np.int32)

# Write mem files
write_mem_8("w1.mem", w1q)
write_mem_8("w2.mem", w2q)
write_mem_32("b1.mem", b1q)
write_mem_32("b2.mem", b2q)

print("Generated: w1.mem, w2.mem, b1.mem, b2.mem")
print("Scales:", s1, s2, "SHIFT:", SHIFT)
