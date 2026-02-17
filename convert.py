from PIL import Image, ImageOps
import numpy as np

img = Image.open("digit.png").convert("L")
img = ImageOps.invert(img)          # flip if needed
img = img.resize((28,28))
np.array(img, dtype=np.uint8).reshape(-1).tofile("img_28x28.bin")
print("wrote img_28x28.bin (784 bytes)")
