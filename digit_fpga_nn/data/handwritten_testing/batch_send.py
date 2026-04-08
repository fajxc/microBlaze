import time
from pathlib import Path

import cv2
import numpy as np
import serial

PORT = "COM6"
BAUD = 9600
INPUT_SIZE = 784
CHUNK_SIZE = 32


def preprocess_mnist_uart_best(image_path: Path) -> np.ndarray:
    gray = cv2.imread(str(image_path), cv2.IMREAD_GRAYSCALE)
    if gray is None:
        raise FileNotFoundError(f"Could not read image: {image_path}")
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    _, mask = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    border = np.concatenate([mask[0, :], mask[-1, :], mask[:, 0], mask[:, -1]])
    if float(np.mean(border)) > 127.0:
        gray = 255 - gray
        mask = 255 - mask
    mask = cv2.medianBlur(mask, 3)
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if contours:
        c = max(contours, key=cv2.contourArea)
        x, y, w, h = cv2.boundingRect(c)
        pad = 2
        x0 = max(0, x - pad)
        y0 = max(0, y - pad)
        x1 = min(gray.shape[1], x + w + pad)
        y1 = min(gray.shape[0], y + h + pad)
        roi = gray[y0:y1, x0:x1]
    else:
        roi = gray
    if roi.size == 0:
        return np.zeros((28, 28), dtype=np.uint8).flatten()
    h, w = roi.shape
    s = max(h, w)
    square = np.zeros((s, s), dtype=np.uint8)
    y_off = (s - h) // 2
    x_off = (s - w) // 2
    square[y_off:y_off + h, x_off:x_off + w] = roi
    resized20 = cv2.resize(square, (20, 20), interpolation=cv2.INTER_AREA)
    out28 = np.zeros((28, 28), dtype=np.uint8)
    out28[4:24, 4:24] = resized20
    m = cv2.moments(out28.astype(np.float32))
    if m["m00"] > 1e-3:
        cx = m["m10"] / m["m00"]
        cy = m["m01"] / m["m00"]
        shift_x = int(round(14.0 - cx))
        shift_y = int(round(14.0 - cy))
        M = np.float32([[1, 0, shift_x], [0, 1, shift_y]])
        out28 = cv2.warpAffine(out28, M, (28, 28), flags=cv2.INTER_LINEAR, borderValue=0)
    return out28.flatten().astype(np.uint8)


def wait_for_ready_silent(ser, timeout=10.0) -> bool:
    start = time.time()
    buf = ""
    while time.time() - start < timeout:
        if ser.in_waiting:
            data = ser.read(ser.in_waiting).decode("utf-8", errors="ignore")
            buf += data
            if "READY" in buf:
                return True
        time.sleep(0.01)
    return False


def send_image(ser, image_path: Path):
    print(f"\n==============================")
    print(f"Testing: {image_path.name}")
    print(f"==============================")

    img_flat = preprocess_mnist_uart_best(image_path)
    image_bytes = img_flat.tobytes()

    if ser.in_waiting:
        ser.read(ser.in_waiting)

    ser.write(b"1")
    ser.flush()
    time.sleep(0.2)

    if not wait_for_ready_silent(ser, timeout=10.0):
        print("FPGA not ready.")
        return None, None

    print("Sending image data...")
    sent = 0
    for i in range(0, INPUT_SIZE, CHUNK_SIZE):
        chunk = image_bytes[i:i + CHUNK_SIZE]
        ser.write(chunk)
        ser.flush()
        sent += len(chunk)
        print(f"Sent {sent}/{INPUT_SIZE} bytes", end="\r", flush=True)
        time.sleep(0.02)
    print("")

    hw_pred = None
    sw_pred = None
    hw_time_us = None
    sw_time_us = None
    start = time.time()
    while time.time() - start < 20.0:
        if ser.in_waiting:
            line = ser.readline().decode("utf-8", errors="ignore").strip()
            if line:
                print(f"FPGA: {line}")
            if line.startswith("HW TIME US:"):
                hw_time_us = int(line.split(":")[1])
            elif line.startswith("SW TIME US:"):
                sw_time_us = int(line.split(":")[1])
            elif line.startswith("HW PRED:"):
                hw_pred = int(line.split(":")[1])
            elif line.startswith("SW PRED:"):
                sw_pred = int(line.split(":")[1])
            if hw_pred is not None and sw_pred is not None:
                return hw_pred, sw_pred, hw_time_us, sw_time_us
        time.sleep(0.01)

    print("No prediction received.")
    return hw_pred, sw_pred, hw_time_us, sw_time_us


def main():
    base_path = Path(".")
    images = [base_path / f"digit{i}.png" for i in range(0, 10)]

    print("Opening serial port...")
    ser = serial.Serial(PORT, BAUD, timeout=0.5)
    time.sleep(2)

    hw_correct = 0
    sw_correct = 0
    total = 0
    hw_times = []
    sw_times = []

    for true_label, img_path in enumerate(images):
        if not img_path.exists():
            print(f"{img_path.name} not found. Skipping.")
            continue

        try:
            hw_pred, sw_pred, hw_us, sw_us = send_image(ser, img_path)
            if hw_pred is not None:
                total += 1
                if hw_pred == true_label: hw_correct += 1
                if sw_pred == true_label: sw_correct += 1
                hw_mark = "✓" if hw_pred == true_label else "✗"
                sw_mark = "✓" if sw_pred == true_label else "✗"
                hw_ms = hw_us / 1000.0 if hw_us is not None else 0
                sw_ms = sw_us / 1000.0 if sw_us is not None else 0
                if hw_us is not None: hw_times.append(hw_ms)
                if sw_us is not None: sw_times.append(sw_ms)
                print(f"HW: {hw_pred} {hw_mark} ({hw_ms:.2f}ms)  "
                      f"SW: {sw_pred} {sw_mark} ({sw_ms:.2f}ms)  "
                      f"True: {true_label}")
            else:
                print("Failed to get prediction")
        except Exception as e:
            print(f"Error testing {img_path.name}: {e}")

        time.sleep(0.3)

    ser.close()

    print(f"\n{'='*50}")
    if total > 0:
        print(f"HW Accuracy: {hw_correct}/{total} = {100*hw_correct/total:.2f}%")
        print(f"SW Accuracy: {sw_correct}/{total} = {100*sw_correct/total:.2f}%")
        if hw_times:
            print(f"HW Avg Time: {sum(hw_times)/len(hw_times):.2f}ms")
        if sw_times:
            print(f"SW Avg Time: {sum(sw_times)/len(sw_times):.2f}ms")
            print(f"Speedup:     {sum(sw_times)/sum(hw_times):.1f}x" if hw_times else "")
    else:
        print("No successful predictions")
    print(f"{'='*50}")


if __name__ == "__main__":
    main()