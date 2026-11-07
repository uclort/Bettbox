package tls

import (
	"sort"
)

func slicesConcat[S ~[]E, E any](slices ...S) S {
	size := 0
	for _, s := range slices {
		size += len(s)
		if size < 0 {
			panic("len out of range")
		}
	}
	// Use Grow, not make, to round up to the size class:
	// the extra space is otherwise unused and helps
	// callers that append a few elements to the result.
	newslice := slicesGrow[S](nil, size)
	for _, s := range slices {
		newslice = append(newslice, s...)
	}
	return newslice
}

func slicesGrow[S ~[]E, E any](s S, n int) S {
	if n < 0 {
		panic("cannot be negative")
	}
	if n -= cap(s) - len(s); n > 0 {
		// This expression allocates only once (see test).
		s = append(s[:cap(s)], make([]E, n)...)[:len(s)]
	}
	return s
}

func slicesEqual[S ~[]E, E comparable](s1, s2 S) bool {
	if len(s1) != len(s2) {
		return false
	}
	for i := range s1 {
		if s1[i] != s2[i] {
			return false
		}
	}
	return true
}

func slicesEqualFunc[S1 ~[]E1, S2 ~[]E2, E1, E2 any](s1 S1, s2 S2, eq func(E1, E2) bool) bool {
	if len(s1) != len(s2) {
		return false
	}
	for i, v1 := range s1 {
		v2 := s2[i]
		if !eq(v1, v2) {
			return false
		}
	}
	return true
}

func slicesClone[S ~[]E, E any](s S) S {
	// Preserve nil in case it matters.
	if s == nil {
		return nil
	}
	return append(S([]E{}), s...)
}

func slicesIndex[S ~[]E, E comparable](s S, v E) int {
	for i := range s {
		if v == s[i] {
			return i
		}
	}
	return -1
}

func slicesIndexFunc[S ~[]E, E any](s S, f func(E) bool) int {
	for i := range s {
		if f(s[i]) {
			return i
		}
	}
	return -1
}

func slicesContains[S ~[]E, E comparable](s S, v E) bool {
	return slicesIndex(s, v) >= 0
}

func slicesContainsFunc[S ~[]E, E any](s S, f func(E) bool) bool {
	return slicesIndexFunc(s, f) >= 0
}

func clearSlice[S ~[]E, E any](s S) {
	var zero E
	for i := range s {
		s[i] = zero
	}
}

func slicesDelete[S ~[]E, E any](s S, i, j int) S {
	_ = s[i:j:len(s)] // bounds check

	if i == j {
		return s
	}

	oldlen := len(s)
	s = append(s[:i], s[j:]...)
	clearSlice(s[len(s):oldlen]) // zero/nil out the obsolete elements, for GC
	return s
}

func slicesDeleteFunc[S ~[]E, E any](s S, del func(E) bool) S {
	i := slicesIndexFunc(s, del)
	if i == -1 {
		return s
	}
	// Don't start copying elements until we find one to delete.
	for j := i + 1; j < len(s); j++ {
		if v := s[j]; !del(v) {
			s[i] = v
			i++
		}
	}
	clearSlice(s[i:]) // zero/nil out the obsolete elements, for GC
	return s[:i]
}

func slicesSort[S ~[]E, E cmpOrdered](x S) {
	sort.Slice(x, func(i, j int) bool { return x[i] < x[j] })
}

func slicesSortFunc[S ~[]E, E any](x S, cmp func(a, b E) int) {
	sort.Slice(x, func(i, j int) bool { return cmp(x[i], x[j]) < 0 })
}

func slicesIsSorted[S ~[]E, E cmpOrdered](x S) bool {
	for i := len(x) - 1; i > 0; i-- {
		if cmpLess(x[i], x[i-1]) {
			return false
		}
	}
	return true
}

func slicesIsSortedFunc[S ~[]E, E any](x S, cmp func(a, b E) int) bool {
	for i := len(x) - 1; i > 0; i-- {
		if cmp(x[i], x[i-1]) < 0 {
			return false
		}
	}
	return true
}
