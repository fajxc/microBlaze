# Edge Accel — FPGA Neural Network Accelerator

An FPGA-based machine learning inference accelerator that recognizes handwritten digits in real time using a live camera feed. Built on a Digilent Basys 3 (Artix-7), the system offloads a two-layer MLP from a MicroBlaze-V soft-core processor into a custom RTL datapath, achieving a **~24× inference speedup** (0.763 ms vs. 18 ms software-only).

---

## What It Does

A handwritten digit is held up to a camera connected to the FPGA. The image is captured, preprocessed, and classified entirely on-board by a hardware-accelerated neural network. The predicted digit is displayed on a connected monitor in real time. A host-side UART path is also supported for testing and validation with MNIST dataset images.

---

## Architecture

```
Camera
  └── Camera PMOD PCB (custom)
        └── FPGA — frame capture → grayscale → resize → normalize → 784-pixel buffer
              └── MicroBlaze-V (AXI4-Lite control)
                    └── Custom NN IP
                          ├── Input Loader       — buffers 784-pixel input vector
                          ├── Control Unit (FSM) — sequences layer execution
                          ├── Layer 1            — MAC array → accumulator → bias → ReLU (784→32)
                          ├── Layer 2            — MAC array → accumulator → bias (32→10)
                          ├── BRAM               — stores quantized weights and biases
                          └── Output Logic       — argmax → prediction register → display
```

**Also supported:**
- **UART path** — host preprocesses and sends image over serial for testing and validation

---

## Neural Network

- **Architecture:** 784 → 32 → 10 fully connected MLP
- **Training:** PyTorch, MNIST dataset (20,000 images)
- **Weights:** quantized to 8-bit signed integers for hardware efficiency
- **Biases:** stored as 32-bit integers to prevent accumulation overflow
- **Export:** `.coe` memory initialization files loaded into BRAM at configuration time

---

## Performance

| Mode | Latency | Notes |
|---|---|---|
| Hardware (Custom NN IP) | ~0.763 ms | ~3 cycles/MAC, deterministic FSM |
| Software (MicroBlaze-V) | ~18 ms | General-purpose pipeline overhead |
| **Speedup** | **~24×** | |

**Timing (100 MHz):** WNS = 0.433 ns, WHS = 0.009 ns — all constraints met, zero failing endpoints across 25,489 paths.

---

## Hardware

| | |
|---|---|
| Board | Digilent Basys 3 (Artix-7 XC7A35T) |
| Processor | MicroBlaze-V soft-core |
| Interconnect | AXI4-Lite |
| Tools | Vivado / Vitis 2025.2 |
| Clock | 100 MHz |

---

## Custom PCBs

Two PCBs designed in KiCad and manufactured by JLCPCB — both worked on the first fabrication pass.

| Board | Purpose | Layers |
|---|---|---|
| Camera PMOD | Camera-to-FPGA signal breakout (PCLK, VSYNC, HREF, D0–D7, SDA/SCL) | 2-layer |
| HyperRAM PMOD | External memory expansion for larger model support | 4-layer |

> The current 784→32→10 model fits within the Basys 3's on-chip BRAM (50/50 tiles). The HyperRAM board is designed and ready for use when scaling to larger architectures.

---

## Getting Started

### Prerequisites

```
Python 3.x — torch, torchvision, numpy, Pillow, pyserial, opencv-python
Vivado 2025.2 with Vitis
Digilent Basys 3 + USB-UART cable
Camera module + Camera PMOD PCB
```

### 1. Train and Export Model Parameters

```bash
cd python
python train.py       # trains model, saves mlp32.pth
python quantize.py    # exports weights.h and .coe files for FPGA
```

### 2. Build and Program

Open the Vivado project under `vivado/project/`, synthesize and implement, generate the bitstream, and program the Basys 3 via Hardware Manager.

### 3. Run Inference

Connect the camera PMOD PCB to the Basys 3 PMOD headers and power on. The system will begin capturing and classifying in real time, with the predicted digit shown on the display.

For UART-based testing:
```bash
cd python
python send_uart.py --port COM3 --image digit.png
```

---

## Repository Structure

```
├── hardware/          # RTL source — nn_core, control_unit, mac_array, testbench
├── software/          # MicroBlaze-V embedded C application
├── python/            # Training, quantization, preprocessing, UART scripts
├── vivado/            # Vivado project and block design
└── pcb/               # KiCad files for Camera PMOD and HyperRAM PMOD
```

---

## Resource Utilization (Post-Implementation)

| Resource | Used | Available | % |
|---|---|---|---|
| LUT | 6,588 | 20,800 | 31.67% |
| FF | 10,086 | 41,600 | 24.25% |
| BRAM | 50 | 50 | 100% |
| DSP | 4 | 90 | 4.44% |

---

## Future Work

- Expand to full handwritten equation recognition (digits + operators → computed result)
- Accelerator pipelining and increased MAC parallelism
- CNN support for improved spatial feature extraction
