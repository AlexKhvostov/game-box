// Module-level prototype checks; this does not claim browser or device QA.
import assert from 'node:assert/strict';
globalThis.document={addEventListener(){},querySelector(){return null;}};
const base='../docs/design/simple-energy-bonus-20261016/live-kit/';
const account=await import(base+'account-kit.js');
const ranking=await import(base+'ranking-kit.js');
const stack=[];
ranking.connectRankingKit({open:id=>stack.push(id),refresh(){}});
account.connectAccountKit({openRanking:ranking.openRankingDestination});
const html=account.accountDialog('main');
for(const destination of ['record','average','mine']){
  assert.ok(html.includes(`data-action="acct-ranking-${destination}"`));
  await account.handleAccountAction(`acct-ranking-${destination}`);
  assert.equal(stack.at(-1),destination==='mine'?'ranking-mine':'ranking');
  if(destination!=='mine'){
    const sheet=ranking.rankingSheet();
    const target=destination==='average'?'rank-view-average':'rank-view-record';
    assert.ok(new RegExp(`data-action="${target}"[^>]*aria-selected="true"`).test(sheet));
    if(destination==='average')ranking.handleRankingAction('rank-view-record');
    assert.ok(/data-action="rank-period-all"[^>]*aria-selected="true"/.test(ranking.rankingSheet()));
  }
}
const length=stack.length;ranking.openRankingDestination('invalid');assert.equal(stack.length,length);
console.log(JSON.stringify({ok:true,destinations:3,rejectedUnknown:true,scope:'prototype modules, no browser'}));
