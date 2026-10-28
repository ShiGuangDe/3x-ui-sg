package sub

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/mhsanaei/3x-ui/v3/database"
	"github.com/mhsanaei/3x-ui/v3/database/model"
	"github.com/mhsanaei/3x-ui/v3/logger"
	"github.com/mhsanaei/3x-ui/v3/web/entity"
	"github.com/op/go-logging"
	"github.com/quic-go/quic-go/http3"
)

func h3TestCertificate(t *testing.T) (tls.Certificate, *x509.CertPool, string, string) {
	t.Helper()
	t.Setenv("XUI_LOG_FOLDER", t.TempDir())
	logger.InitLogger(logging.ERROR)
	t.Cleanup(logger.CloseLogger)
	fixture := httptest.NewTLSServer(nil)
	cert := fixture.TLS.Certificates[0]
	fixture.Close()
	pool := x509.NewCertPool()
	parsed, err := x509.ParseCertificate(cert.Certificate[0])
	if err != nil {
		t.Fatal(err)
	}
	pool.AddCert(parsed)
	key, err := x509.MarshalPKCS8PrivateKey(cert.PrivateKey)
	if err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	certFile, keyFile := filepath.Join(dir, "cert.pem"), filepath.Join(dir, "key.pem")
	if err := os.WriteFile(certFile, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: cert.Certificate[0]}), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(keyFile, pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: key}), 0600); err != nil {
		t.Fatal(err)
	}
	return cert, pool, certFile, keyFile
}

func TestH3SettingsRequireTLS(t *testing.T) {
	_, _, certFile, keyFile := h3TestCertificate(t)
	base := entity.AllSetting{SubH3Enable: true, SubH3Port: 2097, SubCertFile: certFile, SubKeyFile: keyFile}
	if err := base.CheckSubH3(); err != nil {
		t.Fatalf("shared certificate rejected: %v", err)
	}
	for _, tc := range []struct {
		name   string
		change func(*entity.AllSetting)
	}{
		{"missing certificate", func(s *entity.AllSetting) { s.SubCertFile = "" }},
		{"partial override", func(s *entity.AllSetting) { s.SubH3CertFile = certFile }},
		{"bad certificate", func(s *entity.AllSetting) { s.SubH3CertFile = "missing"; s.SubH3KeyFile = "missing" }},
		{"port zero", func(s *entity.AllSetting) { s.SubH3Port = 0 }},
		{"port overflow", func(s *entity.AllSetting) { s.SubH3Port = 65536 }},
		{"listen hostname", func(s *entity.AllSetting) { s.SubH3Listen = "example.com" }},
		{"domain with scheme", func(s *entity.AllSetting) { s.SubH3Domain = "https://example.com" }},
		{"plain HTTP", func(s *entity.AllSetting) { s.SubH3URI = "http://example.com/sub/" }},
		{"UDP scheme", func(s *entity.AllSetting) { s.SubH3URI = "udp://example.com/sub/" }},
		{"query", func(s *entity.AllSetting) { s.SubH3URI = "https://example.com/sub/?id=" }},
		{"missing slash", func(s *entity.AllSetting) { s.SubH3URI = "https://example.com/sub" }},
	} {
		t.Run(tc.name, func(t *testing.T) {
			s := base
			tc.change(&s)
			if err := s.CheckSubH3(); err == nil {
				t.Fatal("invalid HTTP/3 settings accepted")
			}
		})
	}
	if err := (&entity.AllSetting{SubH3Enable: false}).CheckSubH3(); err != nil {
		t.Fatal(err)
	}
}

func h3Client(t *testing.T, pool *x509.CertPool) *http.Client {
	t.Helper()
	transport := &http3.Transport{TLSClientConfig: &tls.Config{RootCAs: pool, MinVersion: tls.VersionTLS13}}
	t.Cleanup(func() { _ = transport.Close() })
	return &http.Client{Transport: transport, Timeout: 5 * time.Second}
}

func TestH3DownloadWithoutTCP(t *testing.T) {
	cert, pool, _, _ := h3TestCertificate(t)
	s := NewServer()
	if err := s.startH3("127.0.0.1:0", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.ProtoMajor != 3 {
			t.Errorf("request protocol = %s", r.Proto)
		}
		_, _ = io.WriteString(w, "subscription-over-udp")
	}), cert); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = s.Stop() })
	addr := s.udpConn.LocalAddr().String()
	if conn, err := net.DialTimeout("tcp", addr, 200*time.Millisecond); err == nil {
		conn.Close()
		t.Fatal("HTTP/3 unexpectedly opened TCP")
	}
	resp, err := h3Client(t, pool).Get("https://" + addr + "/sub/test")
	if err != nil {
		t.Fatal(err)
	}
	body, err := io.ReadAll(resp.Body)
	resp.Body.Close()
	if err != nil || resp.ProtoMajor != 3 || string(body) != "subscription-over-udp" {
		t.Fatalf("HTTP/3 response: %s, %q, %v", resp.Proto, body, err)
	}
	_ = s.Stop()
	conn, err := net.ListenPacket("udp", addr)
	if err != nil {
		t.Fatalf("UDP port leaked after Stop: %v", err)
	}
	conn.Close()
}

