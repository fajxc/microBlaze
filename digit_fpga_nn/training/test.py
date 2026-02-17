import numpy as np
import torch
from train_mlp import MLP

H=32
x = np.fromfile("img_28x28.bin", dtype=np.uint8).astype(np.float32) / 255.0
x = torch.tensor(x).view(1,784)

model = MLP(hidden=H)
sd = torch.load("mlp32.pth", map_location="cpu")
model.load_state_dict(sd)
model.eval()

with torch.no_grad():
    pred = torch.argmax(model(x), dim=1).item()
print("Python pred:", pred)
