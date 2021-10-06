#! /bin/python

import sys, re

for markdown in sys.argv[1:]:
    with open(markdown) as f:
        block_num = 1
        in_block = False
        header = ''
        for line in f.readlines():
            line = line.rstrip()
            match = re.match('^#+\s+(.*)', line)
            # Use markdown headers to 'localize' block numbers
            if match:
                header = match.group(1).lower().replace(' ', '-')
                block_num = 1
            elif line == '```console':
                print('function {}-{}-block{} {{'.format(markdown, header, block_num))
                in_block = True
            elif line == '```':
                print('}')
                block_num += 1
                in_block = False
            elif in_block:
                print('    '+line)
