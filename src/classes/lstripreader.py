class LstripReader(object):
    "LstripReader formats .gitmodules files to be acceptable for configparser"

    def __init__(self, filename):
        with open(filename, "r") as infile:
            lines = infile.readlines()
        self._lines = list()
        self._num_lines = len(lines)
        self._index = 0
        for line in lines:
            self._lines.append(line.lstrip())

    def readlines(self):
        """Return all the lines from this object's file"""
        return self._lines

    def readline(self, size=-1):
        """Format and return the next line or raise StopIteration"""
        try:
            line = self.next()
        except StopIteration:
            line = ""

        if (size > 0) and (len(line) < size):
            return line[0:size]

        return line

    def __iter__(self):
        """Begin an iteration"""
        self._index = 0
        return self

    def next(self):
        """Return the next line or raise StopIteration"""
        if self._index >= self._num_lines:
            raise StopIteration

        self._index = self._index + 1
        return self._lines[self._index - 1]

    def __next__(self):
        return self.next()
