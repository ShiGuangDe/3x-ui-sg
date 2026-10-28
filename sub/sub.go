// Package sub provides subscription server functionality for the 3x-ui panel,
// including HTTP/HTTPS servers for serving subscription links and JSON configurations.
package sub

import (
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"net"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/mhsanaei/3x-ui/v3/logger"
	"github.com/mhsanaei/3x-ui/v3/util/common"
	"github.com/mhsanaei/3x-ui/v3/web/locale"
	"github.com/mhsanaei/3x-ui/v3/web/middleware"
	"github.com/mhsanaei/3x-ui/v3/web/network"
	"github.com/mhsanaei/3x-ui/v3/web/service"

	"github.com/gin-gonic/gin"
	"github.com/quic-go/quic-go"
	"github.com/quic-go/quic-go/http3"
)

// Server represents the subscription server that serves subscription links and JSON configurations.
type Server struct {
	httpServer *http.Server
	listener   net.Listener
	h3Server   *http3.Server
	h3Listener *quic.EarlyListener
	udpConn    net.PacketConn

	sub            *SUBController
	settingService service.SettingService

	ctx    context.Context
	cancel context.CancelFunc
}

// NewServer creates a new subscription server instance with a cancellable context.
func NewServer() *Server {
	ctx, cancel := context.WithCancel(context.Background())
	return &Server{
		ctx:    ctx,
		cancel: cancel,
	}
}

