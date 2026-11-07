#!/usr/bin/env python3
"""Optional tree-sitter syntax check. Does NOT replace Flutter/native builds.
Install tree-sitter, tree-sitter-dart, tree-sitter-kotlin, tree-sitter-swift.
"""
from pathlib import Path
from tree_sitter import Language, Parser
import tree_sitter_dart
import tree_sitter_kotlin
import tree_sitter_swift

root=Path(__file__).resolve().parents[1]
errors=[];count=0
for ext,grammar,folders in [('dart',tree_sitter_dart,['lib','test']),('kt',tree_sitter_kotlin,['android','test/native']),('swift',tree_sitter_swift,['ios'])]:
    parser=Parser(Language(grammar.language()))
    for folder in folders:
        for file in (root/folder).rglob(f'*.{ext}'):
            raw=file.read_bytes();count+=1
            def inspect(node):
                if node.type=='ERROR' or node.is_missing:
                    errors.append(f'{file.relative_to(root)}:{node.start_point.row+1}: {node.type}')
                for child in node.children: inspect(child)
            inspect(parser.parse(raw).root_node)
assert not errors, '\n'.join(errors)
print(f'PASS: {count} Dart/Kotlin/Swift files parsed with zero syntax errors. Type checking and device testing still required.')
