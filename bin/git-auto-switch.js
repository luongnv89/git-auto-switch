#!/usr/bin/env node
/**
 * git-auto-switch CLI launcher for npm
 *
 * Thin wrapper: all OS detection, package-manager detection, dependency
 * install flows, and banners live in lib/bootstrap.sh — the single
 * implementation shared with the pip launcher and install-curl.sh
 * (F-CLEAN-002). This file only locates the bash CLI and delegates.
 */

const { spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');

// ANSI colors (only what the launcher-local error paths need)
const colors = {
  red: '\x1b[0;31m',
  bold: '\x1b[1m',
  reset: '\x1b[0m'
};

const CROSS = `${colors.red}✗${colors.reset}`;

/**
 * Print the installation-error block and exit 1.
 */
function installationError(missingPath) {
  console.log('');
  console.log(`${colors.bold}${colors.red}━━━ Installation Error ━━━${colors.reset}`);
  console.log('');
  console.log(`  ${CROSS} git-auto-switch files not found`);
  console.log(`     Expected at: ${missingPath}`);
  console.log('');
  console.log('  The package may not be installed correctly.');
  console.log('  Try reinstalling:');
  console.log('');
  console.log('    npm uninstall -g git-auto-switch');
  console.log('    npm install -g git-auto-switch');
  console.log('');
  process.exit(1);
}

/**
 * Main execution
 */
function main() {
  // Find the bash script
  const scriptPath = path.join(__dirname, '..', 'git-auto-switch');
  if (!fs.existsSync(scriptPath)) {
    installationError(scriptPath);
  }

  // The shared dependency bootstrap sits next to the script under lib/.
  const bootstrapPath = path.join(path.dirname(scriptPath), 'lib', 'bootstrap.sh');
  if (!fs.existsSync(bootstrapPath)) {
    installationError(bootstrapPath);
  }

  // Delegate: bootstrap ensures dependencies (installing them with the user's
  // consent when missing), then execs the real CLI with our arguments.
  const result = spawnSync(
    'bash',
    [bootstrapPath, '--target', scriptPath, ...process.argv.slice(2)],
    { stdio: 'inherit' }
  );

  if (result.error) {
    console.log('');
    if (result.error.code === 'ENOENT') {
      console.log(`  ${CROSS} bash not found`);
      console.log('      git-auto-switch requires bash 3.2+ — install it with');
      console.log('      your system package manager, then retry.');
    } else {
      console.log(`  ${CROSS} Failed to execute bash script: ${result.error.message}`);
    }
    console.log('');
    process.exit(1);
  }

  // Propagate the CLI's exit code (null when killed by a signal).
  process.exit(result.status === null ? 1 : result.status);
}

main();
