import sys
import time
import serial
import numpy as np
import cv2

# -----------------------------
# UART protocol (chunked)
# -----------------------------
START = 0xAA
TYPE_DATA = 0x01
ACK_OK = 0x55
ACK_BAD = 0xEE

MAX_PAYLOAD = 240  # safe chunk size


def xor_checksum(data: bytes) -> int:
    c = 0
    for b in data:
        c ^= b
    return c


def make_chunk(offset: int, payload: bytes) -> bytes:
    off_lo = offset & 0xFF
    off_hi = (offset >> 8) & 0xFF
    length = len(payload)

    body = bytes([TYPE_DATA, off_lo, off_hi, length]) + payload
    chk = xor_checksum(body)
    return bytes([START]) + body + bytes([chk])


def send_bytes_to_fpga(data: bytes, port="COM3", baud=9600, retries=3, read_back=True):
    with serial.Serial(port, baudrate=baud, timeout=2.0) as s:
        time.sleep(0.2)
        s.reset_input_buffer()

        offset = 0
        while offset < len(data):
            chunk = data[offset: offset + MAX_PAYLOAD]
            pkt = make_chunk(offset, chunk)

            ok = False
            last_ack = b""
            for _ in range(retries):
                s.write(pkt)
                s.flush()
                ack = s.read(1)
                last_ack = ack
                if ack == bytes([ACK_OK]):
                    ok = True
                    break
                if ack == bytes([ACK_BAD]):
                    continue

            if not ok:
                raise RuntimeError(f"Chunk failed at offset {offset}. Last ACK: {last_ack!r}")

            offset += len(chunk)

        print(f"Sent {len(data)} bytes OK to {port} at {baud} baud")

        if not read_back:
            return

        # Give the FPGA a moment to compute and respond
        time.sleep(0.05)

        # Read whatever comes back. This helps detect if you are receiving ASCII prints.
        resp = s.read(64)

        print("Raw response bytes:", resp)
        if len(resp) > 0:
            print("Response hex:", resp.hex(" "))

        # Best case: FPGA returns a single raw byte 0..9
        # If you got ASCII like b"Pred: 7\r\n", this will not trigger.
        if len(resp) >= 1 and resp[:1] not in (b"P", b"p"):
            # Take the first byte as the predicted digit
            pred = resp[0]
            print("FPGA predicted digit (byte):", pred)
        else:
            # If it looks like ASCII, show it decoded
            try:
                txt = resp.decode("ascii", errors="replace")
                if txt.strip():
                    print("FPGA response looks like text:", repr(txt))
            except Exception:
                pass


# -----------------------------
# Image preprocessing
# Black digit(s) on white background
# -----------------------------
def preprocess_digit_image(
    img_bgr: np.ndarray,
    out_size: int = 28,
    binary: bool = True,
    pad: int = 4,
    debug_prefix: str = "dbg"
) -> np.ndarray:
    if img_bgr is None or img_bgr.size == 0:
        raise ValueError("Empty image input")

    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)

    th = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)[1]

    kernel = np.ones((3, 3), np.uint8)
    th_clean = cv2.morphologyEx(th, cv2.MORPH_OPEN, kernel, iterations=1)

    contours, _ = cv2.findContours(th_clean, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        out = np.zeros((out_size, out_size), dtype=np.uint8)
        cv2.imwrite(f"{debug_prefix}_th.png", th_clean)
        cv2.imwrite(f"{debug_prefix}_out.png", out)
        return out if not binary else (out > 0).astype(np.uint8)

    c = max(contours, key=cv2.contourArea)
    x, y, w, h = cv2.boundingRect(c)

    x0 = max(x - pad, 0)
    y0 = max(y - pad, 0)
    x1 = min(x + w + pad, th_clean.shape[1])
    y1 = min(y + h + pad, th_clean.shape[0])

    roi = th_clean[y0:y1, x0:x1]

    hh, ww = roi.shape[:2]
    side = max(hh, ww)
    square = np.zeros((side, side), dtype=np.uint8)
    yoff = (side - hh) // 2
    xoff = (side - ww) // 2
    square[yoff:yoff + hh, xoff:xoff + ww] = roi

    resized = cv2.resize(square, (out_size, out_size), interpolation=cv2.INTER_AREA)

    if binary:
        out = (resized > 0).astype(np.uint8)
    else:
        out = resized.astype(np.uint8)

    cv2.imwrite(f"{debug_prefix}_gray.png", gray)
    cv2.imwrite(f"{debug_prefix}_th.png", th_clean)
    cv2.imwrite(f"{debug_prefix}_roi.png", roi)
    cv2.imwrite(f"{debug_prefix}_resized.png", resized)
    cv2.imwrite(f"{debug_prefix}_final.png", (out * 255) if binary else out)

    return out


def main():
    if len(sys.argv) < 2:
        print("Usage: python send_digit_to_fpga.py <path_to_image> [--gray]")
        print("Default sends binary 0/1 per pixel. Use --gray to send 0..255 grayscale.")
        sys.exit(1)

    img_path = sys.argv[1]
    send_gray = ("--gray" in sys.argv)

    img = cv2.imread(img_path)
    if img is None:
        raise FileNotFoundError(f"Could not read image: {img_path}")

    digit_28 = preprocess_digit_image(
        img_bgr=img,
        out_size=28,
        binary=not send_gray,
        pad=4,
        debug_prefix="dbg"
    )

    if send_gray:
        payload = digit_28.flatten().astype(np.uint8).tobytes()
        print("Prepared grayscale payload:", len(payload), "bytes")
    else:
        payload = digit_28.flatten().astype(np.uint8).tobytes()
        ones = int(np.sum(digit_28))
        print("Prepared binary payload:", len(payload), "bytes, ones:", ones)

    send_bytes_to_fpga(payload, port="COM3", baud=9600, read_back=True)


if __name__ == "__main__":
    main()
