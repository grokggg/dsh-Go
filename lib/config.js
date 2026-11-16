'use strict';

const fs = require('fs');
const path = require('path');

const DEFAULT_CONFIG = Object.freeze({
  version: '0.1.0-unrestricted',
  baseOn: '0.2.2-rc.1',
  host: '127.0.0.1',
  port: 3080,
  safeMode: false,
  token: '',
  runtime: {
    launchMethod: 'proot',
    dnsOrder: 'ipv4first',
    maxOldSpaceSize: 1792,
    threadPoolSize: 4,
  },
  plugins: {
    pluginManager: true,
    presetStandard: true,
    presetCordis: true,
    hmr: true,
  },
  agentPresets: {
    includeHarnessIdentity: false,
    personaPrefix: '',
  },
});

const SAFE_MODE_CONFIG_OVERRIDE = Object.freeze({
  safeMode: true,
  plugins: {
    pluginManager: false,
    presetStandard: false,
    presetCordis: false,
    hmr: false,
  },
});

function resolveConfigPath(custom) {
  return custom || path.join(process.env.HOME || '/tmp', '.dsh', 'dsh-go.json');
}

function load(customPath) {
  const file = resolveConfigPath(customPath);
  let userConfig = {};
  if (fs.existsSync(file)) {
    try {
      userConfig = JSON.parse(fs.readFileSync(file, 'utf8'));
    } catch (e) {
      throw new Error('Config file is not valid JSON: ' + file);
    }
  }
  return merge(DEFAULT_CONFIG, userConfig);
}

function save(config, customPath) {
  const file = resolveConfigPath(customPath);
  const dir = path.dirname(file);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(file, JSON.stringify(config, null, 2), 'utf8');
  return file;
}

function merge(base, override) {
  const out = JSON.parse(JSON.stringify(base));
  deepMerge(out, override || {});
  return out;
}

function deepMerge(target, source) {
  for (const key of Object.keys(source)) {
    const val = source[key];
    if (val && typeof val === 'object' && !Array.isArray(val) && target[key] && typeof target[key] === 'object') {
      deepMerge(target[key], val);
    } else {
      target[key] = val;
    }
  }
}

function buildRescueConfig() {
  return merge(DEFAULT_CONFIG, SAFE_MODE_CONFIG_OVERRIDE);
}

function applySafeMode(config, enabled) {
  if (enabled) return buildRescueConfig();
  return merge(config, { safeMode: false });
}

function get(config, keyPath) {
  const parts = keyPath.split('.');
  let cur = config;
  for (const p of parts) {
    if (cur == null) return undefined;
    cur = cur[p];
  }
  return cur;
}

function set(config, keyPath, value) {
  const parts = keyPath.split('.');
  let cur = config;
  for (let i = 0; i < parts.length - 1; i++) {
    const p = parts[i];
    if (typeof cur[p] !== 'object' || cur[p] == null) cur[p] = {};
    cur = cur[p];
  }
  cur[parts[parts.length - 1]] = value;
}

module.exports = {
  DEFAULT_CONFIG,
  SAFE_MODE_CONFIG_OVERRIDE,
  load,
  save,
  merge,
  buildRescueConfig,
  applySafeMode,
  get,
  set,
};
