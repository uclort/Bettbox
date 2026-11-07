//go:build go1.26

package tls

import "errors"

func errorsAsType[E error](err error) (E, bool) {
	return errors.AsType[E](err)
}
