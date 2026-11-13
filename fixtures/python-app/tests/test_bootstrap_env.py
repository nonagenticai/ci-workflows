import os

import pytest


@pytest.mark.integration
def test_db_bootstrap_env_reaches_the_test_process() -> None:
    """The workflow runs db_bootstrap_cmd in the SAME shell as this pytest process.

    A bootstrap in a step of its own exports into a shell that has already exited, which is
    exactly the defect this test covers (coding-analysis, run 43414596003 — the integration
    pass ran without the DSN its bootstrap exported).
    """
    assert os.environ.get("SELFTEST_BOOTSTRAP") == "1"
