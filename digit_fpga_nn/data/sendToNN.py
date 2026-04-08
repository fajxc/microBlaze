#!/usr/bin/env python3
"""
MNIST MLP FPGA Tester
Sends images to FPGA via UART and compares HW vs SW inference.
UART: 9600 baud, 8N1
"""

import serial
import numpy as np
import sys
import time
import matplotlib.pyplot as plt

# ============================================================
# Configuration
# ============================================================
PORT = 'COM6'
BAUDRATE = 9600
INPUT_SIZE = 784
CHUNK_SIZE = 32


# ============================================================
# MNIST Loaders
# ============================================================
def load_mnist_images(filepath):
    with open(filepath, 'rb') as f:
        assert int.from_bytes(f.read(4), 'big') == 2051, "Invalid image file"
        n_images = int.from_bytes(f.read(4), 'big')
        int.from_bytes(f.read(4), 'big')  # rows
        int.from_bytes(f.read(4), 'big')  # cols
        return np.frombuffer(f.read(), dtype=np.uint8).reshape(n_images, 28, 28)


def load_mnist_labels(filepath):
    with open(filepath, 'rb') as f:
        assert int.from_bytes(f.read(4), 'big') == 2049, "Invalid label file"
        int.from_bytes(f.read(4), 'big')  # n_labels
        return np.frombuffer(f.read(), dtype=np.uint8)


def find_mnist():
    search_paths = [
        ('t10k-images.idx3-ubyte', 't10k-labels.idx1-ubyte'),
        ('../data/t10k-images.idx3-ubyte', '../data/t10k-labels.idx1-ubyte'),
        ('data/t10k-images.idx3-ubyte', 'data/t10k-labels.idx1-ubyte'),
    ]
    for img_path, lbl_path in search_paths:
        try:
            images = load_mnist_images(img_path)
            labels = load_mnist_labels(lbl_path)
            print(f"Loaded {len(images)} test images from {img_path}")
            return images, labels
        except FileNotFoundError:
            continue
    return None, None


# ============================================================
# Serial Helpers
# ============================================================
def send_command(ser, command):
    ser.write(command.encode())
    ser.flush()
    time.sleep(0.2)


def read_responses(ser, timeout=3.0, verbose=False):
    start = time.time()
    while time.time() - start < timeout:
        if ser.in_waiting > 0:
            try:
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                if line and verbose:
                    print(f"FPGA: {line}")
            except Exception:
                pass
        time.sleep(0.05)


def test_connection(ser):
    print("\n" + "=" * 50)
    print("Testing FPGA Connection...")
    print("=" * 50)

    if ser.in_waiting > 0:
        old = ser.read(ser.in_waiting)
        print(f"Cleared {len(old)} bytes from buffer")

    send_command(ser, '4')
    time.sleep(1.0)

    if ser.in_waiting > 0:
        print("FPGA is responding!")
        read_responses(ser, timeout=2.0)
        return True

    print("No response from FPGA")
    print("\nTroubleshooting:")
    print("1. Check UART cable (TX <-> RX, GND)")
    print("2. Verify FPGA is programmed and running")
    print("3. Confirm COM port is correct")
    print("4. Check baud rate is 9600")
    return False


