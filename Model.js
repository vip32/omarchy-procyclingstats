// Pure state transitions shared by the hosted UI and portable tests.
function integer(value, fallback, min, max) {
    var n = Number(value)
    return Math.max(min, Math.min(max, Number.isFinite(n) && n > 0 ? Math.round(n) : fallback))
}

function settings(value) {
    value = value || {}
    var result = {
        pinnedRaces: normalizePins(value.pinnedRaces),
        detailTab: value.detailTab === "events" ? "events" : "overview",
        revealMode: value.revealMode !== false,
        calendarTab: value.calendarTab === "upcoming" ? "upcoming" : "recent",
        archiveRaceCount: integer(value.archiveRaceCount, 25, 10, 100),
        refreshIntervalSec: integer(value.refreshIntervalSec, 60, 60, 900),
        overviewIntervalSec: integer(value.overviewIntervalSec, 300, 300, 3600),
        resultsIntervalSec: integer(value.resultsIntervalSec, 300, 300, 3600),
        eventNotifications: value.eventNotifications === true,
        notificationDurationSec: integer(value.notificationDurationSec, 8, 5, 30),
        minimumRaceLevel: raceLevels().indexOf(value.minimumRaceLevel)>=0 ? value.minimumRaceLevel : "All"
    }
    categories().forEach(function(c) {result[c.key]=value[c.key] !== false})
    return result
}

function requestInterval(path, finished, options) {
    var s = settings(options)
    return 1000 * ((!path || path.indexOf("day:") === 0) ? s.overviewIntervalSec : finished ? s.resultsIntervalSec : s.refreshIntervalSec)
}

function archiveRows(races, mode, today, options, limit) {
    var eligible=(races || []).filter(function(r) {
        return matchesRace(r,options) && (mode==="recent" ? r.status==="finished" && r.date<=today : r.date>today && r.status!=="finished")
    }).sort(function(a,b) {
        var date=a.date.localeCompare(b.date)
        return (mode==="recent" ? -date : date) || a.name.localeCompare(b.name) || a.path.localeCompare(b.path)
    })
    return pinnedFirst(eligible,settings(options).pinnedRaces).slice(0,limit || 100)
}

function mergeArchive(previous, result, mode, today) {
    if(previous.reset && (result.state==="ready" || result.state==="empty" || (result.dates || []).length))
        previous={reset:false,fetchedAt:previous.fetchedAt || ""}
    var records={}
    ;(previous.races || []).concat(result.races || []).forEach(function(r) {
        var old=records[r.path]
        if(!old || (mode==="recent" ? r.date>=old.date : r.date<=old.date)) records[r.path]=r
    })
    var dates=(previous.dates || []).concat(result.dates || []).filter(function(d,i,all){return all.indexOf(d)===i}).sort()
    var races=Object.keys(records).map(function(k){return records[k]}).sort(function(a,b){return mode==="recent" ? b.date.localeCompare(a.date) : a.date.localeCompare(b.date)}).slice(0,1000)
    return Object.assign({},previous,result,{races:races,dates:dates,
        fetchedAt:isFailure(result.state) ? previous.fetchedAt || "" : result.fetchedAt || "",
        exhausted:dates.length>=366 || races.length>=1000,
        error:result.error || ""})
}

function isFailure(state) {
    return ["blocked", "rate-limited", "offline", "error", "unsupported"].indexOf(state) >= 0
}

function updateIssues(previous, path, result, cached, label, now) {
    var issues = Object.assign({}, previous)
    var key = path || "overview"
    function update(suffix, state, error, stamp, scope) {
        var id = key + suffix
        if (isFailure(state)) {
            issues[id] = {path:path, scope:scope, state:state, error:error || "PCS updates could not be read.",
                lastSuccess:stamp || "", failedAt:now}
        } else if (state) delete issues[id]
    }
    cached = cached || {}
    update("", result.state, result.error, cached.fetchedAt, path ? label : "Races")
    if (!path && result.metadataState) update("/metadata", result.metadataState, result.metadataError, cached.metadataFetchedAt, "Race categories and levels")
    if (path && path.indexOf("course:")!==0 && result.state === "ready") {
        update("/events", result.eventsState, result.eventsError, cached.eventsFetchedAt, "Race events · " + label)
        update("/profile", result.profileState, result.profileError, cached.profileFetchedAt, "Course profile · " + label)
        // A finished results response may omit resultsState on success.
        update("/results", result.resultsState || (result.classifications ? "ready" : ""),
            result.resultsError, cached.fetchedAt, "Results · " + label)
    }
    if (!path && ["ready", "empty"].indexOf(result.state) >= 0) {
        var paths = (result.retainedRaces || result.races || []).map(function(r) {return r.path})
        Object.keys(issues).forEach(function(id) {
            if (issues[id].path && issues[id].path.indexOf("day:") !== 0 && issues[id].path.indexOf("archive:") !== 0 && issues[id].path.indexOf("course:") !== 0 && paths.indexOf(issues[id].path) < 0) delete issues[id]
        })
    }
    return issues
}

