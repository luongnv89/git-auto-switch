#!/usr/bin/env node
/**
 * git-auto-switch CLI wrapper for npm
 * Automatically installs dependencies if missing
 */

const { spawn, execSync, spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');
const readline = require('readline');

// ANSI colors
const colors = {
  green: '\x1b[0;32m',
  red: '\x1b[0;31m',
  yellow: '\x1b[1;33m',
  blue: '\x1b[0;34m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  reset: '\x1b[0m'
};

const CHECK = `${colors.green}✓${colors.reset}`;
const CROSS = `${colors.red}✗${colors.reset}`;
const ARROW = `${colors.blue}→${colors.reset}`;
const WARN = `${colors.yellow}!${colors.reset}`;

/**
 * Check if a command exists and get its version
 */
function checkCommand(cmd) {
  try {
    let version = 'installed';

    if (cmd === 'bash') {
      const output = execSync('bash --version', { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
      const match = output.match(/version (\d+\.\d+)/);
      version = match ? match[1] : 'unknown';
    } else if (cmd === 'git') {
      const output = execSync('git --version', { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
      version = output.replace('git version ', '').trim();
    } else if (cmd === 'jq') {
      const output = execSync('jq --version', { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
      version = output.replace('jq-', '').trim();
    }

    return { installed: true, version };
  } catch (e) {
    return { installed: false, version: 'not installed' };
  }
}

/**
 * Detect operating system
 */
function detectOS() {
  const platform = os.platform();
  if (platform === 'darwin') {
    return 'macos';
  } else if (platform === 'linux') {
    if (fs.existsSync('/etc/debian_version')) {
      return 'debian';
    } else if (fs.existsSync('/etc/redhat-release')) {
      return 'redhat';
    } else if (fs.existsSync('/etc/arch-release')) {
      return 'arch';
    } else if (fs.existsSync('/etc/alpine-release')) {
      return 'alpine';
    }
    return 'linux';
  }
  return platform;
}

/**
 * Detect package manager
 */
function detectPackageManager(osName) {
  if (osName === 'macos') {
    try {
      execSync('which brew', { stdio: ['pipe', 'pipe', 'pipe'] });
      return 'brew';
    } catch (e) {
      return 'none';
    }
  } else if (osName === 'debian') {
    return 'apt';
  } else if (osName === 'redhat') {
    try {
      execSync('which dnf', { stdio: ['pipe', 'pipe', 'pipe'] });
      return 'dnf';
    } catch (e) {
      return 'yum';
    }
  } else if (osName === 'arch') {
    return 'pacman';
  } else if (osName === 'alpine') {
    return 'apk';
  }
  return 'none';
}

/**
 * Get display name for OS
 */
function getOSDisplayName(osName) {
  const names = {
    'macos': 'macOS',
    'debian': 'Debian/Ubuntu',
    'redhat': 'RHEL/CentOS/Fedora',
    'arch': 'Arch Linux',
    'alpine': 'Alpine Linux',
    'linux': 'Linux'
  };
  return names[osName] || osName;
}

/**
 * Install Homebrew on macOS
 */
function installHomebrew() {
  console.log(`  ${ARROW} Installing Homebrew...`);
  try {
    const result = spawnSync('/bin/bash', ['-c', '$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)'], {
      stdio: 'inherit',
      shell: true
    });

    if (result.status === 0) {
      console.log(`  ${CHECK} Homebrew installed`);
      return true;
    } else {
      console.log(`  ${CROSS} Failed to install Homebrew`);
      return false;
    }
  } catch (e) {
    console.log(`  ${CROSS} Failed to install Homebrew: ${e.message}`);
    return false;
  }
}

/**
 * Install a package using the system package manager
 */
function installPackage(pkgManager, pkg) {
  console.log(`  ${ARROW} Installing ${pkg}...`);

  let result;
  try {
    switch (pkgManager) {
      case 'brew':
        result = spawnSync('brew', ['install', pkg], { stdio: 'inherit' });
        break;
      case 'apt':
        spawnSync('sudo', ['apt-get', 'update', '-qq'], { stdio: 'inherit' });
        result = spawnSync('sudo', ['apt-get', 'install', '-y', '-qq', pkg], { stdio: 'inherit' });
        break;
      case 'dnf':
        result = spawnSync('sudo', ['dnf', 'install', '-y', '-q', pkg], { stdio: 'inherit' });
        break;
      case 'yum':
        result = spawnSync('sudo', ['yum', 'install', '-y', '-q', pkg], { stdio: 'inherit' });
        break;
      case 'pacman':
        result = spawnSync('sudo', ['pacman', '-S', '--noconfirm', '--quiet', pkg], { stdio: 'inherit' });
        break;
      case 'apk':
        result = spawnSync('sudo', ['apk', 'add', '--quiet', pkg], { stdio: 'inherit' });
        break;
      default:
        console.log(`  ${CROSS} Unsupported package manager: ${pkgManager}`);
        return false;
    }

    if (result.status === 0) {
      console.log(`  ${CHECK} Installed ${pkg}`);
      return true;
    } else {
      console.log(`  ${CROSS} Failed to install ${pkg}`);
      return false;
    }
  } catch (e) {
    console.log(`  ${CROSS} Failed to install ${pkg}: ${e.message}`);
    return false;
  }
}

/**
 * Check all dependencies
 */
function checkDependencies() {
  const deps = ['bash', 'git', 'jq'];
  const missing = [];

  for (const dep of deps) {
    const { installed } = checkCommand(dep);
    if (!installed) {
      missing.push(dep);
    }
  }

  return missing;
}

/**
 * Print header
 */
function printHeader() {
  console.log('');
  console.log(`${colors.bold}╔════════════════════════════════════════════════════════════╗${colors.reset}`);
  console.log(`${colors.bold}║            git-auto-switch                                 ║${colors.reset}`);
  console.log(`${colors.bold}╚════════════════════════════════════════════════════════════╝${colors.reset}`);
}

/**
 * Print section header
 */
function printSection(title) {
  console.log('');
  console.log(`${colors.bold}${colors.blue}━━━ ${title} ━━━${colors.reset}`);
  console.log('');
}

/**
 * Print system status
 */
function printSystemStatus(osName, pkgManager) {
  printSection('System Status');

  console.log(`  ${colors.bold}Operating System:${colors.reset} ${getOSDisplayName(osName)}`);
  console.log(`  ${colors.bold}Package Manager:${colors.reset}  ${pkgManager}`);
  console.log('');
  console.log(`  ${colors.bold}Required Dependencies:${colors.reset}`);
  console.log('');

  const missing = [];

  // Check bash
  const bash = checkCommand('bash');
  if (bash.installed) {
    console.log(`    ${CHECK} bash     ${colors.dim}v${bash.version} (required: 3.2+)${colors.reset}`);
  } else {
    console.log(`    ${CROSS} bash     ${colors.dim}not installed (required: 3.2+)${colors.reset}`);
    missing.push('bash');
  }

  // Check git
  const git = checkCommand('git');
  if (git.installed) {
    console.log(`    ${CHECK} git      ${colors.dim}v${git.version} (required: 2.13+)${colors.reset}`);
  } else {
    console.log(`    ${CROSS} git      ${colors.dim}not installed (required: 2.13+)${colors.reset}`);
    missing.push('git');
  }

  // Check jq
  const jq = checkCommand('jq');
  if (jq.installed) {
    console.log(`    ${CHECK} jq       ${colors.dim}v${jq.version}${colors.reset}`);
  } else {
    console.log(`    ${CROSS} jq       ${colors.dim}not installed${colors.reset}`);
    missing.push('jq');
  }

  console.log('');

  return missing;
}

/**
 * Prompt user for confirmation
 */
function prompt(question) {
  return new Promise((resolve) => {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });

    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim().toLowerCase());
    });
  });
}

/**
 * Install missing dependencies
 */
async function installDependencies(missing, osName, pkgManager) {
  printSection('Installing Dependencies');

  // Handle macOS without Homebrew
  if (osName === 'macos' && pkgManager === 'none') {
    console.log(`  ${WARN} Homebrew not found`);
    console.log('');

    const response = await prompt('  Install Homebrew? [Y/n] ');
    if (response === 'n' || response === 'no') {
      console.log('');
      console.log(`  ${CROSS} Cannot install dependencies without Homebrew`);
      console.log('');
      console.log('  Please install manually:');
      console.log('    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"');
      for (const dep of missing) {
        console.log(`    brew install ${dep}`);
      }
      return false;
    }

    if (!installHomebrew()) {
      return false;
    }
    pkgManager = 'brew';
  }

  if (pkgManager === 'none') {
    console.log(`  ${CROSS} No supported package manager found`);
    console.log('');
    console.log('  Please install the following manually:');
    for (const dep of missing) {
      console.log(`    - ${dep}`);
    }
    return false;
  }

  // Install each missing dependency
  const installedDeps = [];
  for (const dep of missing) {
    if (installPackage(pkgManager, dep)) {
      installedDeps.push(dep);
    } else {
      console.log('');
      console.log(`  ${CROSS} Failed to install all dependencies`);
      return false;
    }
  }

  console.log('');
  console.log(`  ${CHECK} All dependencies installed: ${installedDeps.join(', ')}`);
  return true;
}

/**
 * Print success summary
 */
function printSuccessSummary() {
  printSection('Ready to Use');

  console.log(`  ${CHECK} All dependencies satisfied`);
  console.log('');
  console.log(`  ${colors.bold}Quick start:${colors.reset}`);
  console.log('');
  console.log('    gas init          # First-time setup');
  console.log('    gas add           # Add a new GitHub account');
  console.log('    gas --help        # Show all commands');
  console.log('');
}

/**
 * Run the bash script
 */
function runScript(scriptPath) {
  const child = spawn(scriptPath, process.argv.slice(2), {
    stdio: 'inherit',
    shell: false
  });

  child.on('error', (err) => {
    if (err.code === 'ENOENT') {
      console.log('');
      console.log(`  ${CROSS} Failed to execute bash script`);
      console.log('      Make sure bash is installed and in your PATH');
      console.log('');
    } else if (err.code === 'EACCES') {
      console.log('');
      console.log(`  ${CROSS} Permission denied executing script`);
      console.log(`      Try: chmod +x ${scriptPath}`);
      console.log('');
    } else {
      console.error('Error:', err.message);
    }
    process.exit(1);
  });

  child.on('close', (code) => {
    process.exit(code || 0);
  });
}

/**
 * Main execution
 */
async function main() {
  // Find the bash script
  const scriptPath = path.join(__dirname, '..', 'git-auto-switch');

  // Check if script exists
  if (!fs.existsSync(scriptPath)) {
    console.log('');
    console.log(`${colors.bold}${colors.red}━━━ Installation Error ━━━${colors.reset}`);
    console.log('');
    console.log(`  ${CROSS} git-auto-switch script not found`);
    console.log(`     Expected at: ${scriptPath}`);
    console.log('');
    console.log('  The package may not be installed correctly.');
    console.log('  Try reinstalling:');
    console.log('');
    console.log('    npm uninstall -g git-auto-switch');
    console.log('    npm install -g git-auto-switch');
    console.log('');
    process.exit(1);
  }

  // Check dependencies
  const missing = checkDependencies();

  if (missing.length > 0) {
    printHeader();

    const osName = detectOS();
    let pkgManager = detectPackageManager(osName);

    // Show current status
    printSystemStatus(osName, pkgManager);

    // Show installation plan
    printSection('Installation Plan');
    console.log(`  ${colors.bold}Actions to perform:${colors.reset}`);
    console.log('');
    for (const dep of missing) {
      console.log(`    ${ARROW} Install ${dep} using ${pkgManager}`);
    }
    console.log('');

    // Ask for confirmation
    const response = await prompt('  Proceed with installation? [Y/n] ');
    if (response === 'n' || response === 'no') {
      console.log('');
      console.log(`  ${WARN} Installation cancelled`);
      console.log('');
      process.exit(0);
    }

    // Install dependencies
    const success = await installDependencies(missing, osName, pkgManager);
    if (!success) {
      process.exit(1);
    }

    // Verify installation
    const stillMissing = checkDependencies();
    if (stillMissing.length > 0) {
      console.log('');
      console.log(`  ${CROSS} Dependencies still missing: ${stillMissing.join(', ')}`);
      process.exit(1);
    }

    printSuccessSummary();
  }

  // Run the bash script
  runScript(scriptPath);
}

main().catch((err) => {
  console.error('Error:', err.message);
  process.exit(1);
});
