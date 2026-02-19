#!/usr/bin/env python3
"""
Send MNIST images to FPGA via UART for inference

This script reads MNIST test images and sends them to the FPGA
MicroBlaze RISC-V system via UART for classification.

UART Configuration: 9600 baud, 8N1
"""

import serial
import numpy as np
import sys
import time
from pathlib import Path

def load_mnist_images(filepath):
    """Load MNIST images from IDX file format"""
    with open(filepath, 'rb') as f:
        magic = int.from_bytes(f.read(4), 'big')
        assert magic == 2051, f"Invalid magic number: {magic}"
        
        n_images = int.from_bytes(f.read(4), 'big')
        n_rows = int.from_bytes(f.read(4), 'big')
        n_cols = int.from_bytes(f.read(4), 'big')
        
        data = np.frombuffer(f.read(), dtype=np.uint8)
        images = data.reshape(n_images, n_rows, n_cols)
        
    return images

def load_mnist_labels(filepath):
    """Load MNIST labels from IDX file format"""
    with open(filepath, 'rb') as f:
        magic = int.from_bytes(f.read(4), 'big')
        assert magic == 2049, f"Invalid magic number: {magic}"
        
        n_labels = int.from_bytes(f.read(4), 'big')
        labels = np.frombuffer(f.read(), dtype=np.uint8)
        
    return labels

def send_image_uart(ser, image_flat, verbose=True):
    """
    Send a 784-byte flattened image to FPGA via UART
    
    Args:
        ser: Serial port object
        image_flat: Flattened 784-byte numpy array
        verbose: Print debug messages
    
    Returns:
        Prediction (int) or None if failed
    """
    # Wait for READY signal
    if verbose:
        print("Waiting for FPGA READY signal...")
    
    ready = False
    timeout = 10  # seconds
    start_time = time.time()
    all_data = ""
    
    while not ready and (time.time() - start_time) < timeout:
        if ser.in_waiting > 0:
            try:
                # Read all available data
                data = ser.read(ser.in_waiting).decode('utf-8', errors='ignore')
                all_data += data
                
                if verbose:
                    # Print each line as we get it
                    for line in data.split('\n'):
                        line = line.strip()
                        if line:
                            print(f"FPGA: {line}")
                
                # Check if READY is in the accumulated data
                if "READY" in all_data:
                    ready = True
                    break
            except Exception as e:
                if verbose:
                    print(f"Read error: {e}")
        time.sleep(0.05)  # Shorter sleep for faster response
    
    if not ready:
        print("ERROR: FPGA did not send READY signal")
        print(f"Received data: {all_data}")
        return None
    
    # Send image data in chunks to avoid buffer overflow
    if verbose:
        print(f"Sending image data ({INPUT_SIZE} bytes) in chunks...")
    
    chunk_size = 32  # Send 32 bytes at a time
    bytes_sent = 0
    img_bytes = image_flat.tobytes()
    
    for i in range(0, INPUT_SIZE, chunk_size):
        chunk = img_bytes[i:i+chunk_size]
        ser.write(chunk)
        ser.flush()
        bytes_sent += len(chunk)
        time.sleep(0.05)  # 50ms delay between chunks to prevent buffer overflow
        if verbose and i % 128 == 0:
            print(f"Sent {bytes_sent}/{INPUT_SIZE} bytes", end='\r')
    
    if verbose:
        print(f"\nSent {bytes_sent} bytes total")
    
    # Wait for prediction (longer timeout for 9600 baud)
    if verbose:
        print("Waiting for prediction...")
    
    timeout = 20  # seconds
    start_time = time.time()
    prediction = None
    
    while (time.time() - start_time) < timeout:
        if ser.in_waiting > 0:
            try:
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                if line:
                    if verbose:
                        print(f"FPGA: {line}")
                    
                    if line.startswith("PRED:"):
                        pred_str = line.split(':')[1]
                        prediction = int(pred_str)
                        return prediction
                    elif line.startswith("HW:") or line.startswith("SW"):
                        print(f"DEBUG: {line}")
            except Exception as e:
                if verbose:
                    print(f"Parse error: {e}")
        time.sleep(0.1)
    
    print("ERROR: Did not receive prediction")
    return None

