// Pure state transitions shared by the hosted UI and portable tests.
function integer(value, fallback, min, max) {
    var n = Number(value)
    return Math.max(min, Math.min(max, Number.isFinite(n) && n > 0 ? Math.round(n) : fallback))
}

function settings(value) {
    value = value || {}
    return {
        refreshIntervalSec: integer(value.refreshIntervalSec, 60, 60, 900),
        overviewIntervalSec: integer(value.overviewIntervalSec, 300, 300, 3600),
        resultsIntervalSec: integer(value.resultsIntervalSec, 300, 300, 3600),
        eventNotifications: value.eventNotifications === true,
        notificationDurationSec: integer(value.notificationDurationSec, 8, 5, 30)
    }
}

function requestInterval(path, finished, options) {
    var s = settings(options)
    return 1000 * (!path ? s.overviewIntervalSec : finished ? s.resultsIntervalSec : s.refreshIntervalSec)
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
    if (path && result.state === "ready") {
        update("/events", result.eventsState, result.eventsError, cached.eventsFetchedAt, "Race events · " + label)
        // A finished results response may omit resultsState on success.
        update("/results", result.resultsState || (result.classifications ? "ready" : ""),
            result.resultsError, cached.fetchedAt, "Results · " + label)
    }
    if (!path && ["ready", "empty"].indexOf(result.state) >= 0) {
        var paths = (result.races || []).map(function(r) {return r.path})
        Object.keys(issues).forEach(function(id) {
            if (issues[id].path && paths.indexOf(issues[id].path) < 0) delete issues[id]
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
