const express = require('express');
const path = require('path');
const app = express();
const port = process.env.PORT || 3000;

// Middleware for health checks
app.use('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// Default route
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Frontend server running on port ${port}`);
});
