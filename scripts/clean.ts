#!/usr/bin/env tsx
import * as fs from 'fs';
import * as path from 'path';

function removeEmptyDirs(dir: string): void {
  if (!fs.existsSync(dir)) return;

  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      removeEmptyDirs(path.join(dir, entry.name));
    }
  }

  try {
    const entries = fs.readdirSync(dir);
    if (entries.length === 0) {
      fs.rmdirSync(dir);
      console.log(`  Removed: ${dir}`);
    }
  } catch {
    // ignore permission errors
  }
}

const projectRoot = path.resolve(__dirname, '..');
process.chdir(projectRoot);

console.log('빈 폴더 정리를 시작합니다...');
removeEmptyDirs('.');
console.log('정리가 완료되었습니다!');
