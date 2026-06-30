import pytest


@pytest.mark.skip(reason="flaky — disabled instead of fixed")
def test_skipped():
    assert True


@pytest.mark.xfail
def test_expected_to_fail():
    assert False