// initRouter configures the subscription server's Gin engine, middleware,
// templates and static assets and returns the ready-to-use engine.
func (s *Server) initRouter(subDomain string) (*gin.Engine, error) {
	// Always run in release mode for the subscription server
	gin.DefaultWriter = io.Discard
	gin.DefaultErrorWriter = io.Discard
	gin.SetMode(gin.ReleaseMode)

	engine := gin.Default()

	if subDomain != "" {
		engine.Use(middleware.DomainValidatorMiddleware(subDomain))
	}

	LinksPath, err := s.settingService.GetSubPath()
	if err != nil {
		return nil, err
	}

	JsonPath, err := s.settingService.GetSubJsonPath()
	if err != nil {
		return nil, err
	}

	ClashPath, err := s.settingService.GetSubClashPath()
	if err != nil {
		return nil, err
	}

	subJsonEnable, err := s.settingService.GetSubJsonEnable()
	if err != nil {
		return nil, err
	}

	subClashEnable, err := s.settingService.GetSubClashEnable()
	if err != nil {
		return nil, err
	}

	// Set base_path based on LinksPath for template rendering
	// Ensure LinksPath ends with "/" for proper asset URL generation
	basePath := LinksPath
	if basePath != "/" && !strings.HasSuffix(basePath, "/") {
		basePath += "/"
	}
	// logger.Debug("sub: Setting base_path to:", basePath)
	engine.Use(func(c *gin.Context) {
		c.Set("base_path", basePath)
	})

	Encrypt, err := s.settingService.GetSubEncrypt()
	if err != nil {
		return nil, err
	}

	ShowInfo, err := s.settingService.GetSubShowInfo()
	if err != nil {
		return nil, err
	}

	RemarkModel, err := s.settingService.GetRemarkModel()
	if err != nil {
		RemarkModel = "-io"
	}

	SubUpdates, err := s.settingService.GetSubUpdates()
	if err != nil {
		SubUpdates = "10"
	}

	SubJsonFragment, err := s.settingService.GetSubJsonFragment()
	if err != nil {
		SubJsonFragment = ""
	}

	SubJsonNoises, err := s.settingService.GetSubJsonNoises()
	if err != nil {
		SubJsonNoises = ""
	}

	SubJsonMux, err := s.settingService.GetSubJsonMux()
	if err != nil {
		SubJsonMux = ""
	}

	SubJsonRules, err := s.settingService.GetSubJsonRules()
	if err != nil {
		SubJsonRules = ""
	}

	SubTitle, err := s.settingService.GetSubTitle()
	if err != nil {
		SubTitle = ""
	}

	SubSupportUrl, err := s.settingService.GetSubSupportUrl()
	if err != nil {
		SubSupportUrl = ""
	}

	SubProfileUrl, err := s.settingService.GetSubProfileUrl()
	if err != nil {
		SubProfileUrl = ""
	}

	SubAnnounce, err := s.settingService.GetSubAnnounce()
	if err != nil {
		SubAnnounce = ""
	}

	SubEnableRouting, err := s.settingService.GetSubEnableRouting()
	if err != nil {
		return nil, err
	}

	SubRoutingRules, err := s.settingService.GetSubRoutingRules()
	if err != nil {
		SubRoutingRules = ""
	}

	// set per-request localizer from headers/cookies
	engine.Use(locale.LocalizerMiddleware())

	// Mount the Vite-built dist/assets/ so the subscription page's JS/CSS
	// bundles load from `/assets/...`. Also mount the same FS under the
	// subscription path prefix (LinksPath + "assets") so reverse proxies
	// running the panel under a URI prefix can resolve those URLs too.
	// Note: LinksPath always starts and ends with "/" (validated in settings).
	var linksPathForAssets string
	if LinksPath == "/" {
		linksPathForAssets = "/assets"
	} else {
		linksPathForAssets = strings.TrimRight(LinksPath, "/") + "/assets"
	}

	var assetsFS http.FileSystem
	if _, err := os.Stat("web/dist/assets"); err == nil {
		assetsFS = http.FS(os.DirFS("web/dist/assets"))
	} else if subFS, err := fs.Sub(distFS, "dist/assets"); err == nil {
		assetsFS = http.FS(subFS)
	} else {
		logger.Error("sub: failed to mount embedded dist assets:", err)
	}

	if assetsFS != nil {
		engine.StaticFS("/assets", assetsFS)
		if linksPathForAssets != "/assets" {
			engine.StaticFS(linksPathForAssets, assetsFS)
		}

		// Browser may resolve subpage assets relative to the request URL —
		// /sub/<basePath>/<subId>/assets/... — so route those to the same FS.
		if LinksPath != "/" {
			engine.Use(func(c *gin.Context) {
				path := c.Request.URL.Path
				pathPrefix := strings.TrimRight(LinksPath, "/") + "/"
				if strings.HasPrefix(path, pathPrefix) && strings.Contains(path, "/assets/") {
					_, after, ok := strings.Cut(path, "/assets/")
					if ok {
						assetPath := after // +8 to skip "/assets/"
						if assetPath != "" {
							c.FileFromFS(assetPath, assetsFS)
							c.Abort()
							return
						}
					}
				}
				c.Next()
			})
		}
	}

	g := engine.Group("/")

	s.sub = NewSUBController(
		g, LinksPath, JsonPath, ClashPath, subJsonEnable, subClashEnable, Encrypt, ShowInfo, RemarkModel, SubUpdates,
		SubJsonFragment, SubJsonNoises, SubJsonMux, SubJsonRules, SubTitle, SubSupportUrl,
		SubProfileUrl, SubAnnounce, SubEnableRouting, SubRoutingRules)

	return engine, nil
}

