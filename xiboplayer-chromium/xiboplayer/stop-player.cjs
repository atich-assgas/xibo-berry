const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

function matchesProfile(argv, profile) {
  if (argv.some((argument, index) =>
    argument === `--user-data-dir=${profile}` ||
    (argument === '--user-data-dir' && argv[index + 1] === profile)
  )) return true;
  const nonempty = argv.filter(Boolean);
  if (nonempty.length !== 1) return false;
  const escaped = profile.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(
    `(?:^|\\s)--user-data-dir(?:=|\\s)${escaped}(?=\\s|$)`
  ).test(nonempty[0]);
}

function inspectProcess(pid, profile) {
  try {
    const directory = `/proc/${pid}`;
    if (fs.statSync(directory).uid !== process.getuid()) return null;
    const executable = path.basename(fs.readlinkSync(`${directory}/exe`));
    if (!['chromium', 'chromium-browser', 'chrome',
      'google-chrome', 'google-chrome-stable'].includes(executable)) return null;
    const argv = fs.readFileSync(`${directory}/cmdline`, 'utf8').split('\0');
    if (!matchesProfile(argv, profile)) return null;
    const stat = fs.readFileSync(`${directory}/stat`, 'utf8');
    const fields = stat.slice(stat.lastIndexOf(')') + 2).trim().split(/\s+/);
    if (fields[0] === 'Z') return null;
    return {
      pid: Number(pid),
      startTime: fields[19],
      main: !argv.some(argument => /(?:^|\s)--type=/.test(argument))
    };
  } catch (error) {
    if (['ENOENT', 'ESRCH', 'EACCES', 'EPERM'].includes(error.code)) return null;
    throw error;
  }
}

function findProcesses(profile) {
  return fs.readdirSync('/proc')
    .filter(entry => /^\d+$/.test(entry))
    .map(pid => inspectProcess(pid, profile))
    .filter(Boolean);
}

function signalProcesses(processes, signal, profile) {
  for (const target of processes) {
    const current = inspectProcess(target.pid, profile);
    if (!current || current.startTime !== target.startTime) continue;
    try {
      process.kill(target.pid, signal);
    } catch (error) {
      if (error.code !== 'ESRCH') throw error;
    }
  }
}

async function waitForExit(profile, duration) {
  const deadline = Date.now() + duration;
  do {
    if (findProcesses(profile).length === 0) return true;
    await new Promise(resolve => setTimeout(resolve, 200));
  } while (Date.now() < deadline);
  return findProcesses(profile).length === 0;
}

async function stopPlayer() {
  if (process.platform !== 'linux') throw new Error('Linux is required');
  const profile = path.join(process.env.XDG_DATA_HOME ||
    path.join(os.homedir(), '.local/share'), 'xiboplayer/chromium');
  const processes = findProcesses(profile);
  const mains = processes.filter(target => target.main);
  signalProcesses(mains.length ? mains : processes, 'SIGTERM', profile);
  if (await waitForExit(profile, 5000)) {
    console.log('[xibo-stop] Player profile stopped');
    return;
  }
  signalProcesses(findProcesses(profile), 'SIGKILL', profile);
  if (!await waitForExit(profile, 2000)) {
    throw new Error('Player profile still has running processes');
  }
  console.log('[xibo-stop] Player profile stopped after forced cleanup');
}

module.exports = { matchesProfile, inspectProcess, findProcesses, stopPlayer };

if (require.main === module) {
  stopPlayer().catch(error => {
    console.error(`[xibo-stop] ${error.message}`);
    process.exitCode = 1;
  });
}
