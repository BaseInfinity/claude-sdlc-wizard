#!/usr/bin/env node
'use strict';

const { version } = require('../../package.json');
const { init } = require('../init');

const args = process.argv.slice(2);

const flags = {
  force: args.includes('--force'),
  dryRun: args.includes('--dry-run'),
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

  Options:
    --force       Overwrite existing files
    --dry-run     Preview changes without writing
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
} else {
  console.error(`Unknown command: ${command}`);
  console.error('Run "sdlc-wizard --help" for usage.');
  process.exit(1);
}
