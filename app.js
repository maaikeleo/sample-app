const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({
    message: 'Hello from Jenkins CI/CD Pipeline!',
    status: 'success',
    build: process.env.BUILD_NUMBER || 'local',
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'OK', service: 'sample-app' });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
