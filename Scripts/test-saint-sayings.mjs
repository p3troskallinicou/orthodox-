import assert from 'node:assert/strict';
import {readFileSync, statSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
const catalog = JSON.parse(readFileSync('Klimax/saint-sayings.json'));
assert.equal(catalog.sayings.length, 188);
assert.equal(catalog.saints.length, 4);
assert.equal(catalog.categories.length, 12);
assert.equal(catalog.photos.length, 29);
for (const key of ['sayings','saints','categories','photos']) assert.equal(new Set(catalog[key].map(x=>x.id)).size,catalog[key].length);
assert(catalog.sayings.every(s=>s.text && s.source && typeof s.sourceChecked==='boolean'));
assert(catalog.categories.every(c=>catalog.sayings.some(s=>s.categoryID===c.id)));
for (const s of catalog.sayings) {
 assert(catalog.saints.some(x=>x.id===s.saintID));
 assert(catalog.categories.some(x=>x.id===s.categoryID));
 assert(catalog.photos.some(x=>x.id===s.photoID));
}
for (const saint of catalog.saints) assert(catalog.photos.some(p=>p.id===saint.photoID));
const porfyriosSource=JSON.parse(readFileSync('data/porfyrios-sayings.json'));
const porfyrios=catalog.sayings.filter(s=>s.saintID==='porfyrios');
assert.deepEqual(porfyrios.map(({id,categoryID,text})=>({id,categoryID,text})),porfyriosSource.sayings);
assert.deepEqual(catalog.categories.filter(c=>c.id.startsWith('porfyrios-')),porfyriosSource.categories);
assert(porfyrios.every(s=>!s.sourceChecked&&!s.featured&&s.sourceStatus===porfyriosSource.sourceStatus));
for (const [file,saintID,count] of [['iakovos-sayings','iakovos-tsalikis',6],['evmenios-sayings','evmenios-saridakis',33],['paisios-haidari-sayings','paisios',116]]) {
 const source=JSON.parse(readFileSync(`data/${file}.json`));
 const actual=catalog.sayings.filter(s=>s.saintID===saintID);
 assert.equal(actual.length,count);assert.deepEqual(actual,source.sayings);
 for (const photo of source.photos) assert.deepEqual(catalog.photos.find(p=>p.id===photo.id),photo);
 if(source.saint) assert.deepEqual(catalog.saints.find(s=>s.id===saintID),source.saint);
}
const paisiosSource=JSON.parse(readFileSync('data/paisios-haidari-sayings.json'));
const coverage=[];
const normal=s=>s.replace(/\s+/g,' ').trim();
for (const quote of paisiosSource.sayings) {
 const block=Number(quote.id.split('-').at(-1));
 const group=paisiosSource.groups[block]??[block];coverage.push(...group);
 assert.equal(normal(quote.text),normal(group.map(n=>paisiosSource.sourceBlocks[n-1]).join(' ')),'Preserve every source word, including dialogue context');
}
assert.deepEqual(coverage.sort((a,b)=>a-b),Array.from({length:129},(_,i)=>i+1));
assert(catalog.sayings.every(s=>!s.id.startsWith('PAI-')),'Retire old IDs instead of assigning different text to saved favourites');
assert.equal(new Set(catalog.sayings.filter(s=>s.saintID==='paisios').map(s=>s.photoID)).size,8);
assert.equal(new Set(catalog.sayings.filter(s=>s.saintID==='evmenios-saridakis').map(s=>s.photoID)).size,9);
for (const saintID of ['porfyrios','evmenios-saridakis','iakovos-tsalikis']) {
 for (const category of catalog.categories) {
  const group=catalog.sayings.filter(s=>s.saintID===saintID&&s.categoryID===category.id);
  assert.equal(new Set(group.map(s=>s.photoID)).size,group.length,'Avoid repeated photos inside these supplied topic groups');
 }
}
let imageBytes=0;
for (const photo of catalog.photos) {
 const path=`Klimax/Assets.xcassets/${photo.asset}.imageset/`;
 const manifest=JSON.parse(readFileSync(path+'Contents.json'));
 const bytes=readFileSync(path+manifest.images[0].filename);imageBytes+=bytes.length;
 assert(bytes[0]===0xff&&bytes[1]===0xd8||bytes.subarray(1,4).toString()==='PNG');
 assert(photo.width>0&&photo.height>0&&photo.subjectTop>=0&&photo.subjectTop<=.8);
 for(const field of ['cardFocusX','reelFocusX','textStart']) if(photo[field]!==undefined)assert(photo[field]>=0&&photo[field]<=1);
}
assert(imageBytes<12_000_000,'Keep the 29 bundled full-resolution photo assets below 12 MB');
const model=readFileSync('Klimax/SaintSayings.swift','utf8');
const swiftTests=`
let catalog = try JSONDecoder().decode(SaintSayingsCatalog.self, from: Data(contentsOf: URL(fileURLWithPath: "Klimax/saint-sayings.json")))
assert(catalog.isValid && catalog.sayings.count == 188)
assert(catalog.categories(for: "paisios").count == 12)
assert(catalog.categories(for: "evmenios-saridakis").count == 10)
assert(catalog.categories(for: "porfyrios").count == 8)
assert(catalog.categories(for: "iakovos-tsalikis").count == 4)
let saved: Set<String> = ["PAI-001", "paisios-haidari-0001", "evmenios-saridakis-0001", "porfyrios-0001"]
assert(SaintSayingFavorites.decode(SaintSayingFavorites.encode(saved)) == saved)
assert(catalog.collection(favoriteIDs: saved).count == 3)
assert(catalog.collection(favoriteIDs: ["PAI-001"]).isEmpty)
assert(SaintSayingFavorites.decode(Data("invalid".utf8)).isEmpty)
let order = Array(catalog.sayings.map(\\.id).reversed())
assert(catalog.collection(order: order).map(\\.id) == order)
let filtered = catalog.collection(categoryID: "porfyrios-prayer-trust", order: order)
assert(filtered.count == 34)
assert(filtered.map(\\.id) == order.filter { id in filtered.contains { $0.id == id } })
assert(catalog.filtered(saintID: "paisios", categoryID: nil, query: "ΟΞΥΓΟΝΟ").count == 2)
assert(catalog.filtered(saintID: "evmenios-saridakis", categoryID: nil, query: "ΣΤΕΝΟΧΩΡΕΙ").count == 1)
for saint in catalog.saints {
 let feed = catalog.collection(saintID: saint.id, order: order)
 assert(!feed.isEmpty && feed.allSatisfy { $0.saintID == saint.id })
 assert(feed.map(\\.id) == order.filter { id in feed.contains { $0.id == id } })
}
assert(catalog.collection(favoriteIDs: saved, order: order).allSatisfy { saved.contains($0.id) })
for natural in [20.0, 180.0, 500.0, 1500.0] {
 for available in [100.0, 350.0, 650.0] {
  let layout = SaintSayingTextLayout(naturalHeight: natural, availableHeight: available, lineHeight: 34)
  assert(layout.needsExpansion == (natural > available))
  assert(layout.height(expanded: false) <= layout.height(expanded: true))
  assert(layout.height(expanded: true) <= available)
  if natural <= available { assert(layout.height(expanded: false) == natural) }
  else { assert(layout.height(expanded: false) <= 204) }
 }
}
for photo in catalog.photos {
 for size in [CGSize(width:175,height:330),CGSize(width:386,height:685),CGSize(width:393,height:852),CGSize(width:430,height:932)] {
  let image = photo.cardImageRect(in: size)
  assert(abs(image.width / image.height - photo.width / photo.height) < 0.001)
  assert(image.minX <= 0 && image.maxX >= size.width - 0.001 && image.height >= size.height - 0.001)
  let text = photo.cardTextRegion(in: size)
  assert(text.minY >= 0 && text.maxY <= size.height + 0.001)
  let immersive = photo.immersiveImageRect(in: size)
  assert(abs(immersive.width / immersive.height - photo.width / photo.height) < 0.001)
  assert(immersive.minX <= 0 && immersive.maxX >= size.width - 0.001 && immersive.height >= size.height - 0.001)
  assert(immersive.minY == 0)
  let subject = immersive.minX + immersive.width * photo.subjectX
  assert(subject >= 0 && subject <= size.width)
  assert(photo.readerTextTop(in: size) >= 86 && photo.readerTextTop(in: size) <= size.height * 0.60)
 }
}
print("PASS: native catalog, retired favourite IDs, filtering, shuffled order, bounded expandable text and photo geometry")
`;
if (!process.argv.includes('--data-only')) {
 const result=spawnSync('swift',['-module-cache-path','/tmp/klimax-sayings-test-cache','-'],{input:model+swiftTests,encoding:'utf8'});
 process.stdout.write(result.stdout??'');process.stderr.write(result.stderr??'');assert.equal(result.status,0);
} else console.log('SKIP: Swift runtime assertions (--data-only); native compilation is verified by the simulator workflow.');
const ui=readFileSync('Klimax/SaintSayingsView.swift','utf8');
assert(!ui.includes('if next == .mixed { showsFeed = true }'), 'Collection changes must not present another screen');
assert(ui.includes('sayings.openFeed') && ui.includes('sayings.feed.saint'));
assert(!ui.includes('portraitReaderPage'), 'All readers use the same photographic background');
assert(ui.includes('SayingArtwork(photo: photo)'));
console.log(`PASS: 188 source-preserved entries, 12 categories, four saints, 29 image assets (${Math.round(imageBytes/1024)} KB), all 129 Paisios source blocks covered.`);
