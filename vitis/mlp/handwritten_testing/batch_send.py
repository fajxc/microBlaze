import time
from pathlib import Path

import cv2
import numpy as np
import serial

PORT = "COM3"
BAUD = 9600
INPUT_SIZE = 784
CHUNK_SIZE = 32


def pad_to_square(img: np.ndarray) -> np.ndarray:
    h, w = img.shape[:2]
    s = max(h, w)
    out = np.zeros((s, s), dtype=img.dtype)
    y0 = (s - h) // 2
    x0 = (s - w) // 2
    out[y0:y0 + h, x0:x0 + w] = img
    return out


def preprocess_mnist_style(image_path: Path) -> np.ndarray:
    """
    IMPROVED preprocessing that better matches MNIST characteristics
    
    Key improvements:
    1. Morphological dilation to thicken thin strokes
    2. Intensity normalization for better contrast
    """
    img_bgr = cv2.imread(str(image_path), cv2.IMREAD_COLOR)
    if img_bgr is None:
        raise FileNotFoundError(f"Could not read image: {image_path}")

    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)

    _, bw = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    border = np.concatenate([bw[0, :], bw[-1, :], bw[:, 0], bw[:, -1]])
    border_mean = float(np.mean(border))

    proc = bw.copy()
    if border_mean > 127:
        proc = 255 - proc

    proc = cv2.medianBlur(proc, 3)

    # IMPROVEMENT 1: Thicken strokes slightly to match MNIST
    # Adjust iterations (1-2) based on your stroke thickness
    kernel = np.ones((2, 2), np.uint8)
    proc = cv2.dilate(proc, kernel, iterations=1)

    contours, _ = cv2.findContours(proc, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    if contours:
        c = max(contours, key=cv2.contourArea)
        x, y, w, h = cv2.boundingRect(c)
        roi = proc[y:y + h, x:x + w]
    else:
        roi = proc

    padded = pad_to_square(roi)

    resized20 = cv2.resize(padded, (20, 20), interpolation=cv2.INTER_AREA)
    
    # IMPROVEMENT 2: Boost intensity to use full range
    # This helps match MNIST's high-contrast digits
    if resized20.max() > 0:
        resized20 = (resized20.astype(np.float32) / resized20.max() * 255).astype(np.uint8)
    
    out28 = np.zeros((28, 28), dtype=np.uint8)
    out28[4:24, 4:24] = resized20

    return out28


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

    img_flat = preprocess_mnist_style(image_path)
    
    # Save preprocessed image for debugging
    debug_path = image_path.parent / f"preprocessed_{image_path.name}"
    cv2.imwrite(str(debug_path), img_flat.reshape(28, 28))
    
    # Print stats
    nonzero = np.count_nonzero(img_flat)
    avg_intensity = img_flat[img_flat > 0].mean() if nonzero > 0 else 0
    print(f"Preprocessed: {nonzero}/784 pixels, avg intensity: {avg_intensity:.1f}")
    
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

    results = []
    for img_path in images:
        if not img_path.exists():
            print(f"{img_path.name} not found. Skipping.")
            continue

        try:
            send_image(ser, img_path)
            # Could track results here for final summary
        except Exception as e:
            print(f"Error testing {img_path.name}: {e}")

    ser.close()

if __name__ == "__main__":
    main()
