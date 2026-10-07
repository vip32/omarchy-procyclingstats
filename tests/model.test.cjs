const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(__dirname + '/../Model.js', 'utf8'), model);
const stamp = '2026-09-27T12:00:00Z';
const now = Date.parse(stamp) + 60000;
const path = 'race/fictional/2026/result';
const race = {path,name:'Fictional race'};
const cached = {fetchedAt:stamp,eventsFetchedAt:stamp};
const event = (text,marker='42') => ({text,marker});
const plain = value => JSON.parse(JSON.stringify(value));

test('next route point uses the closest remaining climb or sprint, independent of source ordering', () => {
    const detail={kmDone:148.2,keypoints:[{name:'Later sprint',km:181},{name:'Passed climb',km:140},{name:'Next climb',km:163.4}]};
    assert.deepEqual(plain(model.nextKeypoint(detail)),{name:'Next climb',km:163.4,remaining:15.2});
    assert.equal(detail.keypoints[0].name,'Later sprint');
});
test('missing progress cannot be treated as the start of the route', () => {
    for(const kmDone of [null,undefined,NaN]) assert.equal(model.nextKeypoint({kmDone,keypoints:[{km:10}]}),null);
});
test('zero progress and arriving exactly at a keypoint remain valid', () => {
    assert.equal(model.nextKeypoint({kmDone:0,keypoints:[{km:10}]}).remaining,10);
    assert.equal(model.nextKeypoint({kmDone:10,keypoints:[{km:10}]}).remaining,0);
});
test('no future route point is invented from missing or passed coordinates', () => {
    assert.equal(model.nextKeypoint({kmDone:15,keypoints:[{km:null},{},{km:10}]}),null);
});

