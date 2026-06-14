#!/usr/bin/env python3


import unittest

from engrave import depluralize


class TestDepluralize(unittest.TestCase):
    def test_empty(self):
        self.assertEqual(depluralize({}), {})

    def test_listy(self):
        self.assertEqual(
            depluralize(
                {
                    "font": [1, 2, "", 3, 4],
                    "color": [5, 6, 7, 8, ""],
                }
            ),
            {
                0: {"font": 1, "color": 5},
                1: {"font": 2, "color": 6},
                2: {"color": 7},
                3: {"font": 3, "color": 8},
                4: {"font": 4},
            },
        )

    def test_dicty(self):
        self.assertEqual(
            depluralize(
                {
                    "font": {"0": "ooba", "3": "gaba!"},
                    "color": {"2": "nerpy", "1": "derpy", "3": "puce"},
                }
            ),
            {
                0: {"font": "ooba"},
                1: {"color": "derpy"},
                2: {"color": "nerpy"},
                3: {"font": "gaba!", "color": "puce"},
            },
        )

    def test_mixy(self):
        self.assertEqual(
            depluralize(
                {
                    "font": ["a", "b", "c"],
                    "color": {"1": "yes"},
                }
            ),
            {
                0: {"font": "a"},
                1: {"font": "b", "color": "yes"},
                2: {"font": "c"},
            },
        )


if __name__ == "__main__":
    unittest.main()