function warning(issues, now, nextAllowed, loading) {
    var list = Object.keys(issues || {}).map(function(k) {
        return Object.assign({},issues[k],{component:k.indexOf("course:")===0 || k.endsWith("/profile") ? "profile" : k.endsWith("/events") ? "events" : k.endsWith("/results") ? "results" : k.endsWith("/metadata") ? "metadata" : "primary"})
    }).sort(function(a,b) {return (b.component==="primary")-(a.component==="primary") || b.failedAt-a.failedAt})
    if (!list.length) return {visible:false, title:"", text:""}
    var issue = list[0]
    var reason = ({blocked:"PCS rejected automated access.", "rate-limited":"PCS is limiting requests.",
        offline:"Could not connect to PCS.", error:"PCS update failed.", unsupported:"PCS data could not be read."})[issue.state]
    var stamp = Date.parse(issue.lastSuccess)
    var age = Number.isFinite(stamp) ? "Last successful update " + Math.max(0,Math.floor((now-stamp)/60000)) + "m ago." : "No successful update yet."
    var retry = nextAllowed > now ? "Retrying in about " + Math.ceil((nextAllowed-now)/60000) + "m."
        : loading ? "Reconnecting…" : "Retrying automatically."
    var titles={profile:"Course profile unavailable",events:"Race events unavailable",results:"Results unavailable",metadata:"Race metadata unavailable"}
    var title=nextAllowed>now ? "PCS updates paused" : titles[issue.component] || (issue.path ? "Race updates unavailable" : "Live updates unavailable")
    if(list.some(function(other){return other.component!==issue.component}) && issue.component!=="primary" && nextAllowed<=now)title="Some PCS data unavailable"
    var detail=issue.error || reason
    return {visible:true,title:title,text:issue.scope + (list.length>1 ? " (and "+(list.length-1)+" more)" : "") + " · " + detail + "\n"
        + (Number.isFinite(stamp) || issue.component==="primary" ? age+" " : "") + retry}
}

function eventKey(event) { return JSON.stringify([event.marker || "", event.text || ""]) }

function nextKeypoint(detail) {
    if (detail.kmDone === null || detail.kmDone === undefined || !Number.isFinite(Number(detail.kmDone))) return null
    var done = Number(detail.kmDone)
    var upcoming = (detail.keypoints || []).filter(function(k) {
        return k.km !== null && k.km !== undefined && Number.isFinite(Number(k.km)) && Number(k.km) >= done
    }).sort(function(a,b) {return Number(a.km)-Number(b.km)})
    return upcoming.length ? Object.assign({},upcoming[0],{remaining:Math.round((Number(upcoming[0].km)-done)*10)/10}) : null
}

function newEvents(previous, events, now, maxAge) {
    var keys = events.map(eventKey)
    // First fetch, a restart, or a long outage establishes a baseline only.
    var fresh = previous && now-previous.at <= maxAge
        ? events.filter(function(e) {return previous.keys.indexOf(eventKey(e)) < 0}) : []
    var retained = keys.concat(previous ? previous.keys : []).filter(function(k,i,a) {return a.indexOf(k) === i}).slice(0,180)
    return {baseline:{at:now,keys:retained}, fresh:fresh}
}