test('settings reject malformed values, bound intervals, and default notifications off', () => {
    const s=model.settings({refreshIntervalSec:-1,overviewIntervalSec:60,resultsIntervalSec:Infinity,eventNotifications:'true',notificationDurationSec:0});
    const expected={refreshIntervalSec:60,overviewIntervalSec:300,resultsIntervalSec:300,eventNotifications:false,notificationDurationSec:8};
    for(const key of Object.keys(expected)) assert.equal(s[key],expected[key]);
    assert.equal(model.settings({notificationDurationSec:99}).notificationDurationSec,30);
    assert.equal(model.settings({notificationDurationSec:1}).notificationDurationSec,5);
});
test('each source uses its own refresh interval', () => {
    const s={refreshIntervalSec:90,overviewIntervalSec:600,resultsIntervalSec:1200};
    assert.equal(model.requestInterval('',false,s),600000);
    assert.equal(model.requestInterval(path,false,s),90000);
    assert.equal(model.requestInterval(path,true,s),1200000);
});
test('rejected first fetch warns even with no cached data', () => {
    const issues=model.updateIssues({},'',{state:'blocked'}, {},'',now);
    const warning=model.warning(issues,now,now+900000,false);
    assert.equal(warning.visible,true);
    assert.match(warning.text,/No successful update yet/);
    assert.match(warning.text,/15m/);
});
test('offline warning retains the last successful timestamp during reconnection', () => {
    const issues=model.updateIssues({},path,{state:'offline'},cached,race.name,now);
    const warning=model.warning(issues,now,0,true);
    assert.match(warning.text,/Last successful update 1m ago/);
    assert.match(warning.text,/Reconnecting/);
});
test('events-only rejection remains visible after race-list success', () => {
    let issues=model.updateIssues({},path,{state:'ready',eventsState:'rate-limited'},cached,race.name,now);
    issues=model.updateIssues(issues,'',{state:'ready',races:[race]},cached,'',now+1);
    assert.equal(Object.keys(issues).length,1);
    assert.match(model.warning(issues,now,0,false).text,/Race events/);
});
test('failure clears only after the affected source recovers', () => {
    let issues=model.updateIssues({},path,{state:'ready',eventsState:'blocked'},cached,race.name,now);
    issues=model.updateIssues(issues,path,{state:'offline'},cached,race.name,now+1);
    assert.equal(Object.keys(issues).length,2);
    issues=model.updateIssues(issues,path,{state:'ready',eventsState:'ready'},cached,race.name,now+2);
    assert.equal(model.warning(issues,now,0,false).visible,false);
});
test('missing optional events do not claim the connection is down', () => {
    const issues=model.updateIssues({},path,{state:'ready',eventsState:'unavailable'},cached,race.name,now);
    assert.equal(model.warning(issues,now,0,false).visible,false);
});
test('profile rejection keeps its own warning until that source recovers', () => {
    let issues=model.updateIssues({},path,{state:'ready',profileState:'blocked'}, {profileFetchedAt:stamp},race.name,now);
    issues=model.updateIssues(issues,path,{state:'ready',eventsState:'ready',classifications:[]},cached,race.name,now+1);
    assert.match(model.warning(issues,now,0,false).text,/Course profile/);
    assert.equal(issues[path+'/profile'].lastSuccess,stamp);
    issues=model.updateIssues(issues,path,{state:'ready',profileState:'ready'},cached,race.name,now+2);
    assert.equal(Object.keys(issues).length,0);
});
test('missing optional profile is not a connection failure', () => {
    const issues=model.updateIssues({},path,{state:'ready',profileState:'unavailable'},cached,race.name,now);
    assert.equal(model.warning(issues,now,0,false).visible,false);
});
test('results-only failures clear with published classification and retired races are pruned', () => {
    let issues=model.updateIssues({},path,{state:'ready',resultsState:'error'},cached,race.name,now);
    assert.equal(Object.keys(issues).length,1);
    issues=model.updateIssues(issues,path,{state:'ready',classifications:[]},cached,race.name,now+1);
    assert.equal(Object.keys(issues).length,0);
    issues=model.updateIssues({},path,{state:'offline'},cached,race.name,now);
    issues=model.updateIssues(issues,'',{state:'empty',races:[]},cached,'',now);
    assert.equal(Object.keys(issues).length,0);
});
test('enabling notifications establishes a baseline without replaying old events', () => {
    assert.equal(model.newEvents(undefined,[event('old')],now,300000).fresh.length,0);
});
test('only new events notify, including matching text at a different distance', () => {
    const first=model.newEvents(null,[event('old')],now,300000);
    const next=model.newEvents(first.baseline,[event('new'),event('old')],now+60000,300000);
    assert.deepEqual(plain(next.fresh),[event('new')]);
    assert.equal(model.newEvents(next.baseline,[event('new'),event('old')],now+120000,300000).fresh.length,0);
    assert.equal(model.newEvents(next.baseline,[event('old','41'),event('old')],now+120000,300000).fresh.length,1);
});
test('long outages reset the notification baseline rather than replaying a backlog', () => {
    const first=model.newEvents(null,[event('old')],now,300000);
    assert.equal(model.newEvents(first.baseline,[event('new')],now+900000,300000).fresh.length,0);
});
test('notification memory and burst summaries are bounded', () => {
    const events=Array.from({length:60},(_,i)=>event('event '+i));
    let baseline;
    for(let i=0;i<10;i++) baseline=model.newEvents(baseline,events.map(e=>event(e.text+' '+i)),now+i*1000,300000).baseline;
    assert.equal(baseline.keys.length,180);
    const args=model.notificationArgs('Fictional race',events,5);
    assert.equal(args[args.indexOf('-t')+1],'5000');
    assert.match(args.at(-1),/57 more/);
    assert.equal(args[args.indexOf('-u')+1],'low');
});
test('remote strings stay in prefixed positional arguments and cannot become options', () => {
    const args=model.notificationArgs('--exec', [event('--exec $(touch /tmp/no)')],0);
    assert.equal(args.at(-2),'Race events · --exec');
    assert.match(args.at(-1),/^Race update: /);
    assert.equal(args.includes('--exec'),false);
    assert.equal(args[args.indexOf('-t')+1],'8000');
});
test('notification body escapes markup from remote events', () => {
    const args=model.notificationArgs('Test',[event('<b>Attack</b> & chase')],8);
    assert.match(args.at(-1),/&lt;b&gt;Attack&lt;\/b&gt; &amp; chase/);
    assert.equal(args.at(-1).includes('<b>'),false);
});


