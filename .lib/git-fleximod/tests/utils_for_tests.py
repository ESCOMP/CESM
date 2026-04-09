"""
Helper functions that can be used in tests
"""


def normalize_whitespace(text):
    """
    Normalize whitespace for flexible string comparisons in tests.

    This removes leading and trailing whitespace and collapses other whitespace down to a
    single space.
    """
    return " ".join(text.split())
