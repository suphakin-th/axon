// Minimal HTTP server - replace this with your real application.
// It exists so the axon pipeline has a working health endpoint to deploy
// and verify end to end. No dependencies: uses only the Node standard library.

const http = require("http");

const port = process.env.APP_PORT || process.env.PORT || 3000;
const healthPath = process.env.HEALTH_PATH || "/health";

const sendJson = (res, status, body) => {
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(JSON.stringify(body));
};

const isHealthCheck = (req) => req.url === healthPath;

const handleRequest = (req, res) =>
  isHealthCheck(req)
    ? sendJson(res, 200, { status: "ok", uptime: process.uptime() })
    : sendJson(res, 200, { name: "axon", message: "replace this with your application" });

const server = http.createServer(handleRequest);

server.listen(port, () => {
  console.log(`axon listening on port ${port} (health: ${healthPath})`);
});
