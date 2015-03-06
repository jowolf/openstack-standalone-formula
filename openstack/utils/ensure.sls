/usr/local/bin/ensure.py:
  file.managed:
    - source: salt://openstack/utils/files/ensure/ensure.py
    - user: root
    - group: root
    - mode: 755


# This works, but has limitations - see "Semantics" at top of file - JJW

#/usr/local/bin/ensure_ini.py:
#  file.managed:
#    - source: salt://ensure/ensure_ini.py
#    - user: root
#    - group: root
#    - mode: 755

# This one is very simple - can likely use salt's file.append instead - JJW

#/usr/local/bin/ensure_line.sh:
#  file.managed:
#    - source: salt://ensure/ensure_line.sh
#    - user: root
#    - group: root
#    - mode: 755

