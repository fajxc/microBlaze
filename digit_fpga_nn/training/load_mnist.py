import numpy as np

def load_images(path):
    with open(path, "rb") as f:
        magic = int.from_bytes(f.read(4), "big")
        assert magic == 2051
        n = int.from_bytes(f.read(4), "big")
        r = int.from_bytes(f.read(4), "big")
        c = int.from_bytes(f.read(4), "big")
        data = np.frombuffer(f.read(), dtype=np.uint8)
    return data.reshape(n, r, c)

def load_labels(path):
    with open(path, "rb") as f:
        magic = int.from_bytes(f.read(4), "big")
        assert magic == 2049
        n = int.from_bytes(f.read(4), "big")
        data = np.frombuffer(f.read(), dtype=np.uint8)
    return data

if __name__ == "__main__":
    X = load_images("../data/train-images.idx3-ubyte")
    y = load_labels("../data/train-labels.idx1-ubyte")

    print("Images:", X.shape)
    print("Labels:", y.shape)
    print("First label:", y[0])
