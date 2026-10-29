// Read-only smoke test through the same public client SDKs and security rules.
import {createRequire} from 'node:module';
import {resolve,join} from 'node:path';
const require=createRequire(join(resolve(process.env.LIVINGWIKI_WEB_ROOT || '../living-wiki'),'package.json'));
const {initializeApp,deleteApp}=require('firebase/app');
const {getFirestore,collection,query,where,limit,getDocs,doc,getDoc}=require('firebase/firestore');
const {getFunctions,httpsCallable}=require('firebase/functions');
const app=initializeApp({apiKey:'AIzaSyBXFeKYpWMMYyH-Ck9dS4x2uPTO7tUY9RI',projectId:'living-atlas-7622a',appId:'1:661893013313:web:e929cf76ab9d8d44614bc0',authDomain:'living-atlas-7622a.firebaseapp.com'});
const db=getFirestore(app),functions=getFunctions(app,'us-central1');
try{
  const atlases=await getDocs(query(collection(db,'atlases'),where('is_public','==',true),limit(3)));
  if(atlases.empty)throw Error('No public atlases returned');
  console.log('PASS: public wiki directory uses client security rules');
  const summaries=await getDocs(query(collection(db,'public_board_summaries'),where('visibility','==','public'),where('is_root','==',true),limit(3)));
  if(summaries.empty)throw Error('No public boards returned');
  const board=await getDoc(doc(db,'boards',summaries.docs[0].id));
  if(!board.exists()||!Array.isArray(board.data().cards))throw Error('Public board did not resolve');
  console.log('PASS: public summaries resolve to real boards and cards');
  const wiki=await httpsCallable(functions,'getPublicWikiContent')({atlasId:atlases.docs[0].id});
  if(!Array.isArray(wiki.data.articles)||!Array.isArray(wiki.data.topics))throw Error('Wiki response contract changed');
  console.log('PASS: public knowledge endpoint matches the native article/topic contract');
  const gems=await fetch('https://us-central1-living-atlas-7622a.cloudfunctions.net/offGridDirectory',{signal:AbortSignal.timeout(30000)});
  if(!gems.ok||!Array.isArray((await gems.json()).items))throw Error('Gem directory did not return items');
  console.log('PASS: Off Grids public directory responds');
}finally{await deleteApp(app);}
