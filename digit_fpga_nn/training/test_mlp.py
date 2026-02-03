import numpy as np
import torch
import matplotlib.pyplot as plt
from train_mlp import MLP
from load_mnist import load_images, load_labels

def main():
    # Load model
    model = MLP(hidden=32)
    model.load_state_dict(torch.load("mlp32.pth", map_location="cpu"))
    model.eval()

    # Load test data
    X_test = load_images("../data/t10k-images.idx3-ubyte")
    y_test = load_labels("../data/t10k-labels.idx1-ubyte")

    X_test = X_test.reshape(-1, 784).astype(np.float32) / 255.0

    # Pick random samples
    idx = np.random.choice(len(X_test), size=5, replace=False)

    for i in idx:
        x = torch.tensor(X_test[i]).unsqueeze(0)
        with torch.no_grad():
            logits = model(x)
            probs = torch.softmax(logits, dim=1)[0]
            pred = int(torch.argmax(probs))

        print(f"True: {y_test[i]}  Predicted: {pred}  Confidence: {float(probs[pred]):.3f}")

        img = X_test[i].reshape(28,28)
        plt.imshow(img, cmap="gray")
        plt.title(f"Pred {pred}")
        plt.show()

if __name__ == "__main__":
    main()
