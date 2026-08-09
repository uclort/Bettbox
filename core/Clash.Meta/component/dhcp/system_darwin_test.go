//go:build darwin

package dhcp

import (
	"net/netip"
	"slices"
	"testing"
)

func TestParseScopedDNS(t *testing.T) {
	output := `DNS configuration

resolver #1
  nameserver[0] : 223.5.5.5
  if_index : 12 (en0)
  flags    : Scoped, Request A records

resolver #2
  nameserver[0] : 10.255.18.3
  nameserver[1] : 10.255.18.4
  if_index : 10 (en5)
  flags    : Scoped, Request A records
`

	want := []netip.Addr{netip.MustParseAddr("10.255.18.3"), netip.MustParseAddr("10.255.18.4")}
	if got := parseScopedDNS(output, 10); !slices.Equal(got, want) {
		t.Fatalf("接口 DNS 不匹配：got %v, want %v", got, want)
	}
}