test('calendar stepping uses local dates across year and DST boundaries', () => {
    process.env.TZ='Europe/Amsterdam';
    assert.equal(model.dayKey(new Date('2026-12-31T23:30:00+01:00').getTime(),1),'2027-01-01');
    assert.equal(model.dayKey(new Date('2026-03-29T00:30:00+01:00').getTime(),-1),'2026-03-28');
    assert.equal(model.dayKey(new Date('2026-10-25T23:30:00+01:00').getTime(),1),'2026-10-26');
});
test('calendar polling shares the race list interval', () => {
    assert.equal(model.requestInterval('day:2026-09-28',false,{overviewIntervalSec:600}),600000);
});
test('today success preserves failures for cached dates and their races', () => {
    const old={'day:2026-09-26':{path:'day:2026-09-26'},[path]:{path}};
    assert.equal(Object.keys(model.updateIssues(old,'',{state:'ready',races:[],retainedRaces:[race]}, {},'',now)).length,2);
});

test('all categories and levels are selected by default; malformed filters fall back safely', () => {
    const defaults=model.settings({minimumRaceLevel:'bogus',categoryME:'false'});
    assert.equal(defaults.minimumRaceLevel,'All');
    assert.equal(model.categories().length,13);
    for(const c of model.categories()) assert.equal(defaults[c.key],true);
    assert.equal(model.matchesRace({},defaults),true);
    assert.equal(model.filtersActive(defaults),false);
});
test('category checkboxes combine independently and never confuse road with time trial', () => {
    const selection=Object.fromEntries(model.categories().map(c=>[c.key,false]));
    selection.categoryME=true;selection.categoryWETT=true;
    for(const c of model.categories()) assert.equal(model.matchesRace({competitionCategory:c.code},selection),['ME','WE (TT)'].includes(c.code));
    assert.equal(model.matchesRace({},selection),false);
    selection.categoryME=false;selection.categoryWETT=false;
    assert.equal(model.matchesRace({competitionCategory:'ME'},selection),false);
});
test('minimum level applies equally to one-day and stage races, men and women', () => {
    for(const prefix of ['1','2']) {
        for(const cls of ['Pro','UWT','WWT']) assert.equal(model.matchesRace({category:'WE · '+prefix+'.'+cls},{minimumRaceLevel:'ProSeries+'}),true);
        for(const cls of ['1','2','2U']) assert.equal(model.matchesRace({raceClass:prefix+'.'+cls},{minimumRaceLevel:'ProSeries+'}),false);
        assert.equal(model.matchesRace({raceClass:prefix+'.1'},{minimumRaceLevel:'Class 1+'}),true);
        assert.equal(model.matchesRace({raceClass:prefix+'.Pro'},{minimumRaceLevel:'WorldTour'}),false);
    }
});
test('championships keep their category filter at every level; unranked classes need All', () => {
    for(const cls of ['WC','CC','NC','JR']) {
        assert.equal(model.matchesRace({competitionCategory:'WE',raceClass:cls},{minimumRaceLevel:'WorldTour'}),true);
        assert.equal(model.matchesRace({competitionCategory:'WE',raceClass:cls},{minimumRaceLevel:'WorldTour',categoryWE:false}),false);
    }
    for(const cls of ['','2.Ncup','unknown']) {
        assert.equal(model.matchesRace({raceClass:cls},{}),true);
        assert.equal(model.matchesRace({raceClass:cls},{minimumRaceLevel:'Class 2+'}),false);
    }
});
test('metadata request failures stay visible until metadata itself recovers', () => {
    let issues=model.updateIssues({},'',{state:'ready',metadataState:'blocked'},{metadataFetchedAt:stamp},'',now);
    assert.equal(issues['overview/metadata'].lastSuccess,stamp);
    issues=model.updateIssues(issues,'',{state:'ready',races:[]},{},'',now);
    assert.equal(Object.keys(issues).length,1);
    issues=model.updateIssues(issues,'',{state:'ready',metadataState:'ready'},{},'',now);
    assert.equal(Object.keys(issues).length,0);
});

