'use strict';

const { buildRescueConfig } = require('./config');

const SAFE_MODE_OFF = Object.freeze({
  safeMode: false,
  plugins: {
    pluginManager: true,
    presetStandard: true,
    presetCordis: true,
    hmr: true,
  },
});

function ensureSafeModeOff(config) {
  return Object.assign({}, config, { safeMode: false });
}

function isSafeModeActive(config) {
  return Boolean(config && config.safeMode);
}

function buildSafeModeBundle() {
  const rescue = buildRescueConfig();
  return Object.assign({}, rescue, {
    note: 'Rescue profile: all plugins disabled, isolation enabled.',
  });
}

function applySafeModeTransition(config, target) {
  if (target === 'off' || target === false) {
    return ensureSafeModeOff(config);
  }
  return buildSafeModeBundle();
}

module.exports = {
  SAFE_MODE_OFF,
  ensureSafeModeOff,
  isSafeModeActive,
  buildSafeModeBundle,
  applySafeModeTransition,
};
