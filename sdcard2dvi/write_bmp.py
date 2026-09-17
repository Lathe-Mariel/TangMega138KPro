# -*- coding: utf-8 -*-
"""
SDカード (PhysicalDrive1) の先頭に BMP 生データを書き込む
使い方: python write_bmp.py  (管理者権限の PowerShell で実行)
"""
import sys, os

BMP = r"c:\Git\TangMega138KPro\sdcard2dvi\sdcard\antena.bmp"
DRIVE = r"\\.\PhysicalDrive1"

def main():
    if not os.path.exists(BMP):
        print("ERROR: BMP が見つかりません:", BMP)
        sys.exit(1)

    src = open(BMP, "rb").read()
    print("BMP size:", len(src), "bytes")

    # 先頭2バイト確認
    print("header:", src[0:2])
    w = int.from_bytes(src[18:22], "little")
    h = int.from_bytes(src[22:26], "little")
    print(f"width={w} height={h}")

    print("書き込み先:", DRIVE)
    print(">>> この操作はSDカード全体を上書きします。続行しますか? (y/N) ", end="")
    ans = input().strip().lower()
    if ans != "y":
        print("中断しました")
        sys.exit(0)

    # 物理ドライブは "rb+" (O_RDWR, O_CREAT/O_TRUNC なし) で開く。
    # "wb" は O_CREAT|O_TRUNC が付き、デバイスファイルでは Invalid argument になる。
    # 物理ドライブは "rb+" (O_RDWR, O_CREAT/O_TRUNC なし) で開く。
    # 注意: buffering=0 (unbuffered) は書き込みサイズがセクタ倍数必須のため
    #       Invalid argument になる。buffered モード (デフォルト) を使う。
    f = None
    for mode in ("rb+", "r+b"):
        try:
            f = open(DRIVE, mode)
            break
        except PermissionError:
            print("ERROR: Permission denied. 管理者権限の PowerShell で実行してください。")
            sys.exit(1)
        except OSError as e:
            print(f"  open({mode}) -> {e}")
            f = None
    if f is None:
        print("ERROR: ドライブを開けません。E: がエクスプローラ等で使用中でないか確認してください。")
        sys.exit(1)

    # 512バイト境界にパディング (物理ドライブへの生書き込みはセクタ倍数必須)
    SECTOR = 512
    padded = len(src)
    if padded % SECTOR != 0:
        padded = (padded // SECTOR + 1) * SECTOR
        src = src + b"\x00" * (padded - len(src))
    print("書き込みサイズ (パディング後):", padded, "bytes")

    # セクタ境界に揃えて書き込む
    try:
        # セクタ倍数で分割書き込み (raw write)
        offset = 0
        f.seek(0)
        for chunk in [src[i:i+4096] for i in range(0, len(src), 4096)]:
            f.write(chunk)
        f.flush()
        f.close()
        print("書き込み完了:", padded, "bytes")
    except Exception as e:
        print("ERROR: 書き込みに失敗:", repr(e))
        sys.exit(1)
    except Exception as e:
        print("ERROR: 書き込みに失敗:", repr(e))
        sys.exit(1)

if __name__ == "__main__":
    main()
