// Tests the exact Dart-generated board against the web project's existing rules.
// Never connects to production: rules-unit-testing requires an emulator host.
import { createRequire } from 'node:module';
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { resolve, join, delimiter } from 'node:path';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
const webRoot = resolve(process.env.LIVINGWIKI_WEB_ROOT || '../living-wiki');
const script = resolve(import.meta.filename);
if (!process.env.FIRESTORE_EMULATOR_HOST) {
  const temp = mkdtempSync(join(tmpdir(), 'livingwiki-mobile-rules-'));
  const config = join(temp, 'firebase.json');
  writeFileSync(config, JSON.stringify({firestore:{rules:join(webRoot,'firestore.rules')},emulators:{firestore:{host:'127.0.0.1',port:8187,websocketPort:9187},hub:{port:4487},logging:{port:4587},ui:{enabled:false}}}));
  const javaHome = spawnSync('/usr/libexec/java_home', [], {encoding:'utf8'}).stdout?.trim();
  const env = {...process.env, ...(javaHome ? {JAVA_HOME:javaHome,PATH:join(javaHome,'bin')+delimiter+process.env.PATH} : {})};
  const result = spawnSync('firebase',['emulators:exec','--project','demo-livingwiki-mobile','--config',config,'--only','firestore',`node ${JSON.stringify(script)}`],{stdio:'inherit',env});
  rmSync(temp,{recursive:true,force:true}); process.exit(result.status ?? 1);
}
const require = createRequire(join(webRoot,'package.json'));
const {initializeTestEnvironment,assertSucceeds,assertFails} = require('@firebase/rules-unit-testing');
const {doc,setDoc,updateDoc,getDoc,serverTimestamp} = require('firebase/firestore');
const fixture = JSON.parse(readFileSync(process.env.BOARD_FIXTURE || '/tmp/livingwiki-mobile-board.json','utf8'));
const env = await initializeTestEnvironment({projectId:'demo-livingwiki-mobile',firestore:{rules:readFileSync(join(webRoot,'firestore.rules'),'utf8')}});
try {
  await env.withSecurityRulesDisabled(async ctx => {
    await setDoc(doc(ctx.firestore(),'users','test-user'),{id:'test-user',role:'user'});
  });
  const db = env.authenticatedContext('test-user',{email:'test@example.test',email_verified:true}).firestore();
  const ref = doc(db,'boards',fixture.id);
  await assertSucceeds(setDoc(ref,{...fixture,server_updated_at:serverTimestamp()}));
  console.log('PASS: native unlisted board is accepted for a regular user');
  await assertSucceeds(updateDoc(ref,{title:'Native edit',cards:[{id:'card-1',title:'A story',notes:'Words',status:'saved'}],imageUrl:'',description:'Edited',socialVideoRenderVersion:'',socialLandscapeVideoRenderVersion:'',trailerVideoRenderVersion:'',trailerLandscapeVideoRenderVersion:'',trailerVideoSourceFingerprint:'',studioSaveNonce:'cards:mobile-test',updated_at_iso:new Date().toISOString(),server_updated_at:serverTimestamp()}));
  console.log('PASS: native focused card edits are accepted');
  await assertFails(updateDoc(ref,{owner_user_id:'another-user',server_updated_at:serverTimestamp()}));
  console.log('PASS: ownership spoofing is rejected');
  await assertFails(setDoc(doc(db,'boards','private-without-membership'),{...fixture,id:'private-without-membership',visibility:'private',server_updated_at:serverTimestamp()}));
  console.log('PASS: private boards retain existing membership enforcement');
  const guest = env.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(guest,'boards',fixture.id)));
  console.log('PASS: a shared unlisted board can be read by its link');
  const nearby = JSON.parse(readFileSync(process.env.NEARBY_FIXTURE || '/tmp/livingwiki-nearby-board.json','utf8'));
  await env.withSecurityRulesDisabled(async ctx => {
    await setDoc(doc(ctx.firestore(),'nearby_gem_generation_grants',nearby.id),{owner_user_id:'test-user',board_id:nearby.id,expires_at:new Date(Date.now()+86400000)});
  });
  const nearbyRef = doc(db,'boards',nearby.id);
  await assertSucceeds(setDoc(nearbyRef,{...nearby,server_updated_at:serverTimestamp()}));
  console.log('PASS: native Nearby Gems private save works without membership using its generation grant');
  await assertSucceeds(updateDoc(nearbyRef,{title:'Edited gems',server_updated_at:serverTimestamp()}));
  console.log('PASS: a saved Nearby Gems board remains editable');
  await assertFails(setDoc(doc(db,'boards','wrong-grant-board'),{...nearby,id:'wrong-grant-board',server_updated_at:serverTimestamp()}));
  console.log('PASS: Nearby Gems grant cannot create a different board');
  const other = env.authenticatedContext('another-user').firestore();
  await assertFails(setDoc(doc(other,'boards',nearby.id),{...nearby,owner_user_id:'another-user',server_updated_at:serverTimestamp()}));
  console.log('PASS: Nearby Gems grant cannot be reused by another account');
  await assertFails(getDoc(doc(guest,'boards',nearby.id)));
  console.log('PASS: guests cannot read a private Nearby Gems board');

} finally {await env.cleanup();}
