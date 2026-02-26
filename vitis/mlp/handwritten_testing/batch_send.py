import time
from pathlib import Path

import cv2
import numpy as np
import serial

PORT = "COM3"
BAUD = 9600
INPUT_SIZE = 784
CHUNK_SIZE = 32


def preprocess_mnist_uart_best(image_path: Path) -> np.ndarray:
    gray = cv2.imread(str(image_path), cv2.IMREAD_GRAYSCALE)
    if gray is None:
        raise FileNotFoundError(f"Could not read image: {image_path}")
    # Mild denoise (helps with camera / rough PNGs)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    # Otsu mask ONLY for locating digit (not final pixel values)
    _, mask = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    # Invert decision based on border of the mask.
    # We want: background dark (0), digit bright (255-ish), like MNIST.
    border = np.concatenate([mask[0, :], mask[-1, :], mask[:, 0], mask[:, -1]])
    if float(np.mean(border)) > 127.0:
        gray = 255 - gray
        mask = 255 - mask
    # Clean mask a bit so contour detection is stable
    mask = cv2.medianBlur(mask, 3)
    # Find largest connected component and crop (using mask),
    # but crop the GRAYSCALE image (preserve intensities).
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if contours:
        c = max(contours, key=cv2.contourArea)
        x, y, w, h = cv2.boundingRect(c)
        # Small padding around bbox to avoid cutting strokes
        pad = 2
        x0 = max(0, x - pad)
        y0 = max(0, y - pad)
        x1 = min(gray.shape[1], x + w + pad)
        y1 = min(gray.shape[0], y + h + pad)
        roi = gray[y0:y1, x0:x1]
    else:
        roi = gray
    if roi.size == 0:
        out28 = np.zeros((28, 28), dtype=np.uint8)
        return out28.flatten()
    # Pad ROI to square (keeps aspect ratio when resizing)
    h, w = roi.shape
    s = max(h, w)
    square = np.zeros((s, s), dtype=np.uint8)
    y_off = (s - h) // 2
    x_off = (s - w) // 2
    square[y_off:y_off + h, x_off:x_off + w] = roi
    # Resize so digit fits in 20x20, then place into 28x28
    resized20 = cv2.resize(square, (20, 20), interpolation=cv2.INTER_AREA)
    out28 = np.zeros((28, 28), dtype=np.uint8)
    out28[4:24, 4:24] = resized20
    # Center-of-mass shift (helps MLP a lot)
    m = cv2.moments(out28.astype(np.float32))
    if m["m00"] > 1e-3:
        cx = m["m10"] / m["m00"]
        cy = m["m01"] / m["m00"]
        shift_x = int(round(14.0 - cx))
        shift_y = int(round(14.0 - cy))
        M = np.float32([[1, 0, shift_x], [0, 1, shift_y]])
        out28 = cv2.warpAffine(
            out28, M, (28, 28),
            flags=cv2.INTER_LINEAR,
            borderValue=0
        )
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

    # Clear buffer
    if ser.in_waiting:
        ser.read(ser.in_waiting)

    # Send start signal
    ser.write(b"1")
    ser.flush()
    time.sleep(0.2)

    if not wait_for_ready_silent(ser, timeout=10.0):
        print("FPGA not ready.")
        return

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

    pred_line = None
    logits_line = None

    start = time.time()
    while time.time() - start < 20.0:
        if ser.in_waiting:
            line = ser.readline().decode("utf-8", errors="ignore").strip()

            if line.startswith("Prediction:"):
                pred_line = line
            elif line.startswith("Logits:"):
                logits_line = line

            if pred_line and logits_line:
                print(pred_line)
                print(logits_line)
                return

        time.sleep(0.01)

    print("No prediction received.")


def main():
    base_path = Path(".")
    images = [base_path / f"digit{i}.png" for i in range(0, 10)]

    print("Opening serial port...")
    ser = serial.Serial(PORT, BAUD, timeout=0.5)
    time.sleep(2)

    for img_path in images:
        if not img_path.exists():
            print(f"{img_path.name} not found. Skipping.")
            continue

        try:
            send_image(ser, img_path)
        except Exception as e:
            print(f"Error testing {img_path.name}: {e}")

    ser.close()
    print("\nAll tests complete.")


if __name__ == "__main__":
    main()
