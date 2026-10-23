const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

// Catches an absent packaged helper and over-broad Chromium profile matching.
test('stop helper selects only the exact player profile', async t => {
  const helper = path.join(__dirname, '../xiboplayer/stop-player.cjs');
  assert.ok(fs.existsSync(helper), 'stop helper must ship inside the player');
  const { matchesProfile } = require(helper);
  const profile = '/home/berry/.local/share/xiboplayer/chromium';
  const cases = [
    [['chromium', `--user-data-dir=${profile}`], true],
    [['chromium', '--user-data-dir', profile], true],
    [[`chromium --user-data-dir=${profile} --kiosk`, ''], true],
    [[`chromium --user-data-dir ${profile} --kiosk`], true],
    [['chromium', `--user-data-dir=${profile}-other`], false],
    [[`chromium --user-data-dir=${profile}-other --kiosk`], false],
    [['chromium', '--user-data-dir', `${profile}/Default`], false],
    [['chromium', '--user-data-dir'], false],
    [['chromium', '--kiosk'], false],
    [[], false],
    [['chromium', `--other-user-data-dir=${profile}`], false],
    [[`chromium --other-user-data-dir=${profile}`], false]
  ];
  for (const [argv, expected] of cases) {
    await t.test(JSON.stringify(argv), () => {
      assert.equal(matchesProfile(argv, profile), expected);
    });
  }
  await t.test('profile metacharacters are literal', () => {
    assert.equal(matchesProfile(['chromium --user-data-dir=/tmp/playerXtest'],
      '/tmp/player.test'), false);
    assert.equal(matchesProfile(['chromium --user-data-dir=/tmp/player.test'],
      '/tmp/player.test'), true);
  });
});

// /proc is an OS boundary: use complete synthetic proc entries on Windows.
function loadWithProc(entries, env = {}) {
  const killed = [];
  const gone = () => Object.assign(new Error('gone'), { code: 'ENOENT' });
  const fakeFs = {
    readdirSync: () => Object.keys(entries),
    statSync: file => {
      const entry = entries[file.split('/')[2]];
      if (!entry) throw gone();
      return { uid: entry.uid };
    },
    readlinkSync: file => entries[file.split('/')[2]].exe,
    readFileSync: file => {
      const pid = file.split('/')[2];
      const entry = entries[pid];
      if (!entry) throw gone();
      if (file.endsWith('/cmdline')) return entry.argv.join('\0');
      return `${pid} (chromium) ${entry.state} ` +
        Array(18).fill('0').join(' ') + ` ${entry.startTime} 0`;
    }
  };
  const context = {
    module: { exports: {} },
    require: name => name === 'node:fs' ? fakeFs :
      name === 'node:path' ? path.posix :
      name === 'node:os' ? { homedir: () => '/home/berry' } : require(name),
    process: {
      platform: 'linux', env, getuid: () => 1000,
      kill: (pid, signal) => { killed.push([pid, signal]); delete entries[pid]; }
    },
    console: { log() {}, error() {} }, setTimeout, Date
  };
  vm.runInNewContext(fs.readFileSync(
    path.join(__dirname, '../xiboplayer/stop-player.cjs'), 'utf8'), context);
  return { api: context.module.exports, killed };
}

test('stop preserves other users, profiles, executables and zombies', async () => {
  const profile = '/home/berry/.local/share/xiboplayer/chromium';
  const entry = (overrides = {}) => ({ uid: 1000, exe: '/usr/bin/chromium',
    argv: ['chromium', `--user-data-dir=${profile}`],
    state: 'S', startTime: '12345', ...overrides });
  const { api, killed } = loadWithProc({
    101: entry(),
    102: entry({ uid: 2000 }),
    103: entry({ argv: ['chromium', `--user-data-dir=${profile}-other`] }),
    104: entry({ exe: '/usr/bin/node' }),
    105: entry({ state: 'Z' })
  });
  await api.stopPlayer();
  assert.deepEqual(killed, [[101, 'SIGTERM']]);
  await api.stopPlayer();
  assert.deepEqual(killed, [[101, 'SIGTERM']], 'stopping twice is harmless');
});

test('stop honors the same XDG data directory as the launcher', async () => {
  const { api, killed } = loadWithProc({
    201: { uid: 1000, exe: '/usr/bin/chromium', state: 'S', startTime: '42',
      argv: ['chromium', '--user-data-dir=/custom/data/xiboplayer/chromium'] }
  }, { XDG_DATA_HOME: '/custom/data' });
  await api.stopPlayer();
  assert.deepEqual(killed, [[201, 'SIGTERM']]);
});
