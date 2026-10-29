from importlib.metadata import distributions
from pathlib import Path
import re
import shutil
import sys

target = Path("docs/licenses/python")
target.mkdir(parents=True, exist_ok=True)
for distribution in distributions():
    name = re.sub(r"[^a-zA-Z0-9_.-]", "_", distribution.metadata["Name"])
    for item in distribution.files or []:
        if "licenses" in item.parts or item.name.upper().startswith(("LICENSE", "COPYING", "NOTICE")):
            source = Path(distribution.locate_file(item))
            if source.is_file():
                destination = target / name / item.name
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, destination)
python_license = Path(sys.base_prefix) / "LICENSE.txt"
if python_license.exists(): shutil.copy2(python_license, target / "python-license.txt")
