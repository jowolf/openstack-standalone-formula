#!/usr/bin/env python

# Copyright (c)Joseph J Wolff, 2011 all rights reserved, may also be included in GPLed packages
# New version for sectioned ini files, with state

import os, string, sys, time, shutil

# Semantics:
#
# - only one occurence per configfile - greedy, first one changed, rest ignored.
# - ini-style files only, with sections - keeps section state
# - separator is '=' (ini)
# - cannot use ConfigParser, as it reqites to whole file, rearranges the sections, and adds spaces
# - commenting out or removal NOT supported
# - does NOT ensure presence, does nothing if file not present
# - comparisons are case-sensitive
# - exactly one separator is allowed, no more, no less - no extraneous data at end of k,v pair on commandline
# - section is dot-separated - eg, Midnight-Commander.navigate_with_arrows=1

## globals

remove = False
trace = 1

## ensure input

if len (sys.argv) < 3:
  print 'Usage: python ensure_ini <fname> <section>.<configline>'
  sys.exit()


## get args

me = sys.argv [0]
fname = sys.argv [1]
cfg = sys.argv [2]

assert '.' in cfg, 'Must have section.item=value'

sec, itm = cfg.split ('.', 1)

if trace: print fname, cfg, sec, itm


## split out targeted name, value pair

sep = ''

for sep in ['=',':',' ','|','\t']:
  if len (itm.split (sep)) == 2:
    break

if not sep:
  raise Exception, "Config line type not supported - must have recognized name/value-pair separator"

nam,val = [s.strip() for s in itm.split (sep)]


## do the updates as needed

f = open (fname)
lines = f.readlines()
newlines = []
changed = False
section = ''

for line in lines:
  if line.strip().startswith ('[') and line.strip().endswith (']'):
    section = line.strip()[1:-1]
    newlines += [line]  # include section names
    continue

  if section != sec:
    newlines += [line]
    continue

  linetuple = [s.strip() for s in line.strip().split (sep, 1)]

  if len (linetuple) != 2:  # blank lines, comments, etc
    newlines += [line]
    continue

  linenam, lineval = linetuple

  if linenam == nam:
    if trace: print 'Found:', linenam, lineval
    if lineval != val:
      if trace: print 'Changing:', lineval, ' => ', val
      newlines += [nam + sep + val]
      changed = True
    else:
      newlines += [line]
  else:
    newlines += [line]


if not changed:
  if trace: print 'No changes needed'
  sys.exit()


## normalize the line endings - python sucks

newlines = [(l if l[-1]=='\n' else l+'\n') for l in newlines]


## backup the old and save the new file

# os.rename (fname, fname+'~')
shutil.copyfile (fname, fname+'~')

open (fname, 'w').writelines (newlines)

