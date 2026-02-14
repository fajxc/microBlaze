import os
import numpy as np
import torch

from train_mlp import MLP

H = 32
SHIFT = 8  # keep consistent with your teammate's script

def to_int8_with_scale(w: np.ndarray):
    max_abs = np.max(np.abs(w))
    if max_abs < 1e-12:
        scale = 1.0
    else:
        scale = 127.0 / max_abs
    wq = np.round(w * scale).astype(np.int8)
    return wq, scale

def write_coe(path, values_hex, radix=16, values_per_line=16):
    """
    values_hex: list[str] like ["ff","0a",...] or ["ffffffea",...]
    """
    with open(path, "w") as f:
        f.write(f"memory_initialization_radix={radix};\n")
        f.write("memory_initialization_vector=\n")
        for i in range(0, len(values_hex), values_per_line):
            chunk = values_hex[i:i+values_per_line]
            line = ",".join(chunk)
            if i + values_per_line >= len(values_hex):
                f.write(line + ";\n")
            else:
                f.write(line + ",\n")

def i8_to_hex_list(arr_2d: np.ndarray):
    # row-major flatten (same order you'll address in hardware)
    flat = arr_2d.reshape(-1)
    return [f"{(int(x) & 0xFF):02x}" for x in flat]

def i32_to_hex_list(arr_1d: np.ndarray):
    flat = arr_1d.reshape(-1)
    return [f"{(int(x) & 0xFFFFFFFF):08x}" for x in flat]

def main():
    # Load float model
    model = MLP(hidden=H)
    sd = torch.load(r"C:\ENEL400\microBlaze\digit_fpga_nn\training\mlp32.pth", map_location="cpu")
    model.load_state_dict(sd)
    model.eval()

    w1 = model.fc1.weight.detach().numpy()  # (H,784)
    b1 = model.fc1.bias.detach().numpy()    # (H,)
    w2 = model.fc2.weight.detach().numpy()  # (10,H)
    b2 = model.fc2.bias.detach().numpy()    # (10,)

    # Quantize weights to int8
    w1q, s1 = to_int8_with_scale(w1)
    w2q, s2 = to_int8_with_scale(w2)

    # Biases int32 (same as your teammate)
    b1q = np.round(b1 * s1).astype(np.int32)
    b2q = np.round(b2 * s2 * (2**SHIFT)).astype(np.int32)

    out_dir = os.path.join(os.path.dirname(__file__), "vivado_init")
    os.makedirs(out_dir, exist_ok=True)

    # Write COE files
    write_coe(os.path.join(out_dir, "w1_i8.coe"), i8_to_hex_list(w1q), values_per_line=32)
    write_coe(os.path.join(out_dir, "w2_i8.coe"), i8_to_hex_list(w2q), values_per_line=32)
    write_coe(os.path.join(out_dir, "b1_i32.coe"), i32_to_hex_list(b1q), values_per_line=8)
    write_coe(os.path.join(out_dir, "b2_i32.coe"), i32_to_hex_list(b2q), values_per_line=8)

    # Save scale info (so you don't lose it)
    with open(os.path.join(out_dir, "quant_params.txt"), "w") as f:
        f.write(f"s1={s1}\n")
        f.write(f"s2={s2}\n")
        f.write(f"SHIFT={SHIFT}\n")

    print("Wrote Vivado init files to:", out_dir)
    print("Files:")
    print("  w1_i8.coe  (depth = 32*784 = 25088, width = 8)")
    print("  w2_i8.coe  (depth = 10*32  = 320,   width = 8)")
    print("  b1_i32.coe (depth = 32,     width = 32)")
    print("  b2_i32.coe (depth = 10,     width = 32)")
    print("Quant params saved to quant_params.txt")

if __name__ == "__main__":
    main()
