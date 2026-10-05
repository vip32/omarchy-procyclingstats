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