# ============================================================
# Image Sending
# ============================================================
def send_image_uart(ser, image_flat, mode='1', verbose=False):
    """Send flattened 784-byte image and return predictions/timing for the selected mode."""
    if verbose:
        print("Waiting for FPGA READY signal...")

    start = time.time()
    buf = ""
    while time.time() - start < 10.0:
        if ser.in_waiting > 0:
            try:
                data = ser.read(ser.in_waiting).decode('utf-8', errors='ignore')
                buf += data
                if verbose:
                    for line in data.split('\n'):
                        if line.strip():
                            print(f"FPGA: {line.strip()}")
                if "READY" in buf:
                    break
            except Exception as e:
                if verbose:
                    print(f"Read error: {e}")
        time.sleep(0.05)
    else:
        print("ERROR: FPGA did not send READY signal")
        return None

    if verbose:
        print(f"Sending {INPUT_SIZE} bytes in chunks...")

    t_send_start = time.perf_counter()
    img_bytes = image_flat.tobytes()
    bytes_sent = 0
    for i in range(0, INPUT_SIZE, CHUNK_SIZE):
        chunk = img_bytes[i:i + CHUNK_SIZE]
        ser.write(chunk)
        ser.flush()
        bytes_sent += len(chunk)
        if verbose and i % 128 == 0:
            print(f"Sent {bytes_sent}/{INPUT_SIZE} bytes", end='\r')
        time.sleep(0.05)

    if verbose:
        print(f"\nSent {bytes_sent} bytes total")
        print("Waiting for prediction...")

    hw_pred = None
    sw_pred = None
    hw_time_us = None
    sw_time_us = None

    start = time.time()
    while time.time() - start < 20.0:
        if ser.in_waiting > 0:
            try:
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                if line:
                    if verbose:
                        print(f"FPGA: {line}")
                    if line.startswith("HW TIME US:"):
                        hw_time_us = int(line.split(':')[1])
                    elif line.startswith("SW TIME US:"):
                        sw_time_us = int(line.split(':')[1])
                    elif line.startswith("HW PRED:"):
                        hw_pred = int(line.split(':')[1])
                    elif line.startswith("SW PRED:"):
                        sw_pred = int(line.split(':')[1])
                    elif line.startswith("PRED:"):
                        elapsed_ms = (time.perf_counter() - t_send_start) * 1000.0
                        return {
                            "mode": mode,
                            "hw_pred": hw_pred,
                            "sw_pred": sw_pred,
                            "hw_time_us": hw_time_us,
                            "sw_time_us": sw_time_us,
                            "elapsed_ms": elapsed_ms,
                        }
            except Exception as e:
                if verbose:
                    print(f"Parse error: {e}")
        time.sleep(0.1)

    print("ERROR: Did not receive prediction")
    return None


def run_mode(ser, image_flat, mode, verbose=False):
    send_command(ser, mode)
    time.sleep(0.5)
    return send_image_uart(ser, image_flat, mode=mode, verbose=verbose)


def us_to_ms(value_us):
    if value_us is None:
        return None
    return value_us / 1000.0


def format_dual_run(label, true_label, hw_result, sw_result):
    hw_pred = hw_result["hw_pred"] if hw_result else None
    sw_pred = sw_result["sw_pred"] if sw_result else None

    hw_mark = "OK" if hw_pred == true_label else "X"
    sw_mark = "OK" if sw_pred == true_label else "X"

    line1 = f"{label}  HW: {hw_pred} {hw_mark}  SW: {sw_pred} {sw_mark}  True: {true_label}"

    total_hw_ms = hw_result.get("elapsed_ms") if hw_result else None
    total_sw_ms = sw_result.get("elapsed_ms") if sw_result else None
    hw_compute_ms = us_to_ms(hw_result.get("hw_time_us")) if hw_result else None
    sw_compute_ms = us_to_ms(sw_result.get("sw_time_us")) if sw_result else None

    line2_parts = []
    if total_hw_ms is not None:
        line2_parts.append(f"Total HW: {total_hw_ms:.1f}ms")
    if total_sw_ms is not None:
        line2_parts.append(f"Total SW: {total_sw_ms:.1f}ms")
    if hw_compute_ms is not None:
        line2_parts.append(f"HW compute: {hw_compute_ms:.3f}ms")
    if sw_compute_ms is not None:
        line2_parts.append(f"SW compute: {sw_compute_ms:.3f}ms")

    if line2_parts:
        return line1 + "\n" + "  " + "  |  ".join(line2_parts)
    return line1


