const express = require('express');
const path = require('path');
const app = express();

const startTime = Date.now();

// Serve static files from the public folder
// app.use(express.static(path.join(__dirname, 'public')));

app.get('/status', (req, res) => {
    const uptime = Math.floor((Date.now() - startTime) / 1000);
    res.json({ status: 'OK', uptime: `${uptime} seconds` });
});

const PORT = 3000;
app.listen(PORT, () => {
    console.log(`Server is running on http://localhost:${PORT}`);
});