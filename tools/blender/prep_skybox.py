"""Builds a seamless 6 face skybox from one Meshy AI sky image (task 3D-06).

The Meshy faces are generated independently, so their edges do not match and the joins show
as hard vertical lines in game. This script rebuilds the cube from a single side image:

    Front = F, Right = mirror(F), Back = F, Left = mirror(F)

Going around the horizon, every seam then puts an edge next to a copy of itself, so all four
vertical joins match exactly. Up and Down are built as soft gradients from the average colour
of the side image's top and bottom rows, so their joins are a gentle colour change instead of
a mismatch (Up is overhead and Down sits under the cloud sea, so neither is often in view).

Run with Blender 5.2 in background mode, from the repo root:

  blender -b --factory-startup -P tools/blender/prep_skybox.py -- \
      --side "<path to the side image>" --out "<output folder>"
"""

import argparse
import os
import sys

import bpy
import numpy as np

# How far into the Up and Down faces the side colour fades, as a share of the face.
EDGE_FADE = 0.45
# Faint cloud mottling on the Up face, so it is not a flat colour.
CLOUD_STRENGTH = 0.05
CLOUD_SCALE = 6.0


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--side", required=True, help="the sky image used for all four sides")
    parser.add_argument("--out", required=True)
    parser.add_argument("--size", type=int, default=1024)
    return parser.parse_args(argv)


def load_pixels(path, size):
    image = bpy.data.images.load(path)
    if tuple(image.size) != (size, size):
        image.scale(size, size)
    width, height = image.size
    # Blender stores pixels bottom row first; keep that order throughout and it cancels out.
    return np.array(image.pixels[:], dtype=np.float32).reshape(height, width, 4)


def save_pixels(pixels, path):
    height, width = pixels.shape[0], pixels.shape[1]
    image = bpy.data.images.new(os.path.basename(path), width, height, alpha=False)
    image.pixels = np.clip(pixels, 0.0, 1.0).ravel()
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()


def cap_face(side, top):
    """Builds the Up or Down face: the side's edge colour around the border, fading to the
    average of the whole edge in the middle. `top` picks which edge of the side image to match."""
    size = side.shape[0]
    rows = side[-8:] if top else side[:8]
    edge = rows.mean(axis=0)  # one colour per column, averaged over a few rows
    center = edge.mean(axis=0)

    # Distance from the centre of the face, 0 in the middle and 1 at the border.
    axis = (np.arange(size) + 0.5) / size * 2 - 1
    gx, gy = np.meshgrid(axis, axis)
    border = np.maximum(np.abs(gx), np.abs(gy))
    weight = np.clip((border - (1 - EDGE_FADE)) / EDGE_FADE, 0.0, 1.0)[..., None]

    # The border colour at each pixel comes from the nearest point along the edge, so the join
    # lines up with the side faces column by column.
    along = np.where(np.abs(gx) >= np.abs(gy), gx, gy)
    index = np.clip(((along + 1) / 2 * size).astype(np.int32), 0, size - 1)
    border_color = edge[index]

    face = center[None, None, :] * (1 - weight) + border_color * weight

    if top:
        # A little low frequency mottling so the sky overhead is not perfectly flat.
        noise = np.sin(gx * CLOUD_SCALE) * np.cos(gy * CLOUD_SCALE)
        face[..., :3] += (noise * CLOUD_STRENGTH * (1 - weight[..., 0]))[..., None]

    face[..., 3] = 1.0
    return face


def main():
    args = parse_args()
    os.makedirs(args.out, exist_ok=True)
    side = load_pixels(args.side, args.size)
    mirrored = side[:, ::-1, :]

    faces = {
        "Front": side,
        "Back": side,
        "Right": mirrored,
        "Left": mirrored,
        "Up": cap_face(side, top=True),
        "Down": cap_face(side, top=False),
    }
    for name, pixels in faces.items():
        path = os.path.join(args.out, "Skybox_%s.png" % name)
        save_pixels(pixels, path)
        print("SKYFACE", name, path)


if __name__ == "__main__":
    main()