def plot_compute_benchmark(hw_compute_ms_series, sw_compute_ms_series):
    if not hw_compute_ms_series or not sw_compute_ms_series:
        return

    run_idx = np.arange(1, len(hw_compute_ms_series) + 1)
    speedup_series = np.array(sw_compute_ms_series) / np.array(hw_compute_ms_series)
    cumulative_hw_ms = np.cumsum(hw_compute_ms_series)
    cumulative_sw_ms = np.cumsum(sw_compute_ms_series)

    fig, axes = plt.subplots(2, 1, figsize=(10, 8), sharex=True)

    axes[0].plot(run_idx, hw_compute_ms_series, marker='o', markersize=3, linewidth=1.5, label='HW compute')
    axes[0].plot(run_idx, sw_compute_ms_series, marker='o', markersize=3, linewidth=1.5, label='SW compute')
    axes[0].axhline(np.mean(speedup_series), color='tab:red', linestyle='--',
                    label=f"Avg speedup = {np.mean(speedup_series):.2f}x")
    axes[0].text(
        0.99,
        0.95,
        f"Avg speedup = {np.mean(speedup_series):.2f}x",
        transform=axes[0].transAxes,
        ha='right',
        va='top',
        color='tab:red'
    )
    axes[0].set_ylabel("Compute Time (ms)")
    axes[0].set_title("Per-Run Compute Timing")
    axes[0].grid(True, alpha=0.3)
    axes[0].legend()

    axes[1].plot(run_idx, cumulative_hw_ms, color='tab:blue', marker='o', markersize=3, linewidth=1.5, label='HW cumulative')
    axes[1].plot(run_idx, cumulative_sw_ms, color='tab:orange', marker='o', markersize=3, linewidth=1.5, label='SW cumulative')
    axes[1].set_xlabel("Run")
    axes[1].set_ylabel("Cumulative Compute Time (ms)")
    axes[1].set_title("Cumulative Compute Time")
    axes[1].grid(True, alpha=0.3)
    axes[1].legend()

    fig.tight_layout()
    plt.show()


