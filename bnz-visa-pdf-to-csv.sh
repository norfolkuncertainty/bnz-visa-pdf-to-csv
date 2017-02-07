#!/bin/bash
pdftotext -layout $1 - | egrep 'January|February|March|April|May|June|July|August|September|October|November|December' | egrep -v '20[1-9][0-9]' | egrep -v "PAYMENT - THANK YOU"|  sed -e 's/^[ \t]*//' -e 's/   \+/,/g' -e 's/\$//g'
