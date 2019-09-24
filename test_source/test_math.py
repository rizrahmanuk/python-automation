import unittest


class MyTestCase(unittest.TestCase):
    def test_something(self):
        self.assertNotEqual(True, False)

    def test_addition(self):
        assert 1 + 1 == 2

if __name__ == '__main__':
    unittest.main()
