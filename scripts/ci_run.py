#!/usr/bin/env python3
"""Run a build/test command and expose failures as GitHub check annotations.
This preserves the original exit status and helps when full log downloads
are not available to restricted-network workspaces.
"""
import subprocess
import sys
from collections import deque

def annotation(text):
    text=text.replace('%','%25').replace('\r','%0D').replace('\n','%0A')
    print('::error::'+text,flush=True)

command=sys.argv[1:]
if not command:
    raise SystemExit('Usage: ci_run.py COMMAND [ARGS...]')
print('+ '+' '.join(command),flush=True)
process=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
tail=deque(maxlen=55)
findings=[]
for line in process.stdout:
    print(line,end='',flush=True)
    tail.append(line.rstrip())
    if any(token in line for token in ['error •','warning •','ERROR|','WARNING|','Error:','error:','FAILURE:','What went wrong:','Could not resolve','[E]']):
        findings.append(line.rstrip())
code=process.wait()
if code:
    for finding in findings[-20:]:
        annotation(finding[:4000])
    annotation('Command failed: '+' '.join(command)+'\n'+'\n'.join(tail)[-9000:])
else:
    summary = 'Command passed: ' + ' '.join(command) + '\n' + '\n'.join(list(tail)[-12:])
    summary = summary[-2500:].replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
    print('::notice title=Build summary::' + summary, flush=True)
raise SystemExit(code)
