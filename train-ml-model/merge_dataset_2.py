#!/usr/bin/env python3
"""
merge_models_id_only.py

Merge YOLOv11 datasets into one output while forcing every bbox to class id 1 (id_card).
Writes a unified 3 class data.yaml:

train: train/images
val: valid/images
test: test/images

nc: 3
names: ['credit_card', 'id_card', 'passport']

It will:
 1. Use the datasets you pass with --datasets globs, OR
 2. If none provided, auto discover any folders under --root that end with ".yolov11"
    and contain train and valid or val and test splits.

Usage examples:
  python3 merge_models_id_only.py --root . --out merged_dataset_2.yolov11 --dry-run
  python3 merge_models_id_only.py --root . --out merged_dataset_2.yolov11 \
      --datasets "ID*.*.yolov11,id*.v1i.yolov11,id_card*.yolov11,idcard*detector*.yolov11"
"""

import argparse
import os
import shutil
from collections import defaultdict
from pathlib import Path
from typing import List, Tuple, Optional

UNIFIED_NAMES = ["credit_card", "id_card", "passport"]
FORCED_TARGET_ID = 1  # everything becomes id_card

SPLIT_ALIASES = {
    "train": ["train"],
    "valid": ["valid", "val"],
    "test":  ["test"],
}

IMG_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp", ".tif", ".tiff"}


def make_dirs(p: Path):
    p.mkdir(parents=True, exist_ok=True)


def sanitize_prefix(name: str) -> str:
    return name.replace(os.sep, "_").replace(" ", "_").replace(".", "_")


def find_split_dirs(dataset_dir: Path, split_key: str) -> Tuple[Optional[Path], Optional[Path]]:
    for alias in SPLIT_ALIASES[split_key]:
        images_dir = dataset_dir / alias / "images"
        labels_dir = dataset_dir / alias / "labels"
        if images_dir.exists() and images_dir.is_dir():
            return images_dir, labels_dir if labels_dir.exists() else None
    return None, None


def iter_images(images_dir: Path):
    for p in images_dir.rglob("*"):
        if p.is_file() and p.suffix.lower() in IMG_EXTS:
            yield p


def iter_label_files(labels_dir: Optional[Path]):
    if not labels_dir:
        return
    for p in labels_dir.rglob("*.txt"):
        if p.is_file():
            yield p


def resolve_datasets(root: Path, dataset_globs: Optional[List[str]]) -> List[Path]:
    found = []
    if dataset_globs:
        for pattern in dataset_globs:
            for p in root.glob(pattern):
                if p.is_dir():
                    found.append(p.resolve())
    else:
        # auto discover any folder that ends with .yolov11
        for p in root.iterdir():
            if p.is_dir() and p.name.lower().endswith(".yolov11"):
                found.append(p.resolve())

    # keep only those that actually look like YOLO splits
    usable = []
    for d in found:
        ti, _ = find_split_dirs(d, "train")
        vi, _ = find_split_dirs(d, "valid")
        tei, _ = find_split_dirs(d, "test")
        if ti is not None and (vi is not None) and (tei is not None):
            usable.append(d)
    return usable


def process_split(
    dataset_dir: Path,
    split_key: str,
    out_images: Path,
    out_labels: Path,
    prefix: str,
    target_id: int,
    class_counts: dict,
    dry_run: bool = False,
):
    images_dir, labels_dir = find_split_dirs(dataset_dir, split_key)

    if images_dir is None:
        print(f"[WARN] Missing split '{split_key}' in {dataset_dir}. Checked {SPLIT_ALIASES[split_key]}")
        return 0, 0, 0

    copied_images = 0
    copied_labels = 0
    bbox_written = 0

    imgs = list(iter_images(images_dir))
    if not imgs:
        print(f"[WARN] No images under {images_dir}")
    for img in imgs:
        new_name = f"{prefix}_{img.name}"
        dest = out_images / new_name
        if not dry_run:
            make_dirs(dest.parent)
            shutil.copy2(img, dest)
        copied_images += 1

    if labels_dir is None:
        print(f"[INFO] No labels directory for split '{split_key}' in {dataset_dir}")
    else:
        lbls = list(iter_label_files(labels_dir))
        for lab in lbls:
            new_name = f"{prefix}_{lab.name}"
            dest = out_labels / new_name
            if not dry_run:
                make_dirs(dest.parent)

            lines = lab.read_text(encoding="utf-8").splitlines()
            out_lines = []

            def append_line(tokens):
                nonlocal bbox_written
                out_lines.append(" ".join(tokens))
                class_counts[target_id] += 1
                bbox_written += 1

            for line in lines:
                line = line.strip()
                if not line:
                    continue
                parts = line.split()
                if len(parts) >= 5:
                    vals = parts[1:]
                    if len(vals) % 4 == 0:
                        for i in range(0, len(vals), 4):
                            bbox = vals[i:i+4]
                            append_line([str(target_id)] + bbox)
                    else:
                        parts[0] = str(target_id)
                        append_line(parts)
                else:
                    if parts:
                        parts[0] = str(target_id)
                        append_line(parts)

            if not dry_run:
                dest.write_text("\n".join(out_lines) + ("\n" if out_lines else ""), encoding="utf-8")
            copied_labels += 1

    return copied_images, copied_labels, bbox_written


