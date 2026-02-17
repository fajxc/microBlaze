import re
import numpy as np

def load_h_initializer_only(path):
    with open(path, "r") as f:
        text = f.read()

    # Remove C comments
    text = re.sub(r'//.*', '', text)
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)

    # Find first initializer block after '='
    m = re.search(r'=\s*\{(.*)\}\s*;', text, flags=re.S)
    if not m:
        raise ValueError(f"Could not find initializer in {path}")

    init = m.group(1)

    nums = re.findall(r'-?\d+', init)
    return np.array([int(x) for x in nums], dtype=np.int64)

def load_coe(path, bits):
    with open(path, "r") as f:
        text = f.read()
    data = text.split("memory_initialization_vector=")[1]
    data = data.replace(";", "").replace("\n", "").strip()
    hex_vals = [x.strip() for x in data.split(",") if x.strip()]

    if bits == 8:
        arr = np.array([int(x, 16) for x in hex_vals], dtype=np.uint8).astype(np.int8)
    elif bits == 32:
        arr = np.array([int(x, 16) for x in hex_vals], dtype=np.uint32).astype(np.int32)
    else:
        raise ValueError("bits must be 8 or 32")
    return arr

def compare(name, coe_path, h_path, bits):
    coe = load_coe(coe_path, bits)
    h   = load_h_initializer_only(h_path)

    print(f"{name}: coe={len(coe)} h={len(h)}")

    if len(coe) != len(h):
        print(f"{name}: SIZE MISMATCH")
        return

    diff = np.where(coe.astype(np.int64) != h.astype(np.int64))[0]
    if len(diff) == 0:
        print(f"{name}: PERFECT MATCH")
    else:
        print(f"{name}: {len(diff)} mismatches")
        for i in diff[:10]:
            print(f"  idx {i}: coe={int(coe[i])}  h={int(h[i])}")

compare("W1", "w1_i8.coe", "weights_w1.h", 8)
compare("W2", "w2_i8.coe", "weights_w2.h", 8)
compare("B1", "b1_i32.coe", "weights_b1.h", 32)
compare("B2", "b2_i32.coe", "weights_b2.h", 32)
