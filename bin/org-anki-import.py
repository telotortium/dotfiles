#!/usr/bin/env python3
import csv
import re
import sys
import subprocess

DRILL_TAG = 'drill'
AROUND_GROUP = 'around'
INNER_GROUP = 'inner'
SPAN_RE = re.compile(r'(?P<{}><span class=cloze>(?P<{}>.*?)</span>)'.format(
    AROUND_GROUP, INNER_GROUP))
ORG_DRILL_LEFT_CLOZE_DELIMITER = '!|'
ORG_DRILL_RIGHT_CLOZE_DELIMITER = '|!'


def main(argv):
    if len(argv) != 2:
        sys.exit("Usage: {} [anki-exported-tsv-file]".format(argv[0]))
    tsv = argv[1]
    with open(tsv) as f:
        raw_rows = [x for x in csv.reader(f, dialect='excel-tab')]
    cloze_copies = {}
    flip_rows = []
    for i, row in enumerate(raw_rows):
        if len(row) != 2:
            print("Line {} has an unexpected number of fields, {}".format(
                i + 1, len(row)),
                  file=sys.stderr)
            continue
        if SPAN_RE.search(row[0]):
            text = row[1]
            spanless_text = SPAN_RE.sub(r'\g<{}>'.format(INNER_GROUP), text)
            if not spanless_text in cloze_copies:
                cloze_copies[spanless_text] = []
            cloze_copies[spanless_text].append(text)
        else:
            flip_rows.append(row)
    clozes = [merge_cloze_copies(cloze) for cloze in cloze_copies.values()]
    for cloze in clozes:
        print(generate_cloze(cloze))
    for row in flip_rows:
        print(generate_flip(row))


def merge_cloze_copies(cloze_copies):
    """Merge copies of a single cloze item from Anki HTML export.

    The input is a list of HTML snippets generated from a single cloze. Each
    HTML snippet will be identical except that in each copy, some span elements
    with the 'cloze' class will be replaced with just their contents, without
    the surrounding span element. The output will consist of a copy of the
    cloze with all such span elements encountered in any of the input copies
    present together in the output.
    """
    copies = cloze_copies
    if not copies:
        return []
    parts = []
    while True:
        matches = [SPAN_RE.search(copy) for copy in copies]
        min_match = None
        min_match_indexes = None
        for i, match in enumerate(matches):
            if match is None:
                continue
            if min_match is None or match.start(
                    AROUND_GROUP) < min_match.start(AROUND_GROUP):
                min_match = match
                min_match_indexes = {i}
            elif match.start(AROUND_GROUP) == min_match.start(AROUND_GROUP):
                min_match_indexes |= i
        if not min_match:
            parts.append(copies[0])
            break
        first_match_index = sorted(min_match_indexes)[0]
        parts.append(copies[first_match_index][:min_match.start(AROUND_GROUP)])
        parts.append(copies[first_match_index][min_match.start(AROUND_GROUP):
                                               min_match.end(AROUND_GROUP)])
        new_copies = []
        for i, copy in enumerate(copies):
            if i in min_match_indexes:
                new_copies.append(copy[min_match.end(AROUND_GROUP):])
            else:
                new_copies.append(copy[min_match.start(AROUND_GROUP) + (
                    min_match.end(INNER_GROUP) - min_match.start(INNER_GROUP)
                ):])
        copies = new_copies
    return ''.join(parts)


def generate_cloze(cloze_html):
    """Generate a org-mode item containing an org-drill cloze card."""
    org = html_to_org(SPAN_RE.sub(r'{}\g<{}>{}'.format(
        ORG_DRILL_LEFT_CLOZE_DELIMITER, INNER_GROUP,
        ORG_DRILL_RIGHT_CLOZE_DELIMITER), cloze_html))
    return r'''
* Item               :{}:
  :PROPERTIES:
  :DRILL_CARD_TYPE: hide1cloze
  :END:
{}
'''.format(DRILL_TAG, org)[1:]  # Slice to remove leading newline character


NOTE_SEP_RE = re.compile(r'^==$', re.MULTILINE)

def generate_flip(row):
    """Generate a org-mode item containing an org-drill flip card."""
    # The expanded clozes live in row[1]. row[0] is unused.
    front = html_to_org(row[0])
    back = html_to_org(row[1])
    org = r'''
* Item               :{}:
  :PROPERTIES:
  :DRILL_CARD_TYPE: twosided
  :END:

** Front
{}

** Back
{}
'''.format(DRILL_TAG, front,
           back)[1:]  # Slice to remove leading newline character
    return NOTE_SEP_RE.sub('** Note', org)



def html_to_org(html):
    return subprocess.check_output(['pandoc', '-f', 'html', '-t', 'org'],
                                   input=html,
                                   universal_newlines=True)


if __name__ == '__main__':
    main(sys.argv)
