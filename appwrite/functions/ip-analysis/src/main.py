import importlib.util
import sys
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
ROOT_MAIN = ROOT_DIR / "main.py"

if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

spec = importlib.util.spec_from_file_location("ip_analysis_appwrite_main", ROOT_MAIN)
if spec is None or spec.loader is None:
    raise RuntimeError("Unable to load root main.py")

module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

main = module.main
