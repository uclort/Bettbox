package dns

import (
	"context"
	"errors"
	"testing"
	"time"

	D "github.com/miekg/dns"
)

var errInterfaceDNSFailed = errors.New("接口 DNS 请求失败")

type failingInterfaceDNSClient struct {
	reset bool
}

func (c *failingInterfaceDNSClient) ExchangeContext(context.Context, *D.Msg) (*D.Msg, error) {
	return nil, errInterfaceDNSFailed
}

func (c *failingInterfaceDNSClient) Address() string {
	return "失败的接口 DNS"
}

func (c *failingInterfaceDNSClient) ResetConnection() {
	c.reset = true
}

func TestDHCPClientRefreshesAfterDNSFailure(t *testing.T) {
	client := &failingInterfaceDNSClient{}
	dhcp := &dhcpClient{
		ifaceName:       "不存在的测试接口",
		ifaceInvalidate: time.Now().Add(time.Hour),
		clients:         []dnsClient{client},
	}
	query := &D.Msg{}
	query.SetQuestion("example.com.", D.TypeA)

	_, err := dhcp.ExchangeContext(context.Background(), query)
	if !errors.Is(err, errInterfaceDNSFailed) {
		t.Fatalf("应保留首次 DNS 错误，实际为：%v", err)
	}
	if !client.reset {
		t.Fatal("DNS 请求失败后未失效旧接口 DNS 客户端")
	}
}
