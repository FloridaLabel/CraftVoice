#!/usr/bin/env python3
"""Explicit, one-time provisioning. Never imported or executed by the app.
Only official pinned sources; all model files stay in the permanent model folder.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
from pathlib import Path
import subprocess
from urllib.parse import quote

MODEL_REPO = 'argmaxinc/whisperkit-coreml'
MODEL_REVISION = '0f63a7800b00dd0226abd051b906c246e1907482'
MODEL_PREFIX = 'openai_whisper-large-v3-v20240930_turbo/'
TOKENIZER_REPO = 'openai/whisper-large-v3-turbo'
TOKENIZER_REVISION = '41f01f3fe87f28c78e2fbf8b568835947dd65ed9'
TOKENIZER_FILES = {'tokenizer.json', 'tokenizer_config.json', 'added_tokens.json',
    'special_tokens_map.json', 'merges.txt', 'vocab.json', 'config.json',
    'generation_config.json', 'preprocessor_config.json'}
DEFAULT = Path.home() / 'Library/Application Support/CraftVoice/Models/large-v3-turbo'

def metadata(repo, revision):
    url = 'https://huggingface.co/api/models/' + repo + '/revision/' + revision + '?blobs=true'
    data = subprocess.check_output(['/usr/bin/curl', '--fail', '--silent', '--show-error', '--location', '--retry', '3', url])
    result = json.loads(data)
    if result['sha'] != revision: raise RuntimeError('Source revision mismatch')
    return result

def hashes(path):
    size = path.stat().st_size
    sha256 = hashlib.sha256()
    git = hashlib.sha1(('blob ' + str(size) + '\0').encode())
    with path.open('rb') as stream:
        while block := stream.read(8 * 1024 * 1024):
            sha256.update(block); git.update(block)
    return size, sha256.hexdigest(), git.hexdigest()

def verify(path, entry):
    size, sha256, git = hashes(path)
    if size != entry['size']: raise RuntimeError('Size mismatch: ' + str(path))
    expected = entry.get('lfsSha256')
    if (expected and sha256 != expected) or (not expected and git != entry['gitBlob']):
        raise RuntimeError('Hash mismatch: ' + str(path))
    if entry.get('sha256') and sha256 != entry['sha256']: raise RuntimeError('Local SHA-256 mismatch')
    return sha256

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--folder', type=Path, default=DEFAULT)
    parser.add_argument('--verify-only', action='store_true')
    args = parser.parse_args()
    folder = args.folder.expanduser().resolve()
    manifest_path = folder / 'craftvoice-model-manifest.json'
    if args.verify_only:
        manifest = json.loads(manifest_path.read_text())
        if manifest['status'] != 'complete': raise RuntimeError('Incomplete manifest')
        for entry in manifest['files']: verify(folder / entry['path'], entry)
        print('VERIFIED ' + str(len(manifest['files'])) + ' files, ' + str(sum(x['size'] for x in manifest['files'])) + ' bytes', flush=True)
        return
    model = metadata(MODEL_REPO, MODEL_REVISION)
    tokenizer = metadata(TOKENIZER_REPO, TOKENIZER_REVISION)
    entries = []
    for repo, revision, siblings, prefix in [(MODEL_REPO, MODEL_REVISION, model['siblings'], MODEL_PREFIX),
        (TOKENIZER_REPO, TOKENIZER_REVISION, tokenizer['siblings'], '')]:
        for item in siblings:
            name = item['rfilename']
            if prefix and not name.startswith(prefix): continue
            if not prefix and name not in TOKENIZER_FILES: continue
            path = name[len(prefix):]
            # Keep Argmax metadata separate from OpenAI tokenizer metadata.
            if prefix and '/' not in path: path = 'coreml-metadata/' + path
            if Path(path).is_absolute() or '..' in Path(path).parts: raise RuntimeError('Unsafe source path')
            entries.append(dict(path=path, repo=repo, revision=revision, sourcePath=name,
                size=item['size'], gitBlob=item['blobId'], lfsSha256=item.get('lfs', {}).get('sha256')))
    if len([x for x in entries if x['repo'] == MODEL_REPO]) != 24: raise RuntimeError('Unexpected model file inventory')
    if {x['path'] for x in entries if x['repo'] == TOKENIZER_REPO} != TOKENIZER_FILES: raise RuntimeError('Tokenizer inventory incomplete')
    if len({x['path'] for x in entries}) != len(entries): raise RuntimeError('Duplicate destination paths')
    folder.mkdir(parents=True, exist_ok=True)
    manifest = dict(schema=1, whisperKitVersion='1.1.1', status='incomplete', model=MODEL_PREFIX.rstrip('/'), files=entries)
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    print('DESTINATION ' + str(folder), flush=True)
    print('EXPECTED ' + str(len(entries)) + ' files, ' + str(sum(x['size'] for x in entries)) + ' bytes', flush=True)
    def fetch(entry):
        path = folder / entry['path']
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.exists():
            partial = path.with_name(path.name + '.partial')
            url = 'https://huggingface.co/' + entry['repo'] + '/resolve/' + entry['revision'] + '/' + quote(entry['sourcePath'], safe='/')
            subprocess.run(['/usr/bin/curl', '--fail', '--silent', '--show-error', '--location',
                '--retry', '3', '--retry-all-errors', '--connect-timeout', '30', '--max-time', '1800',
                '--output', str(partial), url], check=True)
            verify(partial, entry)
            partial.replace(path)
        entry['sha256'] = verify(path, entry)
        return entry
    with ThreadPoolExecutor(max_workers=4) as pool:
        for future in as_completed([pool.submit(fetch, entry) for entry in entries]):
            entry = future.result()
            print('VERIFIED ' + entry['path'] + ' ' + str(entry['size']), flush=True)
    manifest['status'] = 'complete'
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    print('COMPLETE ' + str(folder), flush=True)

if __name__ == '__main__': main()