# ============================================================
# Interactive Mode
# ============================================================
def interactive_mode(ser, images, labels):
    print("\n" + "=" * 50)
    print("Interactive Mode")
    print("=" * 50)
    print("  t <index> - Test specific image")
    print("  r <n>     - Test n random images with accuracy")
    print("  z         - Send all-zero image")
    print("  p <i> [v] - Send image with x[i]=v, rest 0")
    print("  c         - Test connection")
    print("  q         - Quit")
    print("=" * 50)

    while True:
        cmd = input("\nEnter command: ").strip().lower()

        if cmd.startswith('q'):
            break

        elif cmd.startswith('c'):
            test_connection(ser)

        elif cmd.startswith('t'):
            try:
                parts = cmd.split()
                if len(parts) < 2:
                    print("Usage: t <index>")
                    continue
                idx = int(parts[1])
                if idx < 0 or idx >= len(images):
                    print(f"Index out of range (0-{len(images)-1})")
                    continue

                print(f"\n{'=' * 50}")
                print(f"Testing image {idx} | True label: {labels[idx]}")
                print(f"{'=' * 50}")

                image_flat = images[idx].flatten()
                hw_result = run_mode(ser, image_flat, '2', verbose=False)
                sw_result = run_mode(ser, image_flat, '3', verbose=False)

                if hw_result is not None and sw_result is not None:
                    print(format_dual_run("Result:", labels[idx], hw_result, sw_result))
                else:
                    print("Failed to get prediction")

                time.sleep(0.5)
                read_responses(ser, timeout=1.0, verbose=False)

            except ValueError:
                print("Invalid index")
            except Exception as e:
                print(f"Error: {e}")

        elif cmd.startswith('r'):
            try:
                parts = cmd.split()
                n = int(parts[1]) if len(parts) > 1 else 5

                print(f"\n{'=' * 50}")
                print(f"Testing {n} random images")
                print(f"{'=' * 50}")

                indices = np.random.choice(len(images), size=min(n, len(images)), replace=False)
                hw_correct = sw_correct = total = 0
                total_hw_ms = 0.0
                total_sw_ms = 0.0
                total_hw_compute_ms = 0.0
                total_sw_compute_ms = 0.0
                hw_compute_ms_series = []
                sw_compute_ms_series = []
                hw_total_count = 0
                sw_total_count = 0
                hw_compute_count = 0
                sw_compute_count = 0

                for i, idx in enumerate(indices):
                    print(f"\n--- Image {i+1}/{n} (index {idx}) | True: {labels[idx]} ---")

                    image_flat = images[idx].flatten()
                    hw_result = run_mode(ser, image_flat, '2', verbose=False)
                    sw_result = run_mode(ser, image_flat, '3', verbose=False)

                    if hw_result is not None and sw_result is not None:
                        total += 1

                        hw_pred = hw_result["hw_pred"]
                        sw_pred = sw_result["sw_pred"]
                        if hw_pred == labels[idx]:
                            hw_correct += 1
                        if sw_pred == labels[idx]:
                            sw_correct += 1

                        if hw_result.get("elapsed_ms") is not None:
                            total_hw_ms += hw_result["elapsed_ms"]
                            hw_total_count += 1
                        if sw_result.get("elapsed_ms") is not None:
                            total_sw_ms += sw_result["elapsed_ms"]
                            sw_total_count += 1

                        hw_compute_ms = us_to_ms(hw_result.get("hw_time_us"))
                        sw_compute_ms = us_to_ms(sw_result.get("sw_time_us"))
                        if hw_compute_ms is not None:
                            total_hw_compute_ms += hw_compute_ms
                            hw_compute_count += 1
                            hw_compute_ms_series.append(hw_compute_ms)
                        if sw_compute_ms is not None:
                            total_sw_compute_ms += sw_compute_ms
                            sw_compute_count += 1
                            sw_compute_ms_series.append(sw_compute_ms)

                        print(format_dual_run("Result:", labels[idx], hw_result, sw_result))
                    else:
                        print("Failed to get prediction")

                    time.sleep(0.5)

                print(f"\n{'=' * 50}")
                if total > 0:
                    print(f"HW Accuracy: {hw_correct}/{total} = {100 * hw_correct / total:.2f}%")
                    print(f"SW Accuracy: {sw_correct}/{total} = {100 * sw_correct / total:.2f}%")
                    if hw_total_count > 0:
                        print(f"Avg Total HW: {total_hw_ms / hw_total_count:.1f}ms")
                    if sw_total_count > 0:
                        print(f"Avg Total SW: {total_sw_ms / sw_total_count:.1f}ms")
                    if hw_compute_count > 0:
                        print(f"Avg HW compute: {total_hw_compute_ms / hw_compute_count:.3f}ms")
                    if sw_compute_count > 0:
                        print(f"Avg SW compute: {total_sw_compute_ms / sw_compute_count:.3f}ms")
                else:
                    print("No successful predictions")
                print(f"{'=' * 50}")

                if hw_compute_count > 0 and sw_compute_count > 0 and len(hw_compute_ms_series) == len(sw_compute_ms_series):
                    plot_compute_benchmark(hw_compute_ms_series, sw_compute_ms_series)

            except ValueError:
                print("Invalid number")
            except Exception as e:
                print(f"Error: {e}")

        elif cmd.startswith('z'):
            print("\nSending all-zero image...")
            image_flat = np.zeros(INPUT_SIZE, dtype=np.uint8)
            hw_result = run_mode(ser, image_flat, '2', verbose=False)
            sw_result = run_mode(ser, image_flat, '3', verbose=False)
            if hw_result is not None and sw_result is not None:
                print(format_dual_run("Result:", "n/a", hw_result, sw_result))
            else:
                print("Failed to get prediction")
            time.sleep(0.5)
            read_responses(ser, timeout=1.0, verbose=False)

        elif cmd.startswith('p'):
            try:
                parts = cmd.split()
                if len(parts) < 2:
                    print("Usage: p <pixel_index> [value]")
                    continue
                idx = int(parts[1])
                val = max(0, min(255, int(parts[2]) if len(parts) > 2 else 1))
                if idx < 0 or idx >= INPUT_SIZE:
                    print(f"Pixel index must be 0..{INPUT_SIZE-1}")
                    continue
                print(f"\nSending image with x[{idx}]={val}, rest 0...")
                img = np.zeros(INPUT_SIZE, dtype=np.uint8)
                img[idx] = val
                hw_result = run_mode(ser, img, '2', verbose=False)
                sw_result = run_mode(ser, img, '3', verbose=False)
                if hw_result is not None and sw_result is not None:
                    print(format_dual_run("Result:", "n/a", hw_result, sw_result))
                else:
                    print("Failed to get prediction")
                time.sleep(0.5)
                read_responses(ser, timeout=1.0, verbose=False)
            except ValueError:
                print("Usage: p <pixel_index> [value]  (index 0..783, value 0..255)")

        else:
            print("Unknown command")


