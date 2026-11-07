//go:build go1.21

package tls

import "context"

var contextAfterFunc = context.AfterFunc
