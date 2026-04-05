#!/usr/bin/env node
const args = process.argv.slice(2);

if (args.includes('--help')) {
    console.log('Usage: mycli <command> [options]');
    console.log('Commands: process, validate, convert');
    process.exit(0);
}

if (args.length === 0) {
    console.error('Error: No command provided');
    process.exit(1);
}

console.log(`Processing: ${args.join(' ')}`);
