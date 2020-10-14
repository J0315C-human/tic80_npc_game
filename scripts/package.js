const { memory } = require('console');
const fs = require('fs');
const { sep } = require('path');

const SRC = './src';
const CLASSES = `${SRC}/classes`;
const UTILS = `${SRC}/utils`;
const INIT = `${SRC}/init.lua`;
const MAIN = `${SRC}/main.lua`;
const OUTPUTFILE = `./build.lua`;
const OUTPUTMEMCACHE = `./memory.cache.lua`;

console.log("-- Begin lua packaging process...\n")

let output = `-- title:  omni
-- author: joel schuman
-- desc:   people walk around and do stuff
-- script: lua
`;

function addFileToOutput (path){
  try {
    const content = fs.readFileSync(path);
    output = output + '\n' + content;
    console.log(' - added ' + path);
  } catch (e){
    console.log('ERROR: reading ' + path + ' -- ((' + e.message + '))');
  }
}

function addFilesFromDir (dir){
  fs.readdirSync(dir).forEach(item => addFileToOutput(dir + '/' + item));
}

const SEPARATOR_REGEX = /^-- <[\w\s]+>/g;

function getMemoryStuff (fileContents) {
  const separator = fileContents.split('\n').find(line => SEPARATOR_REGEX.test(line));
  const parts = fileContents.split(separator);
  let memoryStuff = "\n\n";
  for (let i = 1; i< parts.length; i++){
    memoryStuff += separator + parts[i];
  }
  return memoryStuff;
}

function cacheTic80Memory () {
  const existingContent = fs.readFileSync(OUTPUTFILE);
  const memoryStuff = getMemoryStuff(existingContent.toString());
  fs.writeFileSync(OUTPUTMEMCACHE, memoryStuff);
}

function writeOutputFile () {
  const memoryStuff = fs.readFileSync(OUTPUTMEMCACHE);
  fs.writeFileSync(OUTPUTFILE, output + memoryStuff);
}
// cache tic80 memory
cacheTic80Memory();

// add initialization stuff
addFileToOutput(INIT);
// add utility functions
addFilesFromDir(UTILS);
// add classes
addFilesFromDir(CLASSES);
// add main script
addFileToOutput(MAIN);


writeOutputFile();

console.log("\n-- Lua packaging process very succeed!\n")