# ============================================================
# CLI Utilities (no MNIST needed)
# ============================================================
def open_serial(port, baudrate):
    try:
        ser = serial.Serial(
            port,
            baudrate,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0.5,
            write_timeout=2.0,
        )
        time.sleep(2)
        return ser
    except serial.SerialException as e:
        print(f"Error opening serial port: {e}")
        return None


def send_zeros_only(port, baudrate=9600):
    ser = open_serial(port, baudrate)
    if not ser:
        return
    image_flat = np.zeros(INPUT_SIZE, dtype=np.uint8)
    hw_result = run_mode(ser, image_flat, '2', verbose=False)
    sw_result = run_mode(ser, image_flat, '3', verbose=False)
    ser.close()
    if hw_result and sw_result:
        print(format_dual_run("Result:", "n/a", hw_result, sw_result))


def send_single_pixel_only(port, pixel_index, value=1, baudrate=9600):
    if not (0 <= pixel_index < INPUT_SIZE):
        print(f"Pixel index must be 0..{INPUT_SIZE-1}")
        return
    value = max(0, min(255, int(value)))
    ser = open_serial(port, baudrate)
    if not ser:
        return
    img = np.zeros(INPUT_SIZE, dtype=np.uint8)
    img[pixel_index] = value
    hw_result = run_mode(ser, img, '2', verbose=False)
    sw_result = run_mode(ser, img, '3', verbose=False)
    ser.close()
    if hw_result and sw_result:
        print(format_dual_run("Result:", "n/a", hw_result, sw_result))


# ============================================================
# Main
# ============================================================
def main():
    port = PORT
    for a in sys.argv[1:]:
        if a.upper().startswith('COM') or a.startswith('/dev/'):
            port = a
            break

    args = [a.lower() for a in sys.argv[1:]]

    if '--zeros' in args or '-z' in args:
        send_zeros_only(port, BAUDRATE)
        return

    if '--pixel' in args:
        pixel_idx, pixel_val = 0, 1
        for j, a in enumerate(sys.argv[1:], start=1):
            if a.lower() == '--pixel' and j < len(sys.argv) - 1:
                try:
                    pixel_idx = int(sys.argv[j + 1])
                    if j + 2 < len(sys.argv):
                        pixel_val = int(sys.argv[j + 2])
                except (ValueError, IndexError):
                    pass
                break
        send_single_pixel_only(port, pixel_idx, pixel_val, BAUDRATE)
        return

    print("=" * 60)
    print(" MNIST MLP FPGA Tester  |  UART 9600 baud 8N1")
    print("=" * 60)
    print(f"\nOpening serial port {port} at {BAUDRATE} baud...")

    try:
        ser = serial.Serial(
            port,
            BAUDRATE,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0.5,
            write_timeout=2.0,
        )
        print("Serial port opened")
        time.sleep(2)
        if ser.in_waiting > 0:
            print(ser.read(ser.in_waiting).decode('utf-8', errors='ignore'))
    except serial.SerialException as e:
        print(f"Could not open port: {e}")
        print("- Windows: check Device Manager for correct COM port")
        print("- Linux: try /dev/ttyUSB0 or /dev/ttyACM0")
        return

    print("\nLoading MNIST test data...")
    images, labels = find_mnist()
    if images is None:
        print("MNIST data not found. Place idx files in current directory.")
        ser.close()
        return

    try:
        if not test_connection(ser):
            if input("\nFPGA not responding. Continue anyway? (y/n): ").lower() != 'y':
                ser.close()
                return
        interactive_mode(ser, images, labels)
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
    finally:
        ser.close()
        print("Serial port closed")


if __name__ == "__main__":
    main()
