// Exercise the shipped IFrame command bridge with a player spy, without network.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync('Sources/Muses/Platform/iOS/YouTubeIFrame/YouTubeIFrameAdapter.swift', 'utf8');
const js = source.match(/<script>\s*([\s\S]*?)<\/script><script src=/)[1];
const calls = [];
const context = vm.createContext({ window: { webkit: { messageHandlers: { eratoPlayer: { postMessage() {} } } } }, setInterval() {}, calls });
vm.runInContext(js, context);
for (const state of [-1, 0, 1, 2, 3, 5]) {
  calls.length = 0;
  vm.runInContext(`active = {videoID:'dQw4w9WgXcQ', generation:'7'};
    player = {getPlayerState:()=>${state}, seekTo:(...a)=>calls.push(['seek',...a]),
      cueVideoById:o=>calls.push(['cue',o.videoId,o.startSeconds]), playVideo:()=>calls.push(['play'])};
    window.eratoCommand({action:'bookmark',generation:'6',position:2});`, context);
  assert.equal(calls.length, 0, 'stale generation rejected');
  vm.runInContext(`window.eratoCommand({action:'bookmark',generation:'7',position:12.345});`, context);
  assert.equal(calls.length, 1);
  assert.equal(calls[0][0], state === 2 ? 'seek' : 'cue');
  assert.equal(calls[0][state === 2 ? 1 : 2], 12.345);
  assert.ok(!calls.some(c => c[0] === 'play'), 'bookmark never issues play');
  for (const value of ['NaN', 'Infinity', '-1']) {
    vm.runInContext(`window.eratoCommand({action:'bookmark',generation:'7',position:${value}});`, context);
  }
  assert.equal(calls.length, 1, 'invalid positions rejected');
}
console.log('Bookmark command contract passed: ready command, generation, paused seek, cue without autoplay, invalid time.');