function notificationArgs(name, events, duration) {
    // A fixed prefix keeps remote strings out of the CLI's option positions.
    var lines = events.slice(0,3).map(function(e) {
        return (e.marker === "F" ? "Finish" : e.marker ? e.marker + " km to go" : "Update") + " · " + String(e.text || "").slice(0,300)
    })
    if (events.length > 3) lines.push("+ " + (events.length-3) + " more events in the race panel")
    return ["/usr/bin/omarchy", "notification", "send", "--app-name", "ProCyclingStats", "-u", "low", "-g", "󰂣",
        "-t", String(integer(duration,8,5,30)*1000), "Race events · " + String(name).slice(0,180),
        "Race update: " + lines.join("\n").replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;")]
}

// Local noon avoids UTC shifts and DST transitions when stepping calendar days.
function dayKey(now, offset) {
    var d = new Date(now)
    d = new Date(d.getFullYear(), d.getMonth(), d.getDate() + offset, 12)
    return d.getFullYear() + "-" + String(d.getMonth()+1).padStart(2,"0") + "-" + String(d.getDate()).padStart(2,"0")
}
function dayLabel(now, offset) {
    var d = new Date(dayKey(now,offset)+"T12:00:00")
    return ["Yesterday", "Today", "Tomorrow"][offset+1] + " · " + d.getDate() + " " +
        ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][d.getMonth()]
}

function categories() {
    return [
        ["ME","Men elite"],["ME (TT)","Men elite · TT"],
        ["WE","Women elite"],["WE (TT)","Women elite · TT"],
        ["MU","Men U23"],["MU (TT)","Men U23 · TT"],
        ["MJ","Men junior"],["MJ (TT)","Men junior · TT"],
        ["WJ","Women junior"],["WJ (TT)","Women junior · TT"],
        ["WU","Women U23"],["WU (TT)","Women U23 · TT"],
        ["ME+WE (TT)","Mixed team · TT"]
    ].map(function(c) {return {code:c[0],label:c[1],key:"category"+c[0].replace(/[^A-Z]/g,"")}})
}
function raceLevels() { return ["All", "Class 2+", "Class 1+", "ProSeries+", "WorldTour"] }
function raceLevel(value) {
    var c = String(value || "").toUpperCase()
    // Championships are separate competitions, retained at every threshold.
    if (["WC","NC","CC","JC","JOJ","JR","OG"].indexOf(c)>=0) return 5
    if (/^[12]\.(UWT|WWT)$/.test(c)) return 4
    if (/^[12]\.(PRO|HC)$/.test(c)) return 3
    if (/^[12]\.1$/.test(c)) return 2
    if (/^[12]\.2U?$/.test(c)) return 1
    // Nations Cups and other classifications are outside this level ladder.
    return 0
}
function filterMetadata(race) {
    var parts=String(race.category || "").split(" · ")
    return {category:race.competitionCategory || parts[0] || "",level:race.raceClass || parts[1] || ""}
}
function filtersActive(options) {
    var s=settings(options)
    return s.minimumRaceLevel!=="All" || categories().some(function(c){return !s[c.key]})
}
function matchesRace(race, options) {
    var s=settings(options), cats=categories(), meta=filterMetadata(race)
    var category=cats.filter(function(c){return c.code===meta.category})[0]
    if (category ? !s[category.key] : cats.some(function(c){return !s[c.key]})) return false
    var minimum=raceLevels().indexOf(s.minimumRaceLevel)
    return !minimum || raceLevel(meta.level)>=minimum
}

function courseSnapshot(value) {
    var out={state:value.state,fetchedAt:value.fetchedAt || ""}
    ;["distance","profile","profileImage","profileImageWidth","profileImageHeight","profileLabel","stagePath","profileState","profileError","profileFetchedAt"].forEach(function(key){if(value[key]!==undefined)out[key]=value[key]})
    return out
}

function withCourse(detail,course) {
    var result=Object.assign({},detail)
    if(result.distance===null || result.distance===undefined)result.distance=course.distance
    if(!(result.profile || []).length && !result.profileImage) {
        ;["profile","profileImage","profileImageWidth","profileImageHeight","profileState","profileError","profileFetchedAt"].forEach(function(key){if(course[key]!==undefined)result[key]=course[key]})
    }
    if(!result.profileLabel)result.profileLabel=course.profileLabel || ""
    if(!result.stagePath)result.stagePath=course.stagePath || ""
    return result
}

