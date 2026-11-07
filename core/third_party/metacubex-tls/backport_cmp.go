package tls

type cmpOrdered interface {
	~int | ~int8 | ~int16 | ~int32 | ~int64 |
		~uint | ~uint8 | ~uint16 | ~uint32 | ~uint64 | ~uintptr |
		~float32 | ~float64 |
		~string
}

func cmpLess[T cmpOrdered](x, y T) bool {
	return (isNaN(x) && !isNaN(y)) || x < y
}

func cmpCompare[T cmpOrdered](x, y T) int {
	xNaN := isNaN(x)
	yNaN := isNaN(y)
	if xNaN {
		if yNaN {
			return 0
		}
		return -1
	}
	if yNaN {
		return +1
	}
	if x < y {
		return -1
	}
	if x > y {
		return +1
	}
	return 0
}

func isNaN[T cmpOrdered](x T) bool {
	return x != x
}

func cmpOr[T comparable](vals ...T) T {
	var zero T
	for _, val := range vals {
		if val != zero {
			return val
		}
	}
	return zero
}
