package version

import "testing"

func TestSGOrdering(t *testing.T) {
	for _, tc := range []struct {
		a, b string
		want int
	}{
		{"v3.1.0-sg3", "3.11.0-sg1", -1},
		{"v3.11.0-sg2", "3.11.0-sg1", 1},
		{"v3.11.0-sg1", "3.11.0-sg1", 0},
	} {
		got, ok := Compare(tc.a, tc.b)
		if !ok || got != tc.want {
			t.Fatalf("Compare(%q,%q)=(%d,%v)", tc.a, tc.b, got, ok)
		}
	}
}
