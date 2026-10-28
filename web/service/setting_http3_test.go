package service

import (
	"testing"

	"github.com/mhsanaei/3x-ui/v3/web/entity"
)

func TestBuildSubH3URI(t *testing.T) {
	for _, tc := range []struct {
		name, domain, fallback, host, custom, want string
		port                                       int
	}{
		{"domain", "sub.example", "tcp.example", "panel.example:2053", "", "https://sub.example:2097/rescue/", 2097},
		{"fallback", "", "tcp.example", "panel.example:2053", "", "https://tcp.example/rescue/", 443},
		{"panel IPv6", "", "", "[2001:db8::1]:2053", "", "https://[2001:db8::1]:2097/rescue/", 2097},
		{"IPv6 HTTPS", "2001:db8::1", "", "panel.example", "", "https://[2001:db8::1]/rescue/", 443},
		{"custom", "sub.example", "", "panel.example", "https://public.example:8443/custom/", "https://public.example:8443/custom/", 2097},
	} {
		t.Run(tc.name, func(t *testing.T) {
			s := &entity.AllSetting{SubH3Domain: tc.domain, SubDomain: tc.fallback, SubH3Port: tc.port, SubPath: "/rescue/", SubH3URI: tc.custom}
			if got := buildSubH3URI(s, tc.host); got != tc.want {
				t.Fatalf("URI=%q, want %q", got, tc.want)
			}
		})
	}
}

func TestHTTP3DefaultsDoNotEnableNewListener(t *testing.T) {
	setupSettingTestDB(t)
	s := &SettingService{}
	settings, err := s.GetAllSetting()
	if err != nil {
		t.Fatal(err)
	}
	if settings.SubH3Enable || settings.SubH3Port != 2097 {
		t.Fatalf("HTTP/3 defaults: %v, %v", settings.SubH3Enable, settings.SubH3Port)
	}
	defaults, err := s.GetDefaultSettings("panel.example:2053")
	if err != nil {
		t.Fatal(err)
	}
	if values := defaults.(map[string]any); values["subH3Enable"] != false || values["subH3URI"] != "" {
		t.Fatalf("disabled default QR data: %#v", values)
	}
	if err := s.saveSetting("subH3Enable", "true"); err != nil {
		t.Fatal(err)
	}
	if err := s.saveSetting("subEnable", "false"); err != nil {
		t.Fatal(err)
	}
	defaults, err = s.GetDefaultSettings("panel.example:2053")
	if err != nil {
		t.Fatal(err)
	}
	if got := defaults.(map[string]any)["subH3URI"]; got != "https://panel.example:2097/sub/" {
		t.Fatalf("UDP-only default QR URI: %v", got)
	}
}
