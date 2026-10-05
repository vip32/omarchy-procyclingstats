// Pure state transitions shared by the hosted UI and portable tests.
function integer(value, fallback, min, max) {
    var n = Number(value)
    return Math.max(min, Math.min(max, Number.isFinite(n) && n > 0 ? Math.round(n) : fallback))
}

function settings(value) {
    value = value || {}
    var result = {
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
    return (races || []).filter(function(r) {
        return matchesRace(r,options) && (mode==="recent" ? r.status==="finished" && r.date<=today : r.date>today && r.status!=="finished")
    }).sort(function(a,b) {
        var date=a.date.localeCompare(b.date)
        return (mode==="recent" ? -date : date) || a.name.localeCompare(b.name) || a.path.localeCompare(b.path)
    }).slice(0,limit || 100)
}

function mergeArchive(previous, result, mode, today) {
    if(previous.reset && (result.state==="ready" || result.state==="empty")) previous={reset:false}
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
    if (path && result.state === "ready") {
        update("/events", result.eventsState, result.eventsError, cached.eventsFetchedAt, "Race events · " + label)
        update("/profile", result.profileState, result.profileError, cached.profileFetchedAt, "Course profile · " + label)
        // A finished results response may omit resultsState on success.
        update("/results", result.resultsState || (result.classifications ? "ready" : ""),
            result.resultsError, cached.fetchedAt, "Results · " + label)
    }
    if (!path && ["ready", "empty"].indexOf(result.state) >= 0) {
        var paths = (result.retainedRaces || result.races || []).map(function(r) {return r.path})
        Object.keys(issues).forEach(function(id) {
            if (issues[id].path && issues[id].path.indexOf("day:") !== 0 && issues[id].path.indexOf("archive:") !== 0 && paths.indexOf(issues[id].path) < 0) delete issues[id]
        })
    }
    return issues
}

function warning(issues, now, nextAllowed, loading) {
    var list = Object.keys(issues || {}).map(function(k) {return issues[k]})
        .sort(function(a,b) {return b.failedAt - a.failedAt})
    if (!list.length) return {visible:false, title:"", text:""}
    var issue = list[0]
    var reason = ({blocked:"PCS rejected automated access.", "rate-limited":"PCS is limiting requests.",
        offline:"Could not connect to PCS.", error:"PCS update failed.", unsupported:"PCS data could not be read."})[issue.state]
    var stamp = Date.parse(issue.lastSuccess)
    var age = Number.isFinite(stamp) ? "Last successful update " + Math.max(0,Math.floor((now-stamp)/60000)) + "m ago." : "No successful update yet."
    var retry = nextAllowed > now ? "Retrying in about " + Math.ceil((nextAllowed-now)/60000) + "m."
        : loading ? "Reconnecting…" : "Retrying automatically."
    return {visible:true, title:"Live updates unavailable", text:reason + " Previously fetched data may be out of date.\n"
        + issue.scope + (list.length > 1 ? " (and " + (list.length-1) + " more)" : "") + " · " + age + " " + retry}
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
