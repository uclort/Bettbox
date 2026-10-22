package statistic

type RequestNotify func(c Tracker)

var DefaultRequestNotify RequestNotify

// BETTBOX-CUSTOM: 让拨号阶段也能复用连接生命周期通知，供网络面板展示“建立中”。
func NotifyRequest(c Tracker) {
	if DefaultRequestNotify != nil {
		DefaultRequestNotify(c)
	}
}

func (m *Manager) TotalTraffic(onlyProxy bool) (up, down int64) {
	if onlyProxy {
		return m.proxyUploadTotal.Load(), m.proxyDownloadTotal.Load()
	}
	return m.uploadTotal.Load(), m.downloadTotal.Load()
}

func (m *Manager) NowTraffic(onlyProxy bool) (up, down int64) {
	if onlyProxy {
		return m.proxyUploadBlip.Load(), m.proxyDownloadBlip.Load()
	}
	return m.uploadBlip.Load(), m.downloadBlip.Load()
}
