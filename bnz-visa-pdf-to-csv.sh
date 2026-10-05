#!/bin/bash
# Convert a BNZ Visa statement PDF to CSV with columns: date,merchant,amount
# Debits are positive, credits (refunds) are negative, and card payments
# ("PAYMENT - THANK YOU") are skipped.
set -euo pipefail

if [ $# -ne 1 ] || [ ! -f "$1" ]; then
    echo "usage: $(basename "$0") statement.pdf" >&2
    exit 1
fi

pdftotext -layout "$1" - | awk '
# Quote a CSV field only when it contains a comma or double quote.
function csv(s) {
    if (s ~ /[",]/) {
        gsub(/"/, "\"\"", s)
        s = "\"" s "\""
    }
    return s
}

# Each transactions page has its own column header. Remember where the debit
# and credit columns end: amounts are right-aligned under them, so an amount
# ending past the midpoint between the two is a credit.
/Debit amount \$ +Credit amount \$/ {
    debit_end = index($0, "Debit amount $") + length("Debit amount $") - 1
    credit_end = index($0, "Credit amount $") + length("Credit amount $") - 1
    split_col = (debit_end + credit_end) / 2
    next
}

# Transaction lines start with an ordinal date, e.g. "3rd September".
match($0, /^ *[0-9][0-9]?(st|nd|rd|th) (January|February|March|April|May|June|July|August|September|October|November|December) /) {
    date_end = RSTART + RLENGTH - 1
    date = substr($0, 1, date_end)
    gsub(/^ +| +$/, "", date)

    if (!match($0, /\$[0-9,]+\.[0-9][0-9] *$/)) {
        print "warning: no amount found, skipping: " $0 > "/dev/stderr"
        next
    }
    if (!split_col) {
        print "error: transaction before column header: " $0 > "/dev/stderr"
        exit 1
    }
    amount = substr($0, RSTART)
    sub(/ +$/, "", amount)
    amount_end = RSTART + length(amount) - 1
    gsub(/[$,]/, "", amount)
    if (amount_end > split_col)
        amount = "-" amount

    # Between the date and amount is an optional category then the merchant,
    # separated by a wide gap.
    middle = substr($0, date_end + 1, RSTART - date_end - 1)
    gsub(/^ +| +$/, "", middle)
    n = split(middle, parts, /   +/)
    merchant = parts[n]

    if (merchant == "PAYMENT - THANK YOU")
        next

    print csv(date) "," csv(merchant) "," amount
}
'
