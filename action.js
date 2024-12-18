'use strict';
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

// Construct the path to the action script
const scriptPath = path.join(__dirname, 'entrypoint.sh');

// Spawn the child process, inheriting stdio so logs are visible
const child = spawn(scriptPath, [], { stdio: 'inherit' });

// Forward signals to the child, escalating INT -> TERM -> KILL
// https://github.com/ringerc/github-actions-signal-handling-demo
function handleSignal(signal) {
  console.log('Forwarding signal ${signal} to child process');
  if (signal === 'SIGINT') {
    signal = 'SIGTERM';
  } else if (signal === 'SIGTERM') {
    signal = 'SIGKILL';
  }
  child.kill(signal);
}

process.on('SIGINT', handleSignal);
process.on('SIGTERM', handleSignal);

// Exit this process when the child exits
child.on('exit', (exitCode) => {
  // If exitCode is null, default to 143 (commonly used for SIGTERM)
  exitCode = exitCode !== null ? exitCode : 143;
  process.exit(exitCode);
});

// Keep the parent process running
setInterval(() => {}, 10000);
