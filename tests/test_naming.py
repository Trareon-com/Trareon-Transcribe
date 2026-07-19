from export.naming import slugify


def test_slugify():
    assert slugify("Stand Up Meeting!") == "stand-up-meeting"
    assert slugify("") == "rapat"