def merge(root: Path, out: Path, datasets: List[Path], dry_run: bool = False):
    for split in ("train", "valid", "test"):
        make_dirs(out / split / "images")
        make_dirs(out / split / "labels")

    stats = {}
    class_counts = defaultdict(int)
    total_boxes = 0

    for ds_path in datasets:
        prefix = sanitize_prefix(ds_path.name)
        stats[ds_path.name] = {}

        for split in ("train", "valid", "test"):
            out_images = out / split / "images"
            out_labels = out / split / "labels"
            ci, cl, boxes = process_split(
                ds_path, split, out_images, out_labels, prefix, FORCED_TARGET_ID, class_counts, dry_run=dry_run
            )
            total_boxes += boxes
            stats[ds_path.name][split] = {"images_copied": ci, "labels_copied": cl, "boxes": boxes}

    data_yaml = out / "data.yaml"
    yaml_lines = [
        "train: train/images",
        "val: valid/images",
        "test: test/images",
        "",
        f"nc: {len(UNIFIED_NAMES)}",
        f"names: {UNIFIED_NAMES}",
    ]
    if not dry_run:
        data_yaml.write_text("\n".join(yaml_lines) + "\n", encoding="utf-8")

    return stats, dict(class_counts), total_boxes


def main():
    ap = argparse.ArgumentParser(description="Merge YOLOv11 datasets into one, forcing all boxes to id_card (id 1).")
    ap.add_argument("--root", type=str, default=None, help="Folder that contains dataset folders.")
    ap.add_argument("--out", type=str, default="merged_dataset.yolov11", help="Output folder name.")
    ap.add_argument(
        "--datasets",
        type=str,
        default=None,
        help="Comma separated glob patterns relative to --root, for example: \"ID*.*.yolov11,id*.v1i.yolov11\"",
    )
    ap.add_argument("--dry-run", action="store_true", help="Preview actions without copying files.")
    args = ap.parse_args()

    script_root = Path(__file__).resolve().parent
    root = Path(args.root).resolve() if args.root else script_root
    out = root / args.out

    patterns = [s.strip() for s in args.datasets.split(",")] if args.datasets else None
    candidates = resolve_datasets(root, patterns)

    print(f"Root: {root}")
    print(f"Output: {out}")
    print(f"Patterns: {patterns}")
    print("Discovered datasets:")
    for d in candidates:
        print(f"  - {d}")

    if not candidates:
        print("[ERROR] No usable .yolov11 datasets found. Adjust --root or --datasets.")
        return

    stats, class_counts, total_boxes = merge(root, out, candidates, dry_run=args.dry_run)

    print("\nMerge summary:")
    for ds, s in stats.items():
        print(f" - {ds}:")
        for split, counts in s.items():
            print(
                "    {split}: images_copied={images}, labels_copied={labels}, boxes={boxes}".format(
                    split=split, images=counts["images_copied"], labels=counts["labels_copied"], boxes=counts["boxes"]
                )
            )

    print("\nClass counts (post merge):")
    for cls_id in sorted(class_counts):
        name = UNIFIED_NAMES[cls_id] if 0 <= cls_id < len(UNIFIED_NAMES) else str(cls_id)
        print(f"  class {cls_id} ({name}): {class_counts[cls_id]}")
    print(f"  total boxes: {total_boxes}")

    if not args.dry_run:
        print(f"\nMerged dataset written to: {out}")
        print(f"Merged data.yaml: {out / 'data.yaml'}")
    else:
        print("\nDry run completed. No files were changed.")


if __name__ == "__main__":
    main()
