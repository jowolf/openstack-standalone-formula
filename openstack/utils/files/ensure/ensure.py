#!/usr/bin/env python

# Copyright (c)Joseph J Wolff, 2002-2011 all rights reserved, may also be included in GPLed packages
# Originally from circa 2002, from /backups/joe-laptop/home/joe/scripts/ensure.py

import os, string, sys, time, shutil

# Semantics:
#
# - only one occurence per configfile - greedy, first one changed, rest ignored.
# - limited support for different configfile formats - ini supported
# - separators are '=' (ini), ':' (yaml or equiv), space (other).
# - spaces in cfg parm must therefore be quoted
# - # at front means to ensure commented out - so the v of k,v pair doesn't matter, but separator is still required to determine filetype
# - comment char is assumed to be '#'
# - cfg parm passed to this fn has no (secondary) comments
# - comparisons are case-sensitive
# - exactly one separator is allowed, no more, no less - no extraneous data at end of k,v pair on commandline
# - extraneous (comment) data after val on k,v pair in file gets replaced - assumed to be part of val - comments are eliminated.

## globals

remove = False
trace = 1

## ensure input

if len (sys.argv) < 3:
  print 'Usage: python ensure <fname> <configline>'
  sys.exit()


## get args

me = sys.argv [0]
fname = sys.argv [1]
cfg = sys.argv [2]

if trace: print fname, cfg


## ensure present

if not os.path.exists (fname):
  open (fname, 'w').write (cfg + '\n')
  sys.exit()  # success


## determine action

if cfg.startswith ('#'):
  cfg = cfg [1:]
  remove = True

#if len (cfg.split ('=')) == 2:
#  typ = 'ini'
#elif len (cfg.split (':')) == 2:
#  typ = 'yml'
#  sep =
#else:


## split out targeted name, value pair

sep = ''

for sep in ['=',':',' ','|','\t']:
  if len (cfg.split (sep, 1)) == 2:
    break

if not sep:
  raise Exception, "Config line type not supported - must have recognized name/value-pair separator"

nam,val = [s.strip() for s in cfg.split (sep)]


## do the updates as needed

f = open (fname)
lines = f.readlines()
newlines = []
found = False
changed = False

for line in lines:
  linetuple = [s.strip() for s in line.strip().split (sep, 1)]

  if len (linetuple) != 2:  # blank lines, section names, etc
    newlines += [line]
    continue

  linenam, lineval = linetuple
  commented = False

  if linenam.startswith ('#'):  # it's a commented out tuple, check it for a match
    commented = True
    linenam = linenam.strip (' \t#')

  if linenam == nam:
    if trace: print 'Found:', linenam, lineval
    found = True

    # logic summary (should use truth table mechanism):
    #
    #if commented:
    #  if remove:
    #    leave alone - it's already done
    #  else:
    #    uncomment it & set to value
    #else:
    #  if remove:
    #    comment it out
    #  else:
    #    if val matches:
    #      leave it alone, it's done
    #    else
    #      set to new value

    if remove and not commented:
      newlines += ["# commented out by ensure.py " + time.ctime(), '#' + line]
      changed = True
    elif (lineval != val and not commented) or (commented and not remove):
      changed = True
      newlines += ["# updated by ensure.py " + time.ctime(), nam + sep + val]  # old line not saved nor commented!
      if trace: print 'replaced', line
  else:
    newlines += [line]

if not remove and not found:
  changed = True
  newlines += ["# added by ensure.py " + time.ctime(), nam + sep + val]

if not changed:
  if trace: print 'No changes needed'
  sys.exit()


## normalize the line endings - python sucks

newlines = [(l if l[-1]=='\n' else l+'\n') for l in newlines]


## backup the old and save the new file

# os.rename (fname, fname+'~')
shutil.copyfile (fname, fname+'~')

open (fname, 'w').writelines (newlines)

sys.exit()





## old:
old='''
  open (fname, 'r+w')
  newlines= []

  for line in f:
    if line.startswith (cfg):
      newlines = ["#" + lin + '\n']
      changed = 1
    else
      newlines += [line]

  if not changed:
    newlines += ['#' + cfg]

  f.seek (0)
  f.writelines (newlines)

else:
  cfgname = string.split (cfg, '=') [0]
  f = open (fname, 'r+w')
  lines = f.readlines()
  changed = 0

  for i in range (len (lines)):
    if lines [i] [-1] != '\n':  # normalize
      lines [i] += '\n'

    line = lines [i]
    lname = string.split (line, '=') [0]

    if string.lower (lname) == string.lower (cfgname):
      lines [i] = '#%s%s\n' % (line, cfg)
      changed = 1

  if not changed:
    lines += [cfg]

  f.seek (0)
  f.writelines (lines)

f.close()
'''
