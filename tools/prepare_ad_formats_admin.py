"""Stage existing admin sources against the deployed config metadata."""
import io
from pathlib import Path
import shutil
import subprocess
import tarfile

root=Path(__file__).resolve().parents[1]
stage=root/'.private/ad-formats-deploy'
client=stage/'client'
assert not client.exists()
client.mkdir()
archive=subprocess.check_output(['git','archive','b489c990','admin-console'],cwd=root)
with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
    tar.extractall(client,filter='data')
shared=stage/'production/remote-config-admin/functions/_shared'
shutil.copytree(shared,client/'supabase/functions/_shared')
print(client)