def send_command(ser, command):
    """Send a single character command to FPGA"""
    ser.write(command.encode())
    ser.flush()
    time.sleep(0.2)

def read_responses(ser, timeout=3.0, verbose=True):
    """Read and print responses from FPGA"""
    start_time = time.time()
    while (time.time() - start_time) < timeout:
        if ser.in_waiting > 0:
            try:
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                if line and verbose:
                    print(f"FPGA: {line}")
            except:
                pass
        time.sleep(0.05)

def test_connection(ser):
    """Test if FPGA is responding"""
    print("\n" + "="*50)
    print("Testing FPGA Connection...")
    print("="*50)
    
    # Clear buffer
    if ser.in_waiting > 0:
        old_data = ser.read(ser.in_waiting)
        print(f"Cleared {len(old_data)} bytes from buffer")
    
    # Send menu command
    print("Sending command '4' (show menu)...")
    send_command(ser, '4')
    
    # Wait for response
    time.sleep(1.0)
    
    if ser.in_waiting > 0:
        print("✓ FPGA is responding!")
        read_responses(ser, timeout=2.0)
        return True
    else:
        print("✗ No response from FPGA")
        print("\nTroubleshooting:")
        print("1. Check UART cable is connected (TX ↔ RX, GND)")
        print("2. Verify FPGA is programmed and running")
        print("3. Confirm COM port is correct")
        print("4. Check baud rate is 9600")
        return False

def interactive_mode(ser, images, labels):
    """Interactive mode for testing"""
    print("\n" + "="*50)
    print("Interactive Mode")
    print("="*50)
    print("Commands:")
    print("  t <index> - Test image at index")
    print("  r <n>     - Test n random images")
    print("  z         - Send all-zero image (784 bytes of 0)")
    print("  p <i> [v] - Send image with x[i]=v, rest 0 (v=1 if omitted; e.g. p 0 255)")
    print("  s         - Trigger FPGA self-test")
    print("  i         - Display FPGA network info")
    print("  c         - Test connection")
    print("  q         - Quit")
    print("="*50)
    
    while True:
        cmd = input("\nEnter command: ").strip().lower()
        
        if cmd.startswith('q'):
            break
        
        elif cmd.startswith('c'):
            # Test connection
            test_connection(ser)
            
        elif cmd.startswith('t'):
            # Test specific image
            try:
                parts = cmd.split()
                if len(parts) < 2:
                    print("Usage: t <index>")
                    continue
                    
                idx = int(parts[1])
                if idx < 0 or idx >= len(images):
                    print(f"Index out of range (0-{len(images)-1})")
                    continue
                
                print(f"\n{'='*50}")
                print(f"Testing image {idx}")
                print(f"True label: {labels[idx]}")
                print(f"{'='*50}")
                
                # Send command to receive image
                send_command(ser, '1')
                time.sleep(0.5)
                
                # Send image
                image_flat = images[idx].flatten()
                prediction = send_image_uart(ser, image_flat)
                
                if prediction is not None:
                    correct = "✓ CORRECT" if prediction == labels[idx] else "✗ WRONG"
                    print(f"\nResult: Pred={prediction}, True={labels[idx]} {correct}")
                else:
                    print("\nFailed to get prediction")
                
                # Read any remaining responses
                time.sleep(0.5)
                read_responses(ser, timeout=1.0, verbose=False)
                
            except ValueError:
                print("Invalid index")
            except Exception as e:
                print(f"Error: {e}")
                
        elif cmd.startswith('r'):
            # Test random images
            try:
                parts = cmd.split()
                n = int(parts[1]) if len(parts) > 1 else 5
                
                print(f"\n{'='*50}")
                print(f"Testing {n} random images")
                print(f"{'='*50}")
                
                indices = np.random.choice(len(images), size=min(n, len(images)), replace=False)
                
                correct = 0
                total = 0
                
                for i, idx in enumerate(indices):
                    print(f"\n--- Image {i+1}/{n} (index {idx}) ---")
                    print(f"True label: {labels[idx]}")
                    
                    # Send command
                    send_command(ser, '1')
                    time.sleep(0.5)
                    
                    # Send image
                    image_flat = images[idx].flatten()
                    prediction = send_image_uart(ser, image_flat, verbose=True)
                    
                    if prediction is not None:
                        total += 1
                        if prediction == labels[idx]:
                            correct += 1
                            print(f"✓ Correct: {prediction}")
                        else:
                            print(f"✗ Wrong: predicted {prediction}, true {labels[idx]}")
                    else:
                        print("✗ Failed to get prediction")
                    
                    time.sleep(0.5)
                
                print(f"\n{'='*50}")
                if total > 0:
                    accuracy = 100.0 * correct / total
                    print(f"Accuracy: {correct}/{total} = {accuracy:.2f}%")
                else:
                    print("No successful predictions")
                print(f"{'='*50}")
                    
            except ValueError:
                print("Invalid number")
            except Exception as e:
                print(f"Error: {e}")
        
        elif cmd.startswith('z'):
            # Send all-zero image
            print("\nSending all-zero image (784 bytes)...")
            send_command(ser, '1')
            time.sleep(0.5)
            zeros = np.zeros(INPUT_SIZE, dtype=np.uint8)
            prediction = send_image_uart(ser, zeros)
            if prediction is not None:
                print(f"\nResult: Pred={prediction}")
            else:
                print("\nFailed to get prediction")
            time.sleep(0.5)
            read_responses(ser, timeout=1.0, verbose=False)
        
        elif cmd.startswith('p'):
            # Send single-pixel image: x[i]=value, rest 0 (value 0-255, default 1)
            try:
                parts = cmd.split()
                if len(parts) < 2:
                    print("Usage: p <pixel_index> [value]  (e.g. p 0 255 or p 0 for x[0]=1)")
                    continue
                idx = int(parts[1])
                val = int(parts[2]) if len(parts) > 2 else 1
                val = max(0, min(255, val))
                if idx < 0 or idx >= INPUT_SIZE:
                    print(f"Pixel index must be 0..{INPUT_SIZE-1}")
                    continue
                print(f"\nSending image with x[{idx}]={val}, rest 0...")
                send_command(ser, '1')
                time.sleep(0.5)
                img = np.zeros(INPUT_SIZE, dtype=np.uint8)
                img[idx] = val
                prediction = send_image_uart(ser, img)
                if prediction is not None:
                    print(f"\nResult: Pred={prediction}")
                else:
                    print("\nFailed to get prediction")
                time.sleep(0.5)
                read_responses(ser, timeout=1.0, verbose=False)
            except ValueError:
                print("Usage: p <pixel_index> [value]  (index 0..783, value 0..255)")
                
        elif cmd.startswith('s'):
            # Self-test
            print("\nTriggering FPGA self-test...")
            send_command(ser, '2')
            read_responses(ser, timeout=5.0)
            
        elif cmd.startswith('i'):
            # Network info
            print("\nRequesting network info...")
            send_command(ser, '3')
            read_responses(ser, timeout=3.0)
            
        else:
            print("Unknown command")

