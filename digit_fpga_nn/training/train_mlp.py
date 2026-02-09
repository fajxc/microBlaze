import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from load_mnist import load_images, load_labels

class MLP(nn.Module):
    def __init__(self, hidden=32):
        super().__init__()
        self.fc1 = nn.Linear(784, hidden)
        self.fc2 = nn.Linear(hidden, 10)

    def forward(self, x):
        x = torch.relu(self.fc1(x))
        return self.fc2(x)

def main():
    X_train = load_images("../data/train-images.idx3-ubyte")
    y_train = load_labels("../data/train-labels.idx1-ubyte")
    X_test  = load_images("../data/t10k-images.idx3-ubyte")
    y_test  = load_labels("../data/t10k-labels.idx1-ubyte")

    # Use subset for faster iteration
    n_train = 20000
    X_train = X_train[:n_train]
    y_train = y_train[:n_train]

    X_train = X_train.reshape(-1, 784).astype(np.float32) / 255.0
    X_test  = X_test.reshape(-1, 784).astype(np.float32) / 255.0

    device = "cuda" if torch.cuda.is_available() else "cpu"
    model = MLP(hidden=32).to(device)

    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=1e-3)

    X_train_t = torch.tensor(X_train)
    y_train_t = torch.tensor(y_train, dtype=torch.long)
    X_test_t  = torch.tensor(X_test)
    y_test_t  = torch.tensor(y_test, dtype=torch.long)

    batch_size = 128
    epochs = 10

    for epoch in range(1, epochs + 1):
        model.train()
        perm = torch.randperm(X_train_t.size(0))

        for i in range(0, X_train_t.size(0), batch_size):
            idx = perm[i:i+batch_size]
            xb = X_train_t[idx].to(device)
            yb = y_train_t[idx].to(device)

            optimizer.zero_grad()
            logits = model(xb)
            loss = criterion(logits, yb)
            loss.backward()
            optimizer.step()

        # Compute training accuracy
        model.eval()
        with torch.no_grad():
            train_logits = model(X_train_t.to(device))
            train_pred = torch.argmax(train_logits, dim=1)
            train_acc = float((train_pred.cpu() == y_train_t).float().mean())

            test_logits = model(X_test_t.to(device))
            test_pred = torch.argmax(test_logits, dim=1)
            test_acc = float((test_pred.cpu() == y_test_t).float().mean())

        print(f"Epoch {epoch:02d}: train_acc={train_acc:.4f}  test_acc={test_acc:.4f}")

    torch.save(model.state_dict(), "mlp32.pth")
    print("Saved model: mlp32.pth")

if __name__ == "__main__":
    main()
