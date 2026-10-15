"""Process pywin32's .pth bootstrap in the isolated embedded runtime."""
import site
import sys
from pathlib import Path

site.addsitedir(str(Path(sys.executable).parent / "Lib" / "site-packages"))
sys.dont_write_bytecode = True
