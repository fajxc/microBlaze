import numpy as np
import torch
from train_mlp import MLP

H = 32

def to_int8_with_scale(w: np.ndarray):
    max_abs = np.max(np.abs(w))
    if max_abs < 1e-12:
        scale = 1.0
    else:
        scale = 127.0 / max_abs
    wq = np.round(w * scale).astype(np.int8)
    return wq, scale

def write_i8_2d(path, name, arr):
    with open(path, "w") as f:
        f.write("#pragma once\n#include <stdint.h>\n\n")
        f.write(f"static const int8_t {name}[{arr.shape[0]}][{arr.shape[1]}] = {{\n")
        for r in range(arr.shape[0]):
            f.write("  {")
            f.write(",".join(str(int(x)) for x in arr[r]))
            f.write("}")
            f.write(",\n" if r != arr.shape[0]-1 else "\n")
        f.write("};\n")

def write_i32_1d(path, name, arr):
    with open(path, "w") as f:
        f.write("#pragma once\n#include <stdint.h>\n\n")
        f.write(f"static const int32_t {name}[{arr.shape[0]}] = {{")
        f.write(",".join(str(int(x)) for x in arr))
        f.write("};\n")

def main():
    # load float model
    model = MLP(hidden=H)
    sd = torch.load("mlp32.pth", map_location="cpu")
    model.load_state_dict(sd)
    model.eval()

    w1 = model.fc1.weight.detach().numpy()  # (H,784)
    b1 = model.fc1.bias.detach().numpy()    # (H,)
    w2 = model.fc2.weight.detach().numpy()  # (10,H)
    b2 = model.fc2.bias.detach().numpy()    # (10,)

    # quantize weights
    w1q, s1 = to_int8_with_scale(w1)
    w2q, s2 = to_int8_with_scale(w2)

    # biases: keep as int32, scale them roughly to match math
    # We'll treat input as centered uint8 (-128..127) so input scale ~1.
    b1q = np.round(b1 * s1).astype(np.int32)
    # Layer2 input is ReLU output; we will later downshift by SHIFT in HLS.
    SHIFT = 8
    b2q = np.round(b2 * s2 * (2**SHIFT)).astype(np.int32)

    out_dir = "../hls_nn/weights"
    import os
    os.makedirs(out_dir, exist_ok=True)

    write_i8_2d(f"{out_dir}/weights_w1.h", "w1", w1q)
    write_i32_1d(f"{out_dir}/weights_b1.h", "b1", b1q)
    write_i8_2d(f"{out_dir}/weights_w2.h", "w2", w2q)
    write_i32_1d(f"{out_dir}/weights_b2.h", "b2", b2q)

    print("Exported int8 weights to hls_nn/weights/")
    print("Scales:", s1, s2, "SHIFT:", SHIFT)

if __name__ == "__main__":
    main()
