#!/usr/bin/env python3
"""
Convert a YOLOv11 .pt model to Core ML without overwriting.
Default output name is 'coreml.mlmodel'. If it exists, creates 'coreml_1.mlmodel', etc.
"""

import argparse
import os
import shutil
import sys
from pathlib import Path

def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--weights", type=str, default="best.pt", help="Path to .pt file")
    p.add_argument("--imgsz", type=int, default=640, help="Square input size")
    p.add_argument("--half", action="store_true", help="Export in FP16")
    p.add_argument("--no_nms", action="store_true", help="Export without built in NMS")
    p.add_argument("--outname", type=str, default="coreml", help="Base name for Core ML file")
    return p.parse_args()

def next_free_path(base: Path) -> Path:
    """Return a non existing path by adding _1, _2, ... if needed."""
    if not base.exists():
        return base
    stem = base.stem
    suffix = base.suffix
    parent = base.parent
    i = 1
    while True:
        candidate = parent / f"{stem}_{i}{suffix}"
        if not candidate.exists():
            return candidate
        i += 1

def main():
    args = parse_args()

    # Import here to give a clear error if Ultralytics is missing
    try:
        from ultralytics import YOLO
    except Exception as e:
        print("Ultralytics is required. Install with: pip install ultralytics", file=sys.stderr)
        raise

    weights_p = Path(args.weights)
    if not weights_p.exists():
        print(f"Missing weights file: {weights_p}", file=sys.stderr)
        sys.exit(1)

    print(f"Loading model from {weights_p}")
    model = YOLO(str(weights_p))

    print("Exporting to Core ML")
    # nms is True by default for simplest app integration
    nms_flag = not args.no_nms

    # Run export
    export_out = model.export(
        format="coreml",
        imgsz=args.imgsz,
        nms=nms_flag,
        half=args.half,
        dynamic=False,     # static input size is preferred for Core ML
        int8=False,        # set True only if you have a calibration flow
        optimize=False,    # optional Core ML graph optimizations
        verbose=True
    )

    # Ultralytics returns a path or a list of paths. Find the .mlmodel or .mlpackage.
    def find_coreml_path(x):
        if isinstance(x, (list, tuple)):
            for item in x:
                p = Path(item)
                if p.suffix == ".mlmodel" or p.suffix == ".mlpackage":
                    return p
            # if not found, fall back to first item
            return Path(x[0])
        return Path(x)

    produced = find_coreml_path(export_out)
    if not produced.exists():
        print(f"Export completed but output file was not found: {produced}", file=sys.stderr)
        sys.exit(2)

    # Decide target filename
    ext = produced.suffix  # keep .mlmodel or .mlpackage as produced
    target = Path.cwd() / f"{args.outname}{ext}"
    target = next_free_path(target)

    # Copy to final name in current folder
    if produced.resolve() != target.resolve():
        if produced.is_dir():
            # .mlpackage is a directory
            print(f"Copying {produced} to {target}")
            if target.exists():
                print(f"Target already exists: {target}", file=sys.stderr)
                sys.exit(3)
            shutil.copytree(produced, target)
        else:
            print(f"Copying {produced} to {target}")
            shutil.copy2(produced, target)

    print("\nDone.")
    print(f"Core ML model saved at: {target}")
    print(f"Settings used: imgsz={args.imgsz} half={args.half} nms={nms_flag}")
    print("Tip. Keep the same preprocessing in your app as during training.")

if __name__ == "__main__":
    main()
