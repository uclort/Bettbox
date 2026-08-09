package main

import (
	"strings"
	"testing"

	"github.com/metacubex/mihomo/config"
)

func TestMarshalInlineProviderContent(t *testing.T) {
	rawConfig := config.DefaultRawConfig()
	rawConfig.ProxyProvider = map[string]map[string]any{
		"Source-Proxies": {
			"type": "inline",
			"payload": []map[string]any{
				{
					"name":     "测试节点",
					"type":     "ss",
					"server":   "203.0.113.10",
					"port":     443,
					"cipher":   "aes-128-gcm",
					"password": "test",
				},
			},
		},
	}

	content, err := marshalInlineProviderContent(rawConfig, "Source-Proxies")
	if err != nil {
		t.Fatalf("序列化 inline provider 失败：%v", err)
	}

	text := string(content)
	for _, expected := range []string{"proxies:", "测试节点", "203.0.113.10", "aes-128-gcm"} {
		if !strings.Contains(text, expected) {
			t.Fatalf("提供者内容缺少 %q：\n%s", expected, text)
		}
	}
}

func TestMarshalInlineProviderContentRejectsMissingPayload(t *testing.T) {
	rawConfig := config.DefaultRawConfig()
	rawConfig.ProxyProvider = map[string]map[string]any{
		"Source-Proxies": {"type": "inline"},
	}

	if _, err := marshalInlineProviderContent(rawConfig, "Source-Proxies"); err == nil {
		t.Fatal("缺少 payload 时应返回错误")
	}
}

func TestOverrideTestURLs(t *testing.T) {
	rawConfig := config.DefaultRawConfig()
	rawConfig.ProxyGroup = []map[string]any{{"name": "自动选择", "url": "https://旧地址"}}
	rawConfig.ProxyProvider = map[string]map[string]any{
		"有健康检查": {"health-check": map[string]any{"url": "https://旧地址"}},
		"无健康检查": {"type": "inline"},
	}

	overrideTestURLs(rawConfig, "https://新地址")

	if rawConfig.ProxyGroup[0]["url"] != "https://新地址" {
		t.Fatal("策略组测速地址未覆盖")
	}
	healthCheck := rawConfig.ProxyProvider["有健康检查"]["health-check"].(map[string]any)
	if healthCheck["url"] != "https://新地址" {
		t.Fatal("Provider 健康检查地址未覆盖")
	}
	if _, ok := rawConfig.ProxyProvider["无健康检查"]["health-check"]; ok {
		t.Fatal("不应为未启用健康检查的 Provider 创建配置")
	}
}
