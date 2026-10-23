const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

test('config templates load only player variables from the shared env', () => {
  const dir = fs.mkdtempSync(path.join(__dirname, '.env-test-'));
  try {
    const envFile = path.join(dir, '.env');
    fs.writeFileSync(envFile,
      "XIBO_CMS_URL='http://cms.test:8080'\nXIBO_CMS_KEY=test-key\n" +
      'XIBO_API_CLIENT_ID=test-client\nXIBO_API_CLIENT_SECRET=test-secret\n' +
      'BASH_ENV=/must/not/be/sourced\nDHCP_USERNAME=private-user\n');
    const bash = process.platform === 'win32' ?
      'C:/Program Files/Git/bin/bash.exe' : 'bash';
    const result = spawnSync(bash, [
      path.join(__dirname, '../configs/apply.sh'), 'chromium-dev', 'test-player'
    ], { encoding: 'utf8', timeout: 15000,
      env: { ...process.env, XDG_CONFIG_HOME: dir.replace(/\\/g, '/'),
      XDG_DATA_HOME: dir.replace(/\\/g, '/') + '/data',
      XIBO_ENV_FILE: envFile.replace(/\\/g, '/'), XIBO_CMS_URL: '',
      XIBO_CMS_KEY: '', XIBO_API_CLIENT_ID: '', XIBO_API_CLIENT_SECRET: '' } });
    assert.equal(result.status, 0, result.stderr);
    const config = JSON.parse(fs.readFileSync(
      path.join(dir, 'xiboplayer/test-player/config.json'), 'utf8'));
    assert.equal(config.cmsUrl, 'http://cms.test:8080');
    assert.equal(config.cmsKey, 'test-key');
    assert.equal(config.apiClientId, 'test-client');
    assert.equal(config.apiClientSecret, 'test-secret');
    assert.ok(!JSON.stringify(config).includes('private-user'));
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
