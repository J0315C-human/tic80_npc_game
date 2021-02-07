const { memory } = require('console');
const fs = require('fs');
const { sep } = require('path');

require('dotenv').config({});

// where to copy the output build
const CART_OUT_PATH = process.env.CART_OUT_PATH;

const SRC = './src';
const CLASSES = `${SRC}/classes`;
const UTILS = `${SRC}/utils`;
const INIT = `${SRC}/init.lua`;
const MAIN = `${SRC}/main.lua`;
const OUTPUTFILE = `./build.lua`;
const OUTPUTMEMCACHE = `./memory.cache.lua`;

let output = `-- title:  omni
-- author: joel schuman
-- desc:   people walk around and do stuff
-- script: lua
`;
const consoleColors = [
  "\x1b[32m",
  "\x1b[33m",
  "\x1b[34m",
  "\x1b[35m",
  "\x1b[36m",
  "\x1b[37m",
]
let colorIdx = 0;
const getColor = () => {
  const c = consoleColors[colorIdx];
  colorIdx = (colorIdx + 1) % consoleColors.length;
  return c;
};

function addFileToOutput (path){
  try {
    const content = fs.readFileSync(path);
    output = output + '\n' + content;
    console.log(getColor(), ' - added ' + path);
  } catch (e){
    console.error('ERROR: reading ' + path + ' -- ((' + e.message + '))');
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
  if (CART_OUT_PATH){
    fs.writeFileSync(CART_OUT_PATH, output + memoryStuff);
  }
}


function wait(ms){
  return new Promise(resolve => {
    setTimeout(() => resolve(), ms)
  })
}

async function doPackaging (){
  console.clear();

  console.log(getColor(), "-- Begin lua packaging process...\n")

  await wait(100);

  // cache tic80 memory
  cacheTic80Memory();

  await wait(100);
  // add initialization stuff
  addFileToOutput(INIT);
  await wait(100);

  // add utility functions
  addFilesFromDir(UTILS);
  await wait(100);

  // add classes
  addFilesFromDir(CLASSES);
  await wait(100);

  // add main script
  addFileToOutput(MAIN);

  await wait(100);

  writeOutputFile();

  await wait(100);

  console.log(getColor(), "\n-- Lua packaging process very succeed!\n")
}

doPackaging();