test('saved calendar count defaults to 25 and clamps malformed or out of range settings', () => {
    for (const [value,expected] of [[undefined,25],['oops',25],[-4,25],[5,10],[500,100],[40,40]])
        assert.equal(model.settings({archiveRaceCount:value}).archiveRaceCount,expected);
});
test('archive lists filter before limiting and order nearest dates first', () => {
    const records=[
        {path:'a',name:'A',date:'2026-09-20',status:'finished',raceClass:'1.Pro',competitionCategory:'ME'},
        {path:'b',name:'B',date:'2026-09-25',status:'finished',raceClass:'1.1',competitionCategory:'ME'},
        {path:'c',name:'C',date:'2026-09-28',status:'scheduled',raceClass:'1.Pro',competitionCategory:'WE'},
        {path:'d',name:'D',date:'2026-09-29',status:'scheduled',raceClass:'1.Pro',competitionCategory:'ME'}];
    const opts={minimumRaceLevel:'ProSeries+'};
    assert.deepEqual(plain(model.archiveRows(records,'recent','2026-09-27',opts,1)).map(r=>r.path),['a']);
    assert.deepEqual(plain(model.archiveRows(records,'upcoming','2026-09-27',opts,1)).map(r=>r.path),['c']);
    assert.equal(records[0].path,'a');
});
test('archive merges deduplicate races across dates, retain partial failures and reset on successful refresh', () => {
    const a={path:'a',name:'A',date:'2026-09-25',status:'finished'};
    const old={races:[a],dates:['2026-09-25'],fetchedAt:stamp,nextDate:'2026-09-24'};
    const partial={state:'blocked',races:[{...a,date:'2026-09-24'},{path:'b',date:'2026-09-24'}],dates:['2026-09-24'],nextDate:'2026-09-23'};
    const merged=model.mergeArchive(old,partial,'recent','2026-09-27');
    assert.equal(merged.races.length,2);assert.equal(merged.races[0].date,a.date);
    assert.equal(merged.fetchedAt,stamp);assert.equal(merged.nextDate,'2026-09-23');
    assert.equal(model.mergeArchive({...old,reset:true},{state:'empty',races:[],dates:[]},'recent','2026-09-27').races.length,0);
});

test('a partially successful refresh keeps new pages when the failed page is retried', () => {
    const partial=model.mergeArchive({reset:true,races:[{path:'old',date:'2026-01-01'}],dates:['2026-01-01']},
        {state:'blocked',races:[{path:'new',date:'2026-09-27'}],dates:['2026-09-27'],nextDate:'2026-09-26'},'recent','2026-09-27');
    const recovered=model.mergeArchive(partial,{state:'empty',races:[],dates:['2026-09-26']},'recent','2026-09-27');
    assert.deepEqual(plain(recovered.races).map(r=>r.path),['new']);
    assert.deepEqual(plain(recovered.dates),['2026-09-26','2026-09-27']);
});

test('an isolated profile error does not claim live updates are down', () => {
    const issues=model.updateIssues({},path,{state:'ready',profileState:'error',profileError:'PCS returned HTTP 500.'},cached,race.name,now);
    const warning=model.warning(issues,now,0,false);
    assert.equal(warning.title,'Course profile unavailable');
    assert.match(warning.text,/HTTP 500/);
    assert.doesNotMatch(warning.text,/Previously fetched data may be out of date|No successful update yet/);
});
test('profile rejection still identifies the shared cooldown', () => {
    const issues=model.updateIssues({},path,{state:'ready',profileState:'blocked',profileError:'PCS rejected access.'},cached,race.name,now);
    const warning=model.warning(issues,now,now+900000,false);
    assert.equal(warning.title,'PCS updates paused');
    assert.match(warning.text,/15m/);
});
test('a recent optional error cannot obscure a primary connection failure', () => {
    let issues=model.updateIssues({},'',{state:'offline',error:'Could not connect.'},cached,'',now);
    issues=model.updateIssues(issues,path,{state:'ready',profileState:'error',profileError:'PCS returned HTTP 500.'},cached,race.name,now+1);
    const warning=model.warning(issues,now+1,0,false);
    assert.equal(warning.title,'Live updates unavailable');
    assert.match(warning.text,/Could not connect/);
});

