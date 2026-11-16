'use strict';

const http = require('http');
const { EventEmitter } = require('events');

class Runtime extends EventEmitter {
  constructor(config) {
    super();
    this.config = config;
    this.state = 'stopped';
    this.server = null;
    this.startedAt = null;
  }

  start() {
    if (this.state === 'running') {
      throw new Error('Server is already running');
    }
    const cfg = this.config;
    this.server = http.createServer((req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        ok: true,
        version: cfg.version,
        baseOn: cfg.baseOn,
        safeMode: cfg.safeMode,
        unrestricted: !cfg.safeMode,
      }));
    });
    return new Promise((resolve, reject) => {
      this.server.listen(cfg.port, cfg.host, (err) => {
        if (err) return reject(err);
        this.state = 'running';
        this.startedAt = Date.now();
        this.emit('started', { host: cfg.host, port: cfg.port });
        resolve({ host: cfg.host, port: cfg.port });
      });
    });
  }

  stop() {
    return new Promise((resolve) => {
      if (this.server) {
        this.server.close(() => {
          this.state = 'stopped';
          this.server = null;
          this.startedAt = null;
          this.emit('stopped');
          resolve();
        });
      } else {
        this.state = 'stopped';
        resolve();
      }
    });
  }

  status() {
    const up = this.state === 'running';
    const uptime = up && this.startedAt ? Math.floor((Date.now() - this.startedAt) / 1000) : 0;
    return {
      state: this.state,
      uptime,
      url: `http://${this.config.host}:${this.config.port}`,
      safeMode: this.config.safeMode,
      version: this.config.version,
    };
  }
}

async function probe(port, host) {
  return new Promise((resolve) => {
    const req = http.get({ host: host || '127.0.0.1', port, path: '/', timeout: 1000 }, (res) => {
      res.resume();
      resolve(res.statusCode === 200);
    });
    req.on('error', () => resolve(false));
    req.on('timeout', () => { req.destroy(); resolve(false); });
  });
}

module.exports = { Runtime, probe };
