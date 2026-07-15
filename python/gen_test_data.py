"""
gen_test_data.py
-----------------
Sinh cac file test_data_XXXX.txt tu tap kiem tra (test set) cua MNIST de nap
vao testbench Verilog (tb_full.v). Day la buoc "sinh du lieu test bang Python"
duoc mo ta trong bao cao thuc tap (muc 2.7).

Dinh dang moi file test_data_XXXX.txt (785 dong nhi phan, dung cho $readmemb
trong Verilog):
  - 784 dong dau tien: gia tri muc xam cua tung pixel anh 28x28 (duyet theo
    hang, giong thu tu tra ve boi mnist_loader.load_data_wrapper), da duoc
    chuan hoa ve [0,1) va chuyen sang so co dau dinh dang Q1.15 (bu hai,
    16 bit) -- dung dinh dang input ma khoi neuron (neuron.v/include.v)
    dang su dung (dataWidth=16, phan nguyen 1 bit).
  - dong thu 785: nhan (label) 0-9 cua anh, ghi duoi dang so nguyen khong dau
    16 bit nhi phan (vi du nhan "5" -> "0000000000000101"), giong cach
    testbench doc "expected_digit = in_mem[numPixel]".

Cach dung:
    1) Dat file mnist.pkl.gz (cung dinh dang du lieu ma mnist_loader.py trong
       thu muc nay dang doc) vao cung thu muc voi script nay. Neu chua co,
       xem huong dan tai du lieu o muc 2.7 cua bao cao (nguon: trang chu
       Yann LeCun hoac ban mirror "mnist.pkl.gz" thuong dung voi sach
       Neural Networks and Deep Learning cua Michael Nielsen).
    2) Chay:  python gen_test_data.py --num 100
       -> sinh ra test_data_0000.txt ... test_data_0099.txt trong thu muc
          hien tai, dung vi tri ma tb_full.v mong doi (chay cung thu muc
          voi mo phong).
"""

import argparse
import gzip
import pickle as cPickle

DATA_WIDTH = 16
DATA_INT_WIDTH = 1                       # input dang Q1.15 (giong bien inputIntSize
DATA_FRAC_WIDTH = DATA_WIDTH - DATA_INT_WIDTH   # trong genSigmoid.py / neuron.v)


def to_twos_complement_bin(value: float, data_width: int, frac_width: int) -> str:
    """Chuyen so thuc trong [-1, 1) sang chuoi nhi phan bu hai data_width bit."""
    scaled = int(round(value * (2 ** frac_width)))
    if scaled < 0:
        scaled += (1 << data_width)
    scaled &= (1 << data_width) - 1
    return format(scaled, "0{}b".format(data_width))


def load_mnist_test_set(path: str = "mnist.pkl.gz"):
    """Doc tap test cua MNIST (dinh dang giong mnist_loader.load_data)."""
    with gzip.open(path, "rb") as f:
        _training_data, _validation_data, test_data = cPickle.load(f, encoding="iso-8859-1")
    images, labels = test_data
    return images, labels


def generate(num_tests: int, mnist_path: str, out_prefix: str = "test_data_"):
    images, labels = load_mnist_test_set(mnist_path)
    n = min(num_tests, len(images))
    for idx in range(n):
        pixels = images[idx]
        label = int(labels[idx])
        fname = "{}{:04d}.txt".format(out_prefix, idx)
        with open(fname, "w") as f:
            for p in pixels:
                f.write(to_twos_complement_bin(float(p), DATA_WIDTH, DATA_FRAC_WIDTH) + "\n")
            f.write(format(label, "016b") + "\n")
    print("Da sinh {} file test_data_XXXX.txt (0000..{:04d}).".format(n, n - 1))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Sinh file test tu tap MNIST cho testbench Verilog")
    parser.add_argument("--num", type=int, default=100, help="So anh test can sinh (mac dinh 100)")
    parser.add_argument("--mnist", type=str, default="mnist.pkl.gz", help="Duong dan file mnist.pkl.gz")
    args = parser.parse_args()
    generate(args.num, args.mnist)
