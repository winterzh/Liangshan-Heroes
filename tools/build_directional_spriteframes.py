"""Reproduce SpriteFrames from an authored direction4 manifest; never edit PNGs.

Default checks existing files. --write updates only the character's exact .tres
paths listed in the manifest. Import dimensions must be verified by Godot first.
"""
from pathlib import Path
import argparse, hashlib, json, math, re

ROOT = Path(__file__).resolve().parents[1]
DIRECTIONS = ('se', 'sw', 'ne', 'nw')


def identifier(value):
    if not isinstance(value, str) or not re.fullmatch(r'[a-z][a-z0-9_]*', value):
        raise ValueError('Invalid resource identifier')
    return value


def asset_path(value):
    path = (ROOT / value).resolve()
    if not path.is_relative_to((ROOT / 'assets').resolve()):
        raise ValueError('Resource path must stay inside assets')
    return path


def numbers(values):
    if not all(isinstance(v, (int, float)) and math.isfinite(v) for v in values):
        raise ValueError('Frame coordinates must be finite numbers')
    return ', '.join(str(round(v, 6)) for v in values)


def render(manifest):
    character = identifier(manifest['character'])
    sources, poses = manifest['sources'], manifest['poses']
    for key, source in sources.items():
        identifier(key)
        path = asset_path(source['path'])
        if hashlib.sha256(path.read_bytes()).hexdigest() != source['sha256']:
            raise ValueError('Native source hash mismatch: ' + source['path'])
    for key, pose in poses.items():
        identifier(key)
        x, y, width, height = pose['region']
        source = sources[pose['source']]
        imported_w, imported_h = source['imported_size']
        left, top, pad_w, pad_h = pose['margin']
        draw_scale = pose.get('draw_scale', 1.0)
        numbers([x, y, width, height, left, top, pad_w, pad_h, *pose['draw_offset_px'], draw_scale])
        if not 0.25 <= draw_scale <= 4.0:
            raise ValueError('Authored draw scale outside supported range: ' + key)
        if min(x, y, left, top, pad_w, pad_h) < 0 or min(width, height) <= 0:
            raise ValueError('Negative/outside frame bounds: ' + key)
        if x + width > imported_w or y + height > imported_h or width + pad_w != height + pad_h:
            raise ValueError('Frame must fit the imported texture and padded square: ' + key)
    outputs = {}
    for direction in DIRECTIONS:
        for state, order in manifest['states'].items():
            identifier(state)
            if not order:
                raise ValueError('An action needs at least one authored frame')
            pose_keys = [identifier(value) + '_' + direction for value in order]
            unique = list(dict.fromkeys(pose_keys))
            source_keys = list(dict.fromkeys(poses[key]['source'] for key in unique))
            text = f'[gd_resource type="SpriteFrames" load_steps={len(source_keys)+len(unique)+1} format=3]\n\n'
            for key in source_keys:
                text += f'[ext_resource type="Texture2D" path="res://{sources[key]["path"]}" id="{key}"]\n\n'
            for key in unique:
                p = poses[key]
                text += f'[sub_resource type="AtlasTexture" id="{key}"]\natlas = ExtResource("{p["source"]}")\nregion = Rect2({numbers(p["region"])})\nmargin = Rect2({numbers(p["margin"])})\nfilter_clip = true\nmetadata/draw_offset_px = Vector2({numbers(p["draw_offset_px"])})\nmetadata/authored_direction4 = true\n\n'
                if p.get('draw_scale', 1.0) != 1.0:
                    text = text[:-1] + 'metadata/draw_scale = ' + numbers([p['draw_scale']]) + '\n\n'
            frames = ',\n'.join('{"duration": 1.0, "texture": SubResource("' + key + '")}' for key in pose_keys)
            text += '[resource]\nanimations = [{\n"frames": [\n' + frames + '\n],\n"loop": ' + ('false' if state in ('death', 'down') else 'true') + ',\n"name": &"default",\n"speed": 4.0\n}]\n'
            outputs[f'assets/anim/{character}_{state}_{direction}.tres'] = text
    if set(outputs) != set(manifest['resources']):
        raise ValueError('Manifest resources differ from generated character paths')
    return outputs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    outputs = render(json.loads(args.manifest.read_text(encoding='utf-8')))
    differences = []
    for relative, content in outputs.items():
        path = asset_path(relative)
        if args.write:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding='utf-8', newline='\n')
        elif not path.is_file() or path.read_text(encoding='utf-8') != content:
            differences.append(relative)
    print(json.dumps({'resources': len(outputs), 'written': args.write, 'differences': differences}))
    return 1 if differences else 0


if __name__ == '__main__':
    raise SystemExit(main())
