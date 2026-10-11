"""Prepares the Meshy AI lobby models for Roblox (task 3D-01).

For each model listed in art/lobby_models.json it:
  1. imports the FBX from the source zip
  2. decimates the mesh to its triangle budget (Roblox allows 20,000 per mesh)
  3. recolours green in the base colour texture to a palette colour (no green rule)
  4. resizes the base colour texture and drops the normal, roughness and metallic maps
  5. scales the mesh so its largest dimension is the target size, pivot at the bottom centre
  6. exports <name>.fbx with the texture embedded, plus <name>.png
  7. renders a before and after preview, and writes manifest.json with the triangle counts

Run with Blender 5.2 in background mode, from the repo root:

  blender -b --factory-startup -P tools/blender/prep_models.py -- \
      --source "<folder with the Meshy zips>" --out "<output folder>"

The source art and the output stay outside git.
"""

import argparse
import colorsys
import json
import math
import os
import sys
import tempfile
import zipfile

import bpy
import mathutils
import numpy as np

SPEC_PATH = os.path.join("art", "lobby_models.json")
PALETTE_PATH = os.path.join("art", "palette.json")

# A pixel counts as green when its hue is in this range and it is not grey or near black.
GREEN_HUE_DEGREES = (70.0, 170.0)
GREEN_MIN_SATURATION = 0.2
GREEN_MIN_VALUE = 0.08

PREVIEW_SIZE = (480, 360)
# Baking the original texture onto the decimated mesh (Cycles).
BAKE_SAMPLES = 1
BAKE_MARGIN_PIXELS = 4
# Ray distances as a share of the model size, so the bake finds the high-poly surface.
BAKE_CAGE_SHARE = 0.02
BAKE_RAY_SHARE = 0.05
UV_ANGLE_LIMIT_DEGREES = 66.0
UV_ISLAND_MARGIN = 0.004
FBX_STUD_SCALE = 0.01


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--only", nargs="*", default=None, help="model names to process")
    return parser.parse_args(argv)


