#!/usr/bin/env python3
"""导出三档 YOLOv8 ONNX 模型给 iOS 工程用。

用法:
    python Tools/fetch_models.py            # 只补缺失的档位
    python Tools/fetch_models.py --all      # 三档全部重导

需要: pip install ultralytics
"""
import argparse
import shutil
import sys
from pathlib import Path

TIERS = [("n", "yolov8n"), ("s", "yolov8s"), ("m", "yolov8m")]
IMGSZ = 416
DEST = Path(__file__).resolve().parent.parent / "TianShen" / "Resources" / "Models"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--all", action="store_true", help="三档全部重新导出")
    parser.add_argument("--imgsz", type=int, default=IMGSZ)
    args = parser.parse_args()

    try:
        from ultralytics import YOLO
    except ImportError:
        print("缺少 ultralytics:  pip install ultralytics")
        return 1

    DEST.mkdir(parents=True, exist_ok=True)
    for size, name in TIERS:
        target = DEST / f"{name}.onnx"
        if target.exists() and not args.all:
            print(f"[skip] {target.name} 已存在 ({target.stat().st_size // 1024} KB)")
            continue
        print(f"[export] {name} imgsz={args.imgsz} ...")
        model = YOLO(f"{name}.pt")
        out = model.export(format="onnx", imgsz=args.imgsz, opset=12, simplify=True, dynamic=False)
        shutil.copy(out, target)
        print(f"[ok] {target}  {target.stat().st_size // 1024} KB")
    print("完成。重新构建 iOS 工程即可。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