# Constants
INPUT_SIZE = 784

def send_zeros_only(port, baudrate=9600):
    """Open port, send one all-zero image, print prediction, exit. No MNIST needed."""
    print("="*60)
    print(" Send all-zero image to FPGA")
    print("="*60)
    print(f"\nOpening serial port {port} at {baudrate} baud...")
    try:
        ser = serial.Serial(
            port=port,
            baudrate=baudrate,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0.5,
            write_timeout=2.0
        )
    except serial.SerialException as e:
        print(f"Error opening serial port: {e}")
        return
    time.sleep(2)
    print("Sending 784 zero bytes...")
    send_command(ser, '1')
    time.sleep(0.5)
    zeros = np.zeros(INPUT_SIZE, dtype=np.uint8)
    pred = send_image_uart(ser, zeros)
    ser.close()
    if pred is not None:
        print(f"Prediction: {pred}")
    else:
        print("No prediction received")

def send_single_pixel_only(port, pixel_index, value=1, baudrate=9600):
    """Send image with x[pixel_index]=value and all others 0. No MNIST needed. value 0-255."""
    if pixel_index < 0 or pixel_index >= INPUT_SIZE:
        print(f"Pixel index must be 0..{INPUT_SIZE-1}")
        return
    value = max(0, min(255, int(value)))
    print("="*60)
    print(f" Send single-pixel image (x[{pixel_index}]={value}, rest 0)")
    print("="*60)
    print(f"\nOpening serial port {port} at {baudrate} baud...")
    try:
        ser = serial.Serial(
            port=port,
            baudrate=baudrate,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0.5,
            write_timeout=2.0
        )
    except serial.SerialException as e:
        print(f"Error opening serial port: {e}")
        return
    time.sleep(2)
    img = np.zeros(INPUT_SIZE, dtype=np.uint8)
    img[pixel_index] = value
    print(f"Sending 784 bytes (only x[{pixel_index}]={value})...")
    send_command(ser, '1')
    time.sleep(0.5)
    pred = send_image_uart(ser, img)
    ser.close()
    if pred is not None:
        print(f"Prediction: {pred}")
    else:
        print("No prediction received")