// Start initializes and starts the subscription server with configured settings.
func (s *Server) Start() (err error) {
	// This is an anonymous function, no function name
	defer func() {
		if err != nil {
			s.Stop()
		}
	}()

	settings, err := s.settingService.GetAllSetting()
	if err != nil {
		return err
	}
	if !settings.SubEnable && !settings.SubH3Enable {
		return nil
	}

	if settings.SubH3Enable {
		if err := settings.CheckSubH3(); err != nil {
			return err
		}
		domain := settings.SubH3Domain
		if domain == "" {
			domain = settings.SubDomain
		}
		engine, err := s.initRouter(domain)
		if err != nil {
			return err
		}
		certFile, keyFile := settings.SubH3CertificateFiles()
		cert, err := tls.LoadX509KeyPair(certFile, keyFile)
		if err != nil {
			return err
		}
		addr := net.JoinHostPort(settings.SubH3Listen, strconv.Itoa(settings.SubH3Port))
		if err := s.startH3(addr, engine, cert); err != nil {
			return err
		}
	}
	if !settings.SubEnable {
		return nil
	}

	engine, err := s.initRouter(settings.SubDomain)
	if err != nil {
		return err
	}

	certFile, err := s.settingService.GetSubCertFile()
	if err != nil {
		return err
	}
	keyFile, err := s.settingService.GetSubKeyFile()
	if err != nil {
		return err
	}
	listen, err := s.settingService.GetSubListen()
	if err != nil {
		return err
	}
	port, err := s.settingService.GetSubPort()
	if err != nil {
		return err
	}

	listenAddr := net.JoinHostPort(listen, strconv.Itoa(port))
	listener, err := net.Listen("tcp", listenAddr)
	if err != nil {
		return err
	}
	s.listener = listener

	if certFile != "" || keyFile != "" {
		cert, err := tls.LoadX509KeyPair(certFile, keyFile)
		if err == nil {
			c := &tls.Config{
				Certificates: []tls.Certificate{cert},
			}
			listener = network.NewAutoHttpsListener(listener)
			listener = tls.NewListener(listener, c)
			logger.Info("Sub server running HTTPS on", listener.Addr())
		} else {
			logger.Error("Error loading certificates:", err)
			logger.Info("Sub server running HTTP on", listener.Addr())
		}
	} else {
		logger.Info("Sub server running HTTP on", listener.Addr())
	}
	s.listener = listener

	s.httpServer = &http.Server{
		Handler: engine,
	}

	go func() {
		s.httpServer.Serve(listener)
	}()

	return nil
}

// startH3 binds UDP and QUIC synchronously, so certificate or port errors are
// reported before Start succeeds. It never opens a TCP listener.
func (s *Server) startH3(addr string, handler http.Handler, cert tls.Certificate) error {
	conn, err := net.ListenPacket("udp", addr)
	if err != nil {
		return fmt.Errorf("HTTP/3 subscription UDP listen: %w", err)
	}
	s.udpConn = conn
	tlsConfig := http3.ConfigureTLSConfig(&tls.Config{
		MinVersion:   tls.VersionTLS13,
		Certificates: []tls.Certificate{cert},
	})
	listener, err := quic.ListenEarly(conn, tlsConfig, &quic.Config{
		HandshakeIdleTimeout:  5 * time.Second,
		MaxIdleTimeout:        30 * time.Second,
		MaxIncomingStreams:    16,
		MaxIncomingUniStreams: 8,
	})
	if err != nil {
		_ = conn.Close()
		return fmt.Errorf("HTTP/3 subscription QUIC listen: %w", err)
	}
	s.h3Listener = listener
	s.h3Server = &http3.Server{
		Handler:        handler,
		TLSConfig:      tlsConfig,
		MaxHeaderBytes: 32 << 10,
		IdleTimeout:    30 * time.Second,
	}
	go func() {
		if err := s.h3Server.ServeListener(listener); err != nil && !errors.Is(err, http.ErrServerClosed) && s.ctx.Err() == nil {
			logger.Error("HTTP/3 subscription server:", err)
		}
	}()
	logger.Info("Sub server running HTTP/3 (UDP) on", conn.LocalAddr())
	return nil
}

// Stop gracefully shuts down the subscription server and closes the listener.
func (s *Server) Stop() error {
	s.cancel()
	// Close active QUIC connections before releasing the externally owned
	// listener and UDP socket (http3.Server does not own these resources).
	var h3Errors []error
	if s.h3Server != nil {
		h3Errors = append(h3Errors, s.h3Server.Close())
	}
	if s.h3Listener != nil {
		h3Errors = append(h3Errors, s.h3Listener.Close())
	}
	if s.udpConn != nil {
		h3Errors = append(h3Errors, s.udpConn.Close())
	}

	var err1 error
	var err2 error
	if s.httpServer != nil {
		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer shutdownCancel()
		err1 = s.httpServer.Shutdown(shutdownCtx)
	}
	if s.listener != nil {
		err2 = s.listener.Close()
	}
	return common.Combine(append(h3Errors, err1, err2)...)
}

// GetCtx returns the server's context for cancellation and deadline management.
func (s *Server) GetCtx() context.Context {
	return s.ctx
}
