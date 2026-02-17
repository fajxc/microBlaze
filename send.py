import serial
import time

PORT = "COM6"
BAUD = 9600   # make sure this matches your BSP

# Load raw 784-byte image
data = bytearray(open("img_28x28.bin", "rb").read())
assert len(data) == 784

print("BEFORE INVERT:")
print("len", len(data),
      "min", min(data),
      "max", max(data),
      "avg", sum(data)/len(data))

# Invert for MNIST polarity (white digit on black background)
for i in range(784):
    data[i] = 255 - data[i]

print("\nAFTER INVERT:")
print("len", len(data),
      "min", min(data),
      "max", max(data),
      "avg", sum(data)/len(data))

# Open serial
ser = serial.Serial(PORT, BAUD, timeout=0.2)

time.sleep(0.5)

print("\nSending 784 bytes (inverted)...")
ser.write(data)

print("Reading for 5 seconds...")
end = time.time() + 5.0
buf = bytearray()

while time.time() < end:
    chunk = ser.read(256)
    if chunk:
        buf.extend(chunk)

ser.close()

print("\n--- RAW BYTES (hex) ---")
print(buf.hex())

print("\n--- DECODED (best effort) ---")
print(buf.decode(errors="replace"))

print("\n--- STATS ---")
print("Bytes received:", len(buf))
