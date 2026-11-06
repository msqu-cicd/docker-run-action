'use strict';
const { spawn } = require('child_process');
const path = require('path');

// Construct the path to the action script
const scriptPath = path.join(__dirname, 'entrypoint.sh');

// Spawn the child process, inheriting stdio so logs are visible
const child = spawn(scriptPath, [], { stdio: 'inherit' });

// Forward signals to the child as SIGTERM so the entrypoint's trap can stop
// and remove the container before exiting.
// https://github.com/ringerc/github-actions-signal-handling-demo
function handleSignal(signal) {
  console.log(`Forwarding signal ${signal} to child process as SIGTERM`);
  child.kill('SIGTERM');
}

process.on('SIGINT', handleSignal);
process.on('SIGTERM', handleSignal);

// Exit this process when the child exits
child.on('exit', (exitCode) => {
  // If exitCode is null, default to 143 (commonly used for SIGTERM)
  exitCode = exitCode !== null ? exitCode : 143;
  process.exit(exitCode);
});