test('course metadata fills missing fields without replacing live progress or vectors', () => {
    const merged=model.withCourse({kmDone:42,distance:180,profile:[[0,10],[100,90]]},{distance:170,profileImage:'data:image/png;base64,x',profileLabel:'Stage 8'});
    assert.equal(merged.distance,180);assert.equal(merged.kmDone,42);assert.equal(merged.profileImage,undefined);assert.equal(merged.profileLabel,'Stage 8');
    const empty=model.withCourse({profile:[]},{distance:170,profileImage:'image',profileImageWidth:600});
    assert.equal(empty.profileImage,'image');assert.equal(empty.distance,170);
});
test('course snapshots exclude classification and event payloads', () => {
    const snapshot=model.courseSnapshot({state:'ready',distance:170,events:['old'],classifications:['large'],profileImage:'image'});
    assert.equal(snapshot.distance,170);assert.equal(snapshot.events,undefined);assert.equal(snapshot.classifications,undefined);
});

const trace=vm.createContext({});
vm.runInContext(fs.readFileSync(__dirname+'/../ProfileTrace.js','utf8').replace(/^\.pragma library\s*/,''),trace);
function elevationPixels(gap=false) {
    const w=120,h=60,pixels=new Uint8ClampedArray(w*h*4).fill(255);
    for(let x=3;x<117;x++)for(let y=Math.round(15+20*Math.abs((x-60)/60));y<55;y++) {
        if(gap && x>40 && x<62)continue;
        const i=(y*w+x)*4;pixels[i]=142;pixels[i+1]=190;pixels[i+2]=45;
    }
    return pixels;
}
test('raster tracing follows the published green silhouette and normalizes its extent', () => {
    const outline=trace.outline(elevationPixels(),120,60);
    assert.ok(outline.length>40);assert.equal(outline[0][0],0);assert.equal(outline.at(-1)[0],100);
    const peak=outline.reduce((a,b)=>a[1]<b[1]?a:b);
    assert.ok(peak[0]>45 && peak[0]<55);assert.ok(outline[0][1]>peak[1]);
});
test('tracing rejects empty or unrelated image content and excessive pixel counts', () => {
    assert.equal(trace.outline(new Uint8ClampedArray(120*60*4).fill(255),120,60).length,0);
    assert.equal(trace.outline([],4096,2048).length,0);
});
test('tracing does not bridge a large missing section of the elevation image', () => {
    assert.equal(trace.outline(elevationPixels(true),120,60).length,0);
});
test('traced outlines have a bounded shared cache, including failed traces', () => {
    trace.remember('old',[]);assert.deepEqual(plain(trace.cached('old')),[]);
    for(let i=0;i<40;i++)trace.remember('image'+i,[[0,1],[100,2]]);
    assert.equal(trace.cached('old'),null);assert.equal(trace.cached('image39').length,2);
});


test('calendar tab preference restores Upcoming and falls back to Recent', () => {
    assert.equal(model.settings({calendarTab:'upcoming'}).calendarTab,'upcoming');
    for (const value of [undefined,null,'recent','invalid',42])
        assert.equal(model.settings({calendarTab:value}).calendarTab,'recent');
});

test('detail tabs and spoiler protection have safe persisted defaults', () => {
    assert.equal(model.settings({}).detailTab,'overview');
    assert.equal(model.settings({detailTab:'events'}).detailTab,'events');
    assert.equal(model.settings({detailTab:'invalid'}).detailTab,'overview');
    assert.equal(model.settings({}).revealMode,true);
    assert.equal(model.settings({revealMode:false}).revealMode,false);
    assert.equal(model.settings({revealMode:'false'}).revealMode,true);
});
test('finished results stay concealed until this race is revealed or protection is disabled', () => {
    assert.equal(model.resultsHidden(true,'finished','',false),true);
    assert.equal(model.resultsHidden(true,'live','finished',false),true);
    assert.equal(model.resultsHidden(true,'finished','finished',true),false);
    assert.equal(model.resultsHidden(false,'finished','finished',false),false);
    assert.equal(model.resultsHidden(true,'live','live',false),false);
    assert.equal(model.resultsHidden(true,'scheduled','',false),false);
});

