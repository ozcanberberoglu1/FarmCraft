#!/usr/bin/env python3
"""Takes stray weights off the paws of a skinned dog model (art/models/animals/dog/dog.gltf).

The skinning of tools/blender/build_dog.py left a few dozen vertices on the inside of each
hind paw with a few percent of their weight on the spine: when the dog sits (the hips a
third of a metre down, the body pitched up) those were dragged up to 5 cm under the sole
(under the ground; on a car seat, into the cushion). Every vertex that is mostly on a paw
or a pastern (??_toe, ??_ft) keeps only the weights of its own leg's bones, renormalised.
build_dog.py now does the same (own_leg_only); this patches a built model in place without
Blender, and stamps the buffer's hash into the .gltf so that Godot imports it again.

usage: fix_dog_paw_skin.py [path/to/dog.gltf]      (does nothing to a model already clean)
"""
import hashlib
import json
import os
import sys

import numpy as np

LOW = ("_toe", "_ft")


def own_leg_only(joints, weights, names):
    """joints, weights: N x 4 (bone index, weight); names: the bones' names by index.
    Returns the weights with those of other bones than its own leg's taken off every
    vertex mostly on a paw or a pastern, and how many vertices that changed."""
    out = weights.astype(np.float64).copy()
    changed = 0
    for i in range(len(out)):
        top = names[joints[i][int(np.argmax(out[i]))]]
        if not top.endswith(LOW):
            continue
        leg = top.split("_")[0] + "_"
        stray = [k for k in range(out.shape[1]) if out[i][k] > 0.0 and not names[joints[i][k]].startswith(leg)]
        if not stray:
            continue
        out[i][stray] = 0.0
        out[i] /= out[i].sum()
        changed += 1
    return out, changed


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "art", "models", "animals", "dog", "dog.gltf")
    d = json.load(open(path))
    bin_path = os.path.join(os.path.dirname(path), d["buffers"][0]["uri"])
    data = bytearray(open(bin_path, "rb").read())
    names = [d["nodes"][k]["name"] for k in d["skins"][0]["joints"]]
    total = 0
    for mesh in d["meshes"]:
        for prim in mesh["primitives"]:
            att = prim["attributes"]
            if "JOINTS_0" not in att:
                continue
            ja, wa = d["accessors"][att["JOINTS_0"]], d["accessors"][att["WEIGHTS_0"]]
            jv, wv = d["bufferViews"][ja["bufferView"]], d["bufferViews"][wa["bufferView"]]
            assert ja["componentType"] in (5121, 5123) and wa["componentType"] == 5126 and not jv.get("byteStride") and not wv.get("byteStride")
            n = ja["count"]
            jt = np.uint8 if ja["componentType"] == 5121 else np.uint16
            j_off = jv.get("byteOffset", 0) + ja.get("byteOffset", 0)
            w_off = wv.get("byteOffset", 0) + wa.get("byteOffset", 0)
            joints = np.frombuffer(data, dtype=jt, count=n * 4, offset=j_off).reshape(n, 4)
            weights = np.frombuffer(data, dtype=np.float32, count=n * 4, offset=w_off).reshape(n, 4)
            cleaned, changed = own_leg_only(joints, weights, names)
            data[w_off:w_off + n * 16] = cleaned.astype(np.float32).tobytes()
            print("%s: %d of %d vertices" % (mesh["name"], changed, n))
            total += changed
    if total:
        open(bin_path, "wb").write(data)
        d.setdefault("asset", {}).setdefault("extras", {})["bin_md5"] = hashlib.md5(data).hexdigest()
        with open(path, "w") as f:
            json.dump(d, f, indent=1)


if __name__ == "__main__":
    main()
