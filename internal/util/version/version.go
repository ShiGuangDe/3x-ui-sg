// Package version compares 3x-ui release versions ("v3.8.0" or "3.8.0").
package version

import (
	"strconv"
	"strings"
)

// Compare returns -1, 0 or 1 as a is older than, equal to or newer than b, and
// false when either side is not a plain MAJOR.MINOR.PATCH version.
func Compare(a, b string) (int, bool) {
	aBase, aSG, okASG := splitSG(a)
	bBase, bSG, okBSG := splitSG(b)
	if !okASG || !okBSG {
		return 0, false
	}
	aParts, okA := parse(aBase)
	bParts, okB := parse(bBase)
	if !okA || !okB {
		return 0, false
	}
	for i := range len(aParts) {
		if aParts[i] > bParts[i] {
			return 1, true
		}
		if aParts[i] < bParts[i] {
			return -1, true
		}
	}
	if aSG > bSG {
		return 1, true
	}
	if aSG < bSG {
		return -1, true
	}
	return 0, true
}

// Normalize strips surrounding space and a leading "v" from a version tag.
func Normalize(v string) string {
	return strings.TrimPrefix(strings.TrimSpace(v), "v")
}

func parse(v string) ([3]int, bool) {
	var result [3]int
	parts := strings.Split(Normalize(v), ".")
	if len(parts) != 3 {
		return result, false
	}
	for i, part := range parts {
		n, err := strconv.Atoi(part)
		if err != nil {
			return result, false
		}
		result[i] = n
	}
	return result, true
}

// splitSG keeps official versions valid while ordering the fork's revisions.
func splitSG(v string) (string, int, bool) {
	base, suffix, found := strings.Cut(Normalize(v), "-sg")
	if !found {
		return base, 0, true
	}
	if suffix == "" {
		return "", 0, false
	}
	for _, c := range suffix {
		if c < '0' || c > '9' {
			return "", 0, false
		}
	}
	n, err := strconv.Atoi(suffix)
	return base, n, err == nil
}
