package adapter

import "context"

type UrlTestCheck func(url string, name string, delay uint16)

var UrlTestHook UrlTestCheck

// BETTBOX-CUSTOM: correlate app and provider delay tests with network-stage diagnostics.
type URLTestTrace struct {
	ID      string
	Source  string
	BatchID string
}

type urlTestTraceContextKey struct{}

func WithURLTestTrace(ctx context.Context, trace URLTestTrace) context.Context {
	return context.WithValue(ctx, urlTestTraceContextKey{}, trace)
}

func URLTestTraceFromContext(ctx context.Context) URLTestTrace {
	trace, _ := ctx.Value(urlTestTraceContextKey{}).(URLTestTrace)
	return trace
}
