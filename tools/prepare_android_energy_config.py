"""Offline Android-only config merge. Does not upload, publish or contact services."""
import argparse
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True, help='Fresh effective config/snapshot downloaded by the operator')
    parser.add_argument('--output', type=Path, required=True, help='New candidate JSON; input is never overwritten')
    parser.add_argument('--enable', action='store_true', help='Prepare enabled candidate only after explicit rollout approval')
    args = parser.parse_args()
    if args.input.resolve() == args.output.resolve():
        parser.error('Use a separate output file')
    if args.output.exists():
        parser.error('Output must be a new file')
    raw = json.loads(args.input.read_text(encoding='utf-8-sig'))
    original = raw.get('config', raw)
    if not isinstance(original, dict) or not isinstance(original.get('economy'), dict):
        parser.error('Expected an effective gameplay configuration')
    candidate = copy.deepcopy(original)
    defaults = json.loads((ROOT / 'telegram-web/config/gameplay-config.json').read_text(encoding='utf-8-sig'))
    block = copy.deepcopy(defaults['economy']['androidEnergyV2'])
    block['enabled'] = args.enable
    candidate['economy']['androidEnergyV2'] = block
    check = copy.deepcopy(candidate)
    check['economy'].pop('androidEnergyV2', None)
    expected = copy.deepcopy(original)
    expected['economy'].pop('androidEnergyV2', None)
    if check != expected:
        raise RuntimeError('Non-Android configuration changed')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(candidate, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'ok': True, 'enabled': args.enable, 'onlyChanged': 'economy.androidEnergyV2'}, ensure_ascii=False))


if __name__ == '__main__':
    main()
