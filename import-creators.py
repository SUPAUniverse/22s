#!/usr/bin/env python3
"""
twentytwo — bulk creator importer.

Turns a CSV of creators into a .sql file you paste into the Supabase SQL editor.
Each creator becomes a CLAIMABLE profile: pre-created now, linked to the person
automatically when they first sign in with the matching email.

USAGE
  1. Fill in creators.csv (see creators-template.csv for the columns).
  2. python3 import-creators.py creators.csv > creators-import.sql
  3. Paste creators-import.sql into Supabase → SQL Editor → Run.

CSV COLUMNS (header row required; blanks are fine)
  name, handle, email, city, category, following, engagement, bio,
  brand1, brand2, brand3, brand4, brand5, brand6

NOTES
  - 'email' is the address the creator will claim the profile with (magic-link verified).
  - PUBLISH=False keeps profiles hidden ('reviewing') until you approve them.
    Set PUBLISH=True to drop them straight onto the public board ('approved').
"""
import csv, sys

PUBLISH = False  # False = hidden until approved; True = visible on the board immediately
STATUS = 'approved' if PUBLISH else 'reviewing'

def q(v):
    if v is None: return 'null'
    v = str(v).strip()
    if v == '': return 'null'
    return "'" + v.replace("'", "''") + "'"

def num(v, default='0'):
    v = (v or '').strip().replace(',', '')
    try:
        float(v); return v
    except ValueError:
        return default

def main(path):
    rows = list(csv.DictReader(open(path, newline='', encoding='utf-8-sig')))
    print("-- twentytwo creator import (%d profiles, status=%s)" % (len(rows), STATUS))
    print("begin;")
    for r in rows:
        g = lambda k: (r.get(k) or '').strip()
        handle = g('handle').lstrip('@')
        if not g('name') or not handle:
            sys.stderr.write("skipped row (needs name + handle): %r\n" % r); continue
        print(
            "insert into creators (name, handle, claim_email, claimed, status, city, category, bio, following, engagement, profile_completeness)\n"
            "values (%s, %s, %s, false, '%s', %s, %s, %s, %s, %s, 80)\n"
            "on conflict (handle) do nothing;" % (
                q(g('name')), q('@'+handle), q(g('email')), STATUS,
                q(g('city')), q(g('category')), q(g('bio')),
                num(g('following')), num(g('engagement'))
            )
        )
        # top six (only if any brand given)
        picks = [g('brand%d' % i) for i in range(1, 7)]
        if any(picks):
            print("with c as (select id from creators where handle = %s)" % q('@'+handle))
            vals = []
            for i, b in enumerate(picks, 1):
                if b:
                    vals.append("((select id from c), %d, %s, 'listed')" % (i, q(b)))
            if vals:
                print("insert into top_six (creator_id, rank, brand, status) values\n  " +
                      ",\n  ".join(vals) + "\non conflict (creator_id, rank) do nothing;")
    print("commit;")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit("usage: python3 import-creators.py creators.csv > creators-import.sql")
    main(sys.argv[1])
