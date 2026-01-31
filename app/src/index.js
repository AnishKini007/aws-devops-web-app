// ========================================
// Sample Node.js Express Application
// ========================================
const express = require('express');
const app = express();
const PORT = process.env.PORT || 8080;

// Middleware
app.use(express.json());

// Request logging middleware
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to EKS CI/CD Demo Application!',
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.APP_ENV || 'development',
    timestamp: new Date().toISOString()
  });
});

// Health check endpoint (for Kubernetes liveness probe)
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

// Readiness check endpoint (for Kubernetes readiness probe)
app.get('/ready', (req, res) => {
  // Add any checks needed before pod receives traffic
  // (database connections, dependencies, etc.)
  res.status(200).json({
    status: 'ready',
    timestamp: new Date().toISOString()
  });
});

// Metrics endpoint (for Prometheus)
app.get('/metrics', (req, res) => {
  res.set('Content-Type', 'text/plain');
  res.send(`
# HELP app_requests_total Total number of requests
# TYPE app_requests_total counter
app_requests_total{method="GET",endpoint="/"} ${Math.floor(Math.random() * 1000)}

# HELP app_uptime_seconds Application uptime in seconds
# TYPE app_uptime_seconds gauge
app_uptime_seconds ${process.uptime()}
  `.trim());
});

// API endpoint example
app.get('/api/info', (req, res) => {
  res.json({
    application: 'EKS CI/CD Demo',
    version: '1.0.0',
    node_version: process.version,
    platform: process.platform,
    architecture: process.arch,
    memory: {
      total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024) + ' MB',
      used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024) + ' MB'
    }
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    path: req.path
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: err.message
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.APP_ENV || 'development'}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
  console.log(`Metrics: http://localhost:${PORT}/metrics`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT signal received: closing HTTP server');
  process.exit(0);
});
