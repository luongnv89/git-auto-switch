/**
 * git-auto-switch
 * Manage multiple GitHub accounts with automatic identity switching based on workspace folders
 *
 * This is a bash CLI tool. For programmatic usage, use child_process to execute
 * the git-auto-switch command directly.
 */

const path = require('path');

module.exports = {
  scriptPath: path.join(__dirname, 'git-auto-switch'),
};