// A reveal applies only to the currently selected race, never to the next one.
function resultsHidden(enabled, raceStatus, detailStatus, revealed) {
    return enabled && (raceStatus === "finished" || detailStatus === "finished") && !revealed
}

// Pins identify an edition, so GC and individual stages share the same star.
function raceEdition(path) {
    var match=/^(race\/[a-z0-9-]+\/\d{4})(?:\/(?:result|gc|stage-\d+[a-z]?))?$/.exec(String(path || ""))
    return match ? match[1] : ""
}
function normalizePins(value) {
    return (Array.isArray(value) ? value : []).map(raceEdition).filter(function(p,i,a){return p && a.indexOf(p)===i}).slice(0,100)
}
function isPinned(path,pins) {return normalizePins(pins).indexOf(raceEdition(path))>=0}
function togglePin(path,pins) {
    var next=normalizePins(pins),key=raceEdition(path),index=next.indexOf(key)
    if(!key)return next
    if(index>=0)next.splice(index,1)
    else if(next.length<100)next.push(key)
    return next
}
function pinnedFirst(rows,pins) {
    return rows.map(function(r,i){return {race:r,index:i}}).sort(function(a,b){
        return Number(isPinned(b.race.path,pins))-Number(isPinned(a.race.path,pins)) || a.index-b.index
    }).map(function(item){return item.race})
}
function stageNeighbor(detail,offset) {
    var stages=detail.stages || [],path=detail.stagePath || detail.path || ""
    var index=stages.findIndex(function(s){return s.path===path})
    return index>=0 ? stages[index+(offset<0 ? -1 : 1)] || null : null
}
function gapSeconds(value) {
    if(!/^\+?\d{1,2}:[0-5]\d(?::[0-5]\d)?$/.test(String(value || "")))return null
    return String(value).replace(/^\+/,"").split(":").reduce(function(total,n){return total*60+Number(n)},0)
}
function groupIdentity(group) {
    if(group.uncertain || group.omitted>0)return ""
    var riders=group.riders || []
    if(riders.length) {
        var ids=riders.map(function(r){return r.id || r.name || ""}).sort()
        if(ids.some(function(id){return !id}) || (group.count && group.count!==ids.length))return ""
        return "riders:"+ids.join("|")
    }
    // A numbered group is unstable; the peloton is the only safe unnamed group.
    return /^peloton$/i.test(String(group.label || "").trim()) ? "peloton" : ""
}
function gapTrends(previous,current,now,maxAge) {
    var groups=(current.groups || []).map(function(g){return Object.assign({},g,{gapDelta:null})})
    if(!previous || previous.state!=="ready" || current.state!=="ready" || previous.status!=="live" || current.status!=="live" || previous.path!==current.path)return groups
    var before=Date.parse(previous.sourceAt || previous.fetchedAt),after=Date.parse(current.sourceAt || current.fetchedAt)
    if(!Number.isFinite(before) || !Number.isFinite(after) || after<=before || after-before>maxAge || now-after>maxAge || after>now+60000)return groups
    var old=previous.groups || [],front=groups[0],oldFront=old[0]
    // Both gaps must refer to the same front group, with complete membership.
    if(!front || !oldFront || gapSeconds(front.gap)!==0 || gapSeconds(oldFront.gap)!==0 || !groupIdentity(front) || groupIdentity(front)!==groupIdentity(oldFront))return groups
    var identities=groups.map(groupIdentity),oldIdentities=old.map(groupIdentity)
    return groups.map(function(g,index){
        var id=identities[index],matches=old.filter(function(p,i){return oldIdentities[i]===id})
        var gap=gapSeconds(g.gap),was=matches.length===1 ? gapSeconds(matches[0].gap) : null
        if(index>0 && id && identities.indexOf(id)===identities.lastIndexOf(id) && gap!==null && was!==null && !matches[0].uncertain)g.gapDelta=gap-was
        return g
    })
}
function gapTrendText(group,fresh) {
    var delta=group.gapDelta
    return fresh && typeof delta==="number" && delta!==0 ? (delta<0 ? " ↑" : " ↓") : ""
}

function editionName(race) {
    return race.editionName || String(race.name || "Race").replace(/\s*[·|–-]\s*Stage\s+\d+[a-z]?.*$/i,"")
}