test('pins validate, deduplicate and persist as edition keys across stage URLs', () => {
    const a='race/tour/2026/stage-1',b='race/tour/2026/gc';
    const pins=model.togglePin(a,[]);
    assert.equal(model.isPinned(b,pins),true);
    assert.equal(model.isPinned('race/tour/2027/gc',pins),false);
    assert.deepEqual(plain(model.settings(JSON.parse(JSON.stringify({pinnedRaces:pins}))).pinnedRaces),['race/tour/2026']);
    assert.deepEqual(plain(model.togglePin(b,pins)),[]);
    assert.deepEqual(plain(model.normalizePins([a,b,'https://evil.invalid','race/../2026/result',null])),['race/tour/2026']);
    assert.deepEqual(plain(model.normalizePins('bad')),[]);
    assert.equal(model.normalizePins(Array.from({length:150},(_,i)=>`race/tour-${i}/2026`)).length,100);
});
test('pins sort stably inside eligible lists and before archive limits', () => {
    const rows=['a','b','c'].map(name=>({path:`race/${name}/2026/result`,name,date:'2026-10-05',status:'finished',competitionCategory:'ME',raceClass:'1.Pro'}));
    assert.deepEqual(plain(model.pinnedFirst(rows,['race/c/2026']).map(r=>r.name)),['c','a','b']);
    assert.deepEqual(rows.map(r=>r.name),['a','b','c']);
    assert.equal(model.archiveRows(rows,'recent','2026-10-06',{pinnedRaces:['race/c/2026']},1)[0].name,'c');
    assert.equal(model.archiveRows(rows,'recent','2026-10-06',{pinnedRaces:['race/c/2026'],categoryME:false},10).length,0);
});
test('stage neighbors respect published gaps, split stages and GC current stage', () => {
    const stages=['1','2a','2b','4'].map(n=>({path:`race/tour/2026/stage-${n}`}));
    assert.equal(model.stageNeighbor({path:stages[0].path,stages},-1),null);
    assert.equal(model.stageNeighbor({path:stages[1].path,stages},1).path,stages[2].path);
    assert.equal(model.stageNeighbor({path:'race/tour/2026/gc',stagePath:stages[2].path,stages},1).path,stages[3].path);
    assert.equal(model.stageNeighbor({path:'race/tour/2026/gc',stages},1),null);
});
const group=(label,gap,ids=[])=>({label,gap,count:ids.length,riders:ids.map(id=>({id,name:id}))});
const gapSnapshot=(seconds,groups,extra={})=>({path,status:'live',state:'ready',sourceAt:new Date(now+seconds*1000).toISOString(),groups,...extra});
const originalGroups=()=>[group('Front','+0:00',['a','b']),group('Group 2','+1:12',['c','d']),group('Peloton','+2:03')];
test('gap trends match rider membership, not order or group number', () => {
    const before=gapSnapshot(-60,originalGroups());
    const after=gapSnapshot(0,[group('Front','+0:00',['b','a']),group('Peloton','+2:13'),group('Chase','+0:58',['d','c'])]);
    const groups=model.gapTrends(before,after,now,180000);
    assert.deepEqual(plain(groups.map(g=>g.gapDelta)),[null,10,-14]);
    assert.equal(model.gapTrendText(groups[1],true),' ↓');
    assert.equal(model.gapTrendText(groups[2],true),' ↑');
    assert.equal(model.gapTrendText(groups[2],false),'');
    assert.equal(before.groups[1].gapDelta,undefined);
});
test('gap trends disappear for stale, failed, repeated or changed-front snapshots', () => {
    const before=gapSnapshot(-60,originalGroups());
    for(const after of [gapSnapshot(-60,originalGroups()),gapSnapshot(-120,originalGroups()),gapSnapshot(0,originalGroups(),{status:'finished'}),gapSnapshot(0,originalGroups(),{state:'blocked'}),gapSnapshot(0,originalGroups(),{path:'race/other/2026/result'}),gapSnapshot(0,[group('Front','+0:00',['new']),group('Peloton','+1:02')])])
        assert.ok(model.gapTrends(before,after,now,180000).every(g=>g.gapDelta===null));
    assert.ok(model.gapTrends(before,gapSnapshot(0,originalGroups()),now+600000,180000).every(g=>g.gapDelta===null));
    assert.ok(model.gapTrends({...before,state:'blocked'},gapSnapshot(0,originalGroups()),now,180000).every(g=>g.gapDelta===null));
});
test('gap trends never compare uncertain, truncated, split or anonymous numbered groups', () => {
    const before=gapSnapshot(-60,originalGroups());
    for(const chase of [group('Group 2','+0:50',['c']),{...group('Chase','+0:50',['c','d']),uncertain:true},{...group('Chase','+0:50',['c','d']),omitted:4},group('Group 2','+0:50'),group('Chase','unknown',['c','d'])])
        assert.equal(model.gapTrends(before,gapSnapshot(0,[originalGroups()[0],chase]),now,180000)[1].gapDelta,null);
    assert.equal(model.gapSeconds('+1:02:03'),3723);
    assert.equal(model.gapSeconds('+1:99'),null);
});

