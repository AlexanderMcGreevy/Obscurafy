#!/usr/bin/env python3
"""
merge_yolov11_datasets.py

Merge multiple yolov11-style datasets into a single dataset with a unified class schema.

Usage:
    python3 merge_yolov11_datasets.py --root /path/to/umass_hackathon --out merged_dataset.yolov11

This script will:
 - Copy images and label files from each dataset's train/valid/test splits into a single output folder
 - Remap class IDs in label files according to a mapping defined below
 - Prefix copied files with the source dataset name to avoid name collisions
 - Write a `data.yaml` for the merged dataset with unified class names

Assumptions & safety:
 - Each dataset follows the structure: <dataset>/train/images, <dataset>/train/labels, etc.
 - Most provided datasets are single-class (nc: 1) and use class id 0; the script will remap that 0 to the unified id you provide.
 - The script supports dry-run to preview actions.
"""

import argparse
import os
import shutil
from collections import defaultdict
from pathlib import Path


UNIFIED_NAMES = ["credit_card", "id_card", "passport"]

# Configure your datasets here: folder name -> target unified id
# Folders are relative to the repository root (script's parent by default)
DATASETS = {
    "credit-cards.yolov11": 0,      # names: ['card'] -> credit_card (0)
    "card-live-video.yolov11": 0,   # names: ['CreditCard'] -> credit_card (0)
    "VKYC.v2i.yolov11": 1,          # names: ['ID'] -> id_card (1)
    "passport.yolov11": 2,          # names: ['passport'] -> passport (2)
}


def make_dirs(path: Path):
    path.mkdir(parents=True, exist_ok=True)


def process_split(
    dataset_dir: Path,
    split: str,
    out_images: Path,
    out_labels: Path,
    prefix: str,
    target_id: int,
    class_counts: dict,
    dry_run: bool = False,
):
    images_dir = dataset_dir / split / "images"
    labels_dir = dataset_dir / split / "labels"

    image_files = list(images_dir.glob("**/*")) if images_dir.exists() else []
    label_files = list(labels_dir.glob("**/*.txt")) if labels_dir.exists() else []

    copied_images = 0
    copied_labels = 0
    bbox_written = 0

    # Copy images: prefix filename to avoid collisions
    for img in image_files:
        if img.is_file():
            new_name = f"{prefix}_{img.name}"
            dest = out_images / new_name
            if not dry_run:
                make_dirs(dest.parent)
                shutil.copy2(img, dest)
            copied_images += 1

    # Copy & remap labels
    for lab in label_files:
        if lab.is_file():
            # New label file name mirrors prefixed image base name but .txt
            new_name = f"{prefix}_{lab.name}"
            dest = out_labels / new_name
            if not dry_run:
                make_dirs(dest.parent)
            # Read and remap
            lines = lab.read_text(encoding="utf-8").splitlines()
            out_lines = []

            def append_line(tokens):
                nonlocal bbox_written
                out_line = " ".join(tokens)
                out_lines.append(out_line)
                try:
                    cls_id = int(tokens[0])
                except (ValueError, IndexError):
                    cls_id = target_id
                class_counts[cls_id] += 1
                bbox_written += 1
            for line in lines:
                line = line.strip()
                if not line:
                    continue
                parts = line.split()
                # Handle possible multiple bbox entries on a single line (some files concatenate bboxes):
                # YOLO format per bbox: class x_center y_center width height => 5 tokens
                # If a line has more than 5 tokens, split the trailing tokens into 4-number bbox chunks and write multiple lines.
                if len(parts) >= 5:
                    vals = parts[1:]
                    if len(vals) % 4 == 0:
                        # multiple 4-number bbox chunks
                        for i in range(0, len(vals), 4):
                            bbox = vals[i:i+4]
                            append_line([str(target_id)] + bbox)
                    else:
                        # Unexpected format: fallback to replacing only the class id
                        parts[0] = str(target_id)
                        append_line(parts)
                else:
                    # Malformed/short line — replace class token if present or skip
                    if parts:
                        parts[0] = str(target_id)
                        append_line(parts)
            if not dry_run:
                dest.write_text("\n".join(out_lines) + ("\n" if out_lines else ""), encoding="utf-8")
            copied_labels += 1

    return copied_images, copied_labels, bbox_written


def merge(root: Path, out: Path, dry_run: bool = False):
    # Create output structure
    for split in ("train", "valid", "test"):
        make_dirs(out / split / "images")
        make_dirs(out / split / "labels")

    stats = {}
    class_counts = defaultdict(int)
    total_boxes = 0

    for ds_name, target_id in DATASETS.items():
        ds_path = root / ds_name
        if not ds_path.exists():
            print(f"Warning: dataset folder {ds_name} not found under {root} — skipping")
            continue

        prefix = ds_name.replace(os.sep, "_").replace(".", "_")
        stats[ds_name] = {}

        for split in ("train", "valid", "test"):
            out_images = out / split / "images"
            out_labels = out / split / "labels"
            ci, cl, boxes = process_split(
                ds_path,
                split,
                out_images,
                out_labels,
                prefix,
                target_id,
                class_counts,
                dry_run=dry_run,
            )
            total_boxes += boxes
            stats[ds_name][split] = {"images_copied": ci, "labels_copied": cl, "boxes": boxes}

    # Write merged data.yaml
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
    parser = argparse.ArgumentParser(description="Merge multiple yolov11 datasets into a unified dataset.")
    parser.add_argument("--root", type=str, default=None, help="Path to repository root that contains the dataset folders. Defaults to script's parent.")
    parser.add_argument("--out", type=str, default="merged_dataset.yolov11", help="Output folder name for merged dataset (created inside root).")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done without copying files.")
    args = parser.parse_args()

    script_root = Path(__file__).resolve().parent
    root = Path(args.root).resolve() if args.root else script_root
    out = root / args.out

    print(f"Root: {root}")
    print(f"Output: {out}")
    print(f"Datasets to merge: {list(DATASETS.keys())}")
    print("Dry run:" , args.dry_run)

    stats, class_counts, total_boxes = merge(root, out, dry_run=args.dry_run)

    print("\nMerge summary:")
    for ds, s in stats.items():
        print(f" - {ds}:")
        for split, counts in s.items():
            print(
                "    {split}: images_copied={images}, labels_copied={labels}, boxes={boxes}".format(
                    split=split,
                    images=counts["images_copied"],
                    labels=counts["labels_copied"],
                    boxes=counts["boxes"],
                )
            )

    print("\nClass counts (post-merge):")
    for cls_id in sorted(class_counts):
        name = UNIFIED_NAMES[cls_id] if 0 <= cls_id < len(UNIFIED_NAMES) else str(cls_id)
        print(f"  class {cls_id} ({name}): {class_counts[cls_id]}")
    print(f"  total boxes: {total_boxes}")

    if not args.dry_run:
        print(f"\nMerged dataset written to: {out}")
        print(f"Merged data.yaml: {out / 'data.yaml'}")
    else:
        print("\nDry run completed. No files were changed.")


if __name__ == '__main__':
    main()