def main():
    # Configuration
    PORT = 'COM6'  # Default port
    BAUDRATE = 9600  # Changed to 9600
    
    # Check for --zeros / -z or --pixel <i> (send and exit, no MNIST)
    args = [a.lower() for a in sys.argv[1:]]
    port = PORT
    for a in sys.argv[1:]:
        if a.upper().startswith('COM') or a.startswith('/dev/'):
            port = a
            break
    if '--zeros' in args or '-z' in args:
        send_zeros_only(port, BAUDRATE)
        return
    if '--pixel' in args:
        pixel_idx = 0
        pixel_val = 1
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
    
    # Check command line arguments for port
    if len(sys.argv) > 1:
        PORT = sys.argv[1]
    
    print("="*60)
    print(" MNIST MLP FPGA Tester")
    print(" UART: 9600 baud, 8N1")
    print("="*60)
    print(f"\nOpening serial port {PORT} at {BAUDRATE} baud...")
    
    try:
        ser = serial.Serial(
            port=PORT,
            baudrate=BAUDRATE,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0.5,
            write_timeout=2.0
        )
        
        print(f"✓ Serial port opened successfully")
        time.sleep(2)  # Wait for connection to stabilize
        
        # Clear any initial messages
        if ser.in_waiting > 0:
            initial = ser.read(ser.in_waiting)
            print(f"\nInitial data from FPGA:")
            print(initial.decode('utf-8', errors='ignore'))
        
    except serial.SerialException as e:
        print(f"\n✗ Error opening serial port: {e}")
        print(f"\nTroubleshooting:")
        print(f"- On Windows: Try COM1, COM3, COM4, etc.")
        print(f"- On Linux: Try /dev/ttyUSB0 or /dev/ttyACM0")
        print(f"- Check Device Manager (Windows) or 'dmesg | grep tty' (Linux)")
        print(f"- Ensure no other program is using the port")
        return
    
    # Load MNIST data
    print("\nLoading MNIST test data...")
    try:
        # Try multiple possible locations
        data_files = [
            ('t10k-images.idx3-ubyte', 't10k-labels.idx1-ubyte'),
            ('../data/t10k-images.idx3-ubyte', '../data/t10k-labels.idx1-ubyte'),
            ('data/t10k-images.idx3-ubyte', 'data/t10k-labels.idx1-ubyte'),
        ]
        
        images = None
        labels = None
        
        for img_path, lbl_path in data_files:
            try:
                images = load_mnist_images(img_path)
                labels = load_mnist_labels(lbl_path)
                print(f"✓ Loaded {len(images)} test images from {img_path}")
                break
            except FileNotFoundError:
                continue
        
        if images is None:
            raise FileNotFoundError("Could not find MNIST data files")
            
    except FileNotFoundError:
        print("✗ Error: MNIST data files not found!")
        print("\nPlease ensure these files are in the current directory:")
        print("  - t10k-images.idx3-ubyte")
        print("  - t10k-labels.idx1-ubyte")
        print("\nYou can download them from: http://yann.lecun.com/exdb/mnist/")
        ser.close()
        return
    
    try:
        # Test connection first
        if not test_connection(ser):
            print("\nWARNING: FPGA may not be responding!")
            response = input("Continue anyway? (y/n): ")
            if response.lower() != 'y':
                ser.close()
                return
        
        # Enter interactive mode
        interactive_mode(ser, images, labels)
        
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
    finally:
        ser.close()
        print("\nSerial port closed")

if __name__ == "__main__":
    main()