def load_json(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def find_zip(source, key):
    for name in sorted(os.listdir(source)):
        if name.startswith("Meshy_AI_" + key + "_") and name.endswith(".zip"):
            return os.path.join(source, name)
    raise FileNotFoundError("No zip for " + key + " in " + source)


def extract(zip_path, workdir, key):
    # A short folder name: the zip's own names are long enough to hit the Windows path limit.
    target = os.path.join(workdir, key)
    with zipfile.ZipFile(zip_path) as archive:
        for member in archive.namelist():
            resolved = os.path.realpath(os.path.join(target, member))
            if not resolved.startswith(os.path.realpath(target)):
                raise ValueError("Unsafe path in zip: " + member)
        archive.extractall(target)
    fbx = base_color = None
    for root, _, files in os.walk(target):
        for name in files:
            path = os.path.join(root, name)
            if name.endswith(".fbx"):
                fbx = path
            elif name.endswith(".png") and not any(
                name.endswith(suffix) for suffix in ("_normal.png", "_roughness.png", "_metallic.png")
            ):
                base_color = path
    if not fbx or not base_color:
        raise FileNotFoundError("Missing fbx or base colour in " + zip_path)
    return fbx, base_color


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_mesh(fbx_path):
    bpy.ops.import_scene.fbx(filepath=fbx_path)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if len(meshes) != 1:
        raise ValueError("Expected one mesh in " + fbx_path + ", found " + str(len(meshes)))
    obj = meshes[0]
    # Bake the import transform into the mesh so sizes are measured in world space.
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obj


def triangle_count(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


def apply_modifier(obj, modifier):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def decimate(obj, target):
    before = triangle_count(obj)
    if before > target:
        modifier = obj.modifiers.new("Decimate", "DECIMATE")
        modifier.decimate_type = "COLLAPSE"
        modifier.ratio = target / triangle_count(obj)
        modifier.use_collapse_triangulate = True
        apply_modifier(obj, modifier)
    return before, triangle_count(obj)


def world_bounds(obj):
    points = [obj.matrix_world @ mathutils.Vector(corner) for corner in obj.bound_box]
    low = mathutils.Vector([min(p[i] for p in points) for i in range(3)])
    high = mathutils.Vector([max(p[i] for p in points) for i in range(3)])
    return low, high


def normalise(obj, size):
    low, high = world_bounds(obj)
    extent = high - low
    factor = size / max(extent)
    obj.scale = (factor, factor, factor)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    low, high = world_bounds(obj)
    # Pivot at the bottom centre: move the mesh so that point is the origin.
    offset = mathutils.Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
    obj.data.transform(mathutils.Matrix.Translation(-offset))
    obj.location = (0, 0, 0)
    low, high = world_bounds(obj)
    return [round(v, 2) for v in (high - low)]


def hex_to_hsv(hex_code):
    r, g, b = (int(hex_code[i : i + 2], 16) / 255 for i in (1, 3, 5))
    return colorsys.rgb_to_hsv(r, g, b)


def recolor_green(pixels, target_hex):
    """Moves green pixels to the target hue, keeping their shading. Returns the share changed."""
    rgb = pixels[..., :3]
    maxc = rgb.max(axis=-1)
    minc = rgb.min(axis=-1)
    delta = maxc - minc
    saturation = np.where(maxc > 0, delta / np.maximum(maxc, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    safe = np.maximum(delta, 1e-6)
    hue = np.where(
        maxc == r,
        ((g - b) / safe) % 6,
        np.where(maxc == g, (b - r) / safe + 2, (r - g) / safe + 4),
    ) * 60.0
    mask = (
        (hue >= GREEN_HUE_DEGREES[0])
        & (hue <= GREEN_HUE_DEGREES[1])
        & (saturation >= GREEN_MIN_SATURATION)
        & (maxc >= GREEN_MIN_VALUE)
    )
    if not mask.any():
        return 0.0
    target_h, target_s, target_v = hex_to_hsv(target_hex)
    # New hue from the target; saturation pulled toward the target's. Brightness is scaled so
    # the average green pixel lands on the target's brightness, which keeps the shading but
    # avoids dark greens turning into olive.
    new_s = np.clip((saturation + target_s) / 2, 0, 1)
    h6 = target_h * 6
    sector = int(h6) % 6
    frac = h6 - int(h6)
    v = np.clip(maxc * (target_v / max(float(maxc[mask].mean()), 1e-6)), 0, 1)
    p = v * (1 - new_s)
    q = v * (1 - new_s * frac)
    t = v * (1 - new_s * (1 - frac))
    channels = [
        (v, t, p),
        (q, v, p),
        (p, v, t),
        (p, q, v),
        (t, p, v),
        (v, p, q),
    ][sector]
    for index in range(3):
        rgb[..., index] = np.where(mask, channels[index], rgb[..., index])
    pixels[..., :3] = rgb
    return float(mask.mean())


def use_base_color_only(obj, image):
    """Gives the object one material with just a base colour texture. Returns the texture node."""
    material = bpy.data.materials.new(obj.name + "Material")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    principled = nodes.get("Principled BSDF")
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    material.node_tree.links.new(texture.outputs["Color"], principled.inputs["Base Color"])
    obj.data.materials.clear()
    obj.data.materials.append(material)
    nodes.active = texture
    return texture


def smart_uv(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(
        angle_limit=math.radians(UV_ANGLE_LIMIT_DEGREES), island_margin=UV_ISLAND_MARGIN
    )
    bpy.ops.object.mode_set(mode="OBJECT")


def bake_base_color(high, low, size, model_size):
    """Projects the high-poly base colour onto the low-poly mesh's new UVs."""
    image = bpy.data.images.new(low.name + "Baked", size, size, alpha=False)
    use_base_color_only(low, image)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = BAKE_SAMPLES
    bake = scene.render.bake
    bake.use_selected_to_active = True
    bake.cage_extrusion = model_size * BAKE_CAGE_SHARE
    bake.max_ray_distance = model_size * BAKE_RAY_SHARE
    bake.margin = BAKE_MARGIN_PIXELS
    bake.use_pass_direct = False
    bake.use_pass_indirect = False
    bake.use_pass_color = True
    bpy.ops.object.select_all(action="DESELECT")
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"})
    return image


def finish_texture(image, target_hex, out_path):
    width, height = image.size
    pixels = np.array(image.pixels[:], dtype=np.float32).reshape(height, width, 4)
    changed = recolor_green(pixels, target_hex) if target_hex else 0.0
    image.pixels = pixels.ravel()
    image.filepath_raw = out_path
    image.file_format = "PNG"
    image.save()
    return changed


def render_preview(obj, path):
    scene = bpy.context.scene
    low, high = world_bounds(obj)
    center = (low + high) / 2
    radius = (high - low).length / 2
    camera = scene.camera
    if camera is None:
        camera = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
        scene.collection.objects.link(camera)
        scene.camera = camera
    camera.data.clip_end = max(1000.0, radius * 20)
    camera.location = center + mathutils.Vector((1.0, -1.3, 0.8)).normalized() * radius * 2.6
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x, scene.render.resolution_y = PREVIEW_SIZE
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def export_fbx(obj, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"MESH"},
        path_mode="COPY",
        embed_textures=True,
        axis_forward="-Z",
        axis_up="Y",
        # Blender writes FBX in centimetres, which Roblox reads as 100 studs per Blender
        # unit. Scaling by 0.01 makes one Blender unit one stud in the importer.
        global_scale=FBX_STUD_SCALE,
    )


def main():
    args = parse_args()
    spec = load_json(SPEC_PATH)
    palette = {color["name"]: color["hex"] for color in load_json(PALETTE_PATH)["colors"]}
    os.makedirs(args.out, exist_ok=True)
    previews = os.path.join(args.out, "previews")
    os.makedirs(previews, exist_ok=True)
    workdir = tempfile.mkdtemp(prefix="colorpanic_prep_")

    manifest = {}
    report = []
    for entry in spec["models"]:
        name = entry["name"]
        if args.only and name not in args.only:
            continue
        fbx_path, base_color_path = extract(find_zip(args.source, entry["source"]), workdir, entry["source"])

        reset_scene()
        original = import_mesh(fbx_path)
        render_preview(original, os.path.join(previews, name + "_before.png"))

        reset_scene()
        high = import_mesh(fbx_path)
        high.name = name + "High"
        normalise(high, entry["size"])
        use_base_color_only(high, bpy.data.images.load(base_color_path))

        obj = high.copy()
        obj.data = high.data.copy()
        obj.name = name
        bpy.context.scene.collection.objects.link(obj)
        before, after = decimate(obj, entry["triangles"])
        size = normalise(obj, entry["size"])
        smart_uv(obj)
        image = bake_base_color(high, obj, entry["texture"], entry["size"])
        target_hex = palette[entry["recolorGreen"]] if entry["recolorGreen"] else None
        changed = finish_texture(image, target_hex, os.path.join(args.out, name + ".png"))
        bpy.data.objects.remove(high)
        render_preview(obj, os.path.join(previews, name + "_after.png"))
        export_fbx(obj, os.path.join(args.out, name + ".fbx"))

        manifest[name] = after
        report.append(
            {
                "name": name,
                "source": entry["source"],
                "trianglesBefore": before,
                "trianglesAfter": after,
                "sizeStuds": size,
                "texture": entry["texture"],
                "greenRecoloredShare": round(changed, 4),
                "greenTo": entry["recolorGreen"],
            }
        )
        print("PREP", json.dumps(report[-1]))

    with open(os.path.join(args.out, "manifest.json"), "w", encoding="utf-8") as handle:
        json.dump({"triangles": manifest, "report": report}, handle, indent=2)


if __name__ == "__main__":
    main()
