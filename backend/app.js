const express = require('express');
const cors = require('cors');
const app = express();
const port = process.env.PORT || 8080;

// Middleware
app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    service: 'backend-api',
    version: '1.0.0'
  });
});

// Main API endpoint
app.get('/api/message', (req, res) => {
  const messages = [
    'Hello from Backend API! 🚀',
    'DevOps pipeline is working perfectly! ✅',
    'EKS cluster is running smoothly! ☸️',
    'Containers are healthy and happy! 🐳',
    'Terraform infrastructure deployed successfully! 🏗️'
  ];
  
  const randomMessage = messages[Math.floor(Math.random() * messages.length)];
  
  res.json({ 
    message: randomMessage,
    timestamp: new Date().toISOString(),
    hostname: require('os').hostname(),
    version: '1.0.0'
  });
});

// API info endpoint
app.get('/api/info', (req, res) => {
  res.json({
    service: 'DevOps Backend API',
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    node_version: process.version,
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ 
    error: 'Something went wrong!',
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ 
    error: 'Endpoint not found',
    path: req.originalUrl,
    timestamp: new Date().toISOString()
  });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Backend API server running on port ${port}`);
  console.log(`Health check available at: http://localhost:${port}/health`);
  console.log(`API message endpoint: http://localhost:${port}/api/message`);
});