test('preview is a boolean when returning from tomorrow to a live race with no stage flag', () => {
    assert.equal(model.racePreview({date:'2026-10-07'},{},'2026-10-06',false),true);
    assert.equal(model.racePreview({status:'live'},{status:'live'},'2026-10-06',false),false);
    assert.equal(model.racePreview(null,{},'2026-10-06',false),false);
    assert.equal(model.racePreview({stageNavigation:true},{status:'upcoming'},'2026-10-06',false),true);
    assert.equal(model.racePreview({stageNavigation:true},{status:'finished'},'2026-10-06',true),false);
});

test('today pre-race states route to previews without suppressing genuine live failures', () => {
    for(const status of ['upcoming','scheduled']) {
        const race={status,date:'2026-10-07'};
        assert.equal(model.raceRequestMode(race,'2026-10-07'),'upcoming');
        assert.equal(model.racePreview(race,{},'2026-10-07',false),true);
        assert.equal(model.raceRequestMode({status},'2026-10-07'),'upcoming');
    }
    assert.equal(model.raceRequestMode({status:'live',date:'2026-10-07'},'2026-10-07'),'live');
    assert.equal(model.raceRequestMode({status:'finished',date:'2026-10-07'},'2026-10-07'),'finished');
    assert.equal(model.raceRequestMode({status:'scheduled',date:'2026-10-06'},'2026-10-07'),'live');
    assert.equal(model.raceRequestMode(null,'2026-10-07'),'live');
});
test('dismissing warnings preserves source issues and ignores retry timestamps', () => {
    const issues={race:{state:'offline',error:'Could not connect',failedAt:now,lastSuccess:'saved'}};
    const dismissed=model.dismissIssues(issues);
    assert.equal(Object.keys(model.visibleIssues(issues,dismissed)).length,0);
    const retry={race:{...issues.race,failedAt:now+60000}};
    const retained=model.retainedDismissals(retry,dismissed);
    assert.equal(Object.keys(model.visibleIssues(retry,retained)).length,0);
    assert.equal(issues.race.state,'offline');
    assert.equal(model.warning(issues,now,0,false).visible,true);
});
test('new issues, changed failures and recurrence after recovery show again', () => {
    const issues={race:{state:'offline',error:'Could not connect'}};
    const dismissed=model.dismissIssues(issues);
    for(const changed of [{race:{state:'blocked',error:'Rejected'}},{race:{state:'offline',error:'Different error'}},{...issues,profile:{state:'error',error:'Profile error'}}]) {
        const visible=model.visibleIssues(changed,model.retainedDismissals(changed,dismissed));
        assert.equal(Object.keys(visible).length,1);
    }
    const recovered=model.retainedDismissals({},dismissed);
    assert.equal(Object.keys(model.visibleIssues(issues,recovered)).length,1);
});

test('total ascent survives snapshots and fills live details without using remaining elevation', () => {
    const course=model.courseSnapshot({state:'ready',distance:180,elevationGain:2450,elevation:620});
    assert.equal(course.elevationGain,2450);assert.equal(course.elevation,undefined);
    assert.equal(model.withCourse({elevation:620},course).elevationGain,2450);
    assert.equal(model.withCourse({elevationGain:0},course).elevationGain,0);
    assert.equal(model.withCourse({elevationGain:3000},course).elevationGain,3000);
});
