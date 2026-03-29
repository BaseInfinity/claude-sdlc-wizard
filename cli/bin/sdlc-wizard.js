#!/usr/bin/env node
'use strict';

const { version } = require('../../package.json');
const { init, check } = require('../init');

const args = process.argv.slice(2);

const flags = {
  force: args.includes('--force'),
  dryRun: args.includes('--dry-run'),
  json: args.includes('--json'),
};

const command = args.find((a) => !a.startsWith('--'));

if (args.includes('--version') || args.includes('-v')) {
  console.log(version);
  process.exit(0);
}

if (args.includes('--help') || args.includes('-h') || !command) {
  console.log(`
  agentic-sdlc-wizard v${version}

  Usage:
    sdlc-wizard init [options]    Install SDLC wizard into current directory
    sdlc-wizard check [options]   Check installation health and updates

  Options:
    --force       Overwrite existing files (init only)
    --dry-run     Preview changes without writing (init only)
    --json        Output as JSON (check only)
    --version     Show version
    --help        Show this help
  `.trim());
  process.exit(0);
}

if (command === 'init') {
  try {
    init(process.cwd(), flags);
    process.exit(0);
  } catch (err) {
    console.error(`Error: ${err.message}`);
    process.exit(1);
  }
} else if (command === 'check') {
  try {
    const { hasDrift } = check(process.cwd(), { json: flags.json });
    process.exit(hasDrift ? 1 : 0);
  } catch (err) {
    console.error(`Error: ${err.message}`);
    process.exit(1);
  }
} else {
  console.error(`Unknown command: ${command}`);
  console.error('Run "sdlc-wizard --help" for usage.');
  process.exit(1);
}