func setupH3Database(t *testing.T) {
	t.Helper()
	if err := database.InitDB(filepath.Join(t.TempDir(), "x-ui.db")); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = database.CloseDB() })
}

func freeUDPPort(t *testing.T) int {
	t.Helper()
	conn, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	port := conn.LocalAddr().(*net.UDPAddr).Port
	conn.Close()
	return port
}

func setH3Settings(t *testing.T, values map[string]string) {
	t.Helper()
	for key, value := range values {
		if err := database.GetDB().Save(&model.Setting{Key: key, Value: value}).Error; err != nil {
			t.Fatal(err)
		}
	}
}

func TestConfiguredH3SubscriptionIndependentOfTCP(t *testing.T) {
	setupH3Database(t)
	_, pool, certFile, keyFile := h3TestCertificate(t)
	port := freeUDPPort(t)
	setH3Settings(t, map[string]string{
		"subEnable": "false", "subH3Enable": "true", "subH3Listen": "127.0.0.1",
		"subH3Port": fmt.Sprint(port), "subH3Domain": "127.0.0.1", "subDomain": "tcp-only.invalid",
		"subH3CertFile": certFile, "subH3KeyFile": keyFile, "subEncrypt": "false", "subPath": "/rescue/",
	})
	inbound := &model.Inbound{Enable: true, Port: 12345, Protocol: model.VLESS, Tag: "h3-test", Settings: `{"clients":[{"id":"a6caf933-5364-46f3-9da4-8c8bb1f451fa","email":"h3-test","subId":"rescue-id","enable":true}]}`, StreamSettings: `{"network":"tcp","security":"none"}`}
	client := &model.ClientRecord{Email: "h3-test", SubID: "rescue-id", Enable: true}
	for _, record := range []any{inbound, client} {
		if err := database.GetDB().Create(record).Error; err != nil {
			t.Fatal(err)
		}
	}
	if err := database.GetDB().Create(&model.ClientInbound{InboundId: inbound.Id, ClientId: client.Id}).Error; err != nil {
		t.Fatal(err)
	}
	s := NewServer()
	if err := s.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = s.Stop() })
	if s.listener != nil || s.httpServer != nil {
		t.Fatal("TCP subscription enabled despite disabled switch")
	}
	httpClient := h3Client(t, pool)
	resp, err := httpClient.Get(fmt.Sprintf("https://127.0.0.1:%d/rescue/rescue-id", port))
	if err != nil {
		t.Fatal(err)
	}
	body, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != 200 || resp.ProtoMajor != 3 || !strings.Contains(string(body), "vless://a6caf933") || resp.Header.Get("Subscription-Userinfo") == "" {
		t.Fatalf("subscription response: %s, %s, %q, headers=%v", resp.Status, resp.Proto, body, resp.Header)
	}
	resp, err = httpClient.Get(fmt.Sprintf("https://127.0.0.1:%d/rescue/unknown-id", port))
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if resp.StatusCode == 200 {
		t.Fatal("unknown subscription ID accepted")
	}
}

func TestH3DisabledDoesNotBindUDP(t *testing.T) {
	setupH3Database(t)
	setH3Settings(t, map[string]string{"subEnable": "false", "subH3Enable": "false"})
	s := NewServer()
	if err := s.Start(); err != nil {
		t.Fatal(err)
	}
	defer s.Stop()
	if s.udpConn != nil || s.h3Listener != nil {
		t.Fatal("disabled HTTP/3 listener is active")
	}
}

func TestH3PortCollisionFailsSynchronously(t *testing.T) {
	cert, _, _, _ := h3TestCertificate(t)
	occupied, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer occupied.Close()
	s := NewServer()
	defer s.Stop()
	if err := s.startH3(occupied.LocalAddr().String(), http.NotFoundHandler(), cert); err == nil {
		t.Fatal("occupied UDP port accepted")
	}
}

func TestH3CleanupWhenTCPStartFails(t *testing.T) {
	setupH3Database(t)
	_, _, certFile, keyFile := h3TestCertificate(t)
	occupied, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer occupied.Close()
	udpPort := freeUDPPort(t)
	setH3Settings(t, map[string]string{
		"subEnable": "true", "subListen": "127.0.0.1", "subPort": fmt.Sprint(occupied.Addr().(*net.TCPAddr).Port),
		"subH3Enable": "true", "subH3Listen": "127.0.0.1", "subH3Port": fmt.Sprint(udpPort),
		"subH3CertFile": certFile, "subH3KeyFile": keyFile,
	})
	s := NewServer()
	if err := s.Start(); err == nil {
		_ = s.Stop()
		t.Fatal("TCP port conflict was ignored")
	}
	conn, err := net.ListenPacket("udp", fmt.Sprintf("127.0.0.1:%d", udpPort))
	if err != nil {
		t.Fatalf("UDP listener leaked on partial startup failure: %v", err)
	}
	conn.Close()